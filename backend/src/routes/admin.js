const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const authorizeRoles = require('../middleware/authorizeRoles');
const Donor        = require('../models/Donor');
const Booking      = require('../models/Booking');
const BloodRequest = require('../models/BloodRequest');
const BloodBank    = require('../models/BloodBank');
const BloodBankAccount = require('../models/BloodBankAccount');
const { admin }    = require('../config/firebase');
const { serializeAdminDonation } = require('../privacy/donorResponses');
const { createTransactionRunner, sendTransactionUnavailable } = require('../db/transactions');
const sendPrivateImage = require('../storage/imageResponse');

const runInTransaction = createTransactionRunner(() => Booking.startSession());

router.use(authenticate, authorizeRoles('admin'));

// Self-registered BloodBankAccount approval, separate from the manual directory.
router.get('/blood-bank-accounts/pending', async (_req, res) => {
  try {
    const accounts = await BloodBankAccount.find({ isVerified: { $ne: true } })
      .select({
        name: 1,
        registrationNo: 1,
        email: 1,
        phone: 1,
        address: 1,
        city: 1,
        state: 1,
      })
      .sort({ createdAt: -1 })
      .lean();
    return res.json(accounts);
  } catch (err) {
    console.error('[Admin GET /blood-bank-accounts/pending]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/blood-bank-accounts/:id/approve', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOneAndUpdate(
      { _id: req.params.id, isVerified: { $ne: true } },
      { $set: { isVerified: true } },
      { new: true, runValidators: true },
    ).lean();
    if (account) return res.json(account);

    const existing = await BloodBankAccount.findById(req.params.id).lean();
    if (!existing) return res.status(404).json({ error: 'bank_account_not_found' });
    return res.status(409).json({ error: 'bank_already_verified' });
  } catch (err) {
    console.error('[Admin PATCH /blood-bank-accounts/:id/approve]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /admin/donations/pending ───────────────────────────────────────────
router.get('/donations/pending', async (_req, res) => {
  try {
    const donations = await Booking.find({
      status: 'completed',
      proofStatus: { $in: ['pending', 'approved', 'rejected', 'appealed'] },
    }).select('_id donorName bloodGroup component bookingRef status units facilityName facilityAddress facilityPhone donatedAt coolingEndsAt donationPhotoUrl doctorSlipUrl donationPhoto doctorSlip proofStatus verificationNote verifiedAt certificateNo appealReason createdAt updatedAt')
      .sort({ updatedAt: -1 }).lean();
    return res.json(donations.map(serializeAdminDonation));
  } catch (err) {
    console.error('[Admin GET /donations/pending]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/donations/:id/proof/:kind', async (req, res) => {
  try {
    const fields = {
      'donation-photo': ['donationPhoto', 'donationPhotoUrl'],
      'doctor-slip': ['doctorSlip', 'doctorSlipUrl'],
    }[req.params.kind];
    if (!fields) return res.status(404).json({ error: 'image_not_found' });
    const booking = await Booking.findById(req.params.id);
    if (!booking || booking.status !== 'completed') {
      return res.status(404).json({ error: 'image_not_found' });
    }
    return sendPrivateImage(res, booking[fields[0]], booking[fields[1]]);
  } catch (_) {
    console.error('[Admin GET donation proof] Private image lookup failed');
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /admin/donations/:id/verify ───────────────────────────────────────
router.patch('/donations/:id/verify', async (req, res) => {
  try {
    const result = await runInTransaction(async (session) => {
      const outcome = { statusCode: 200, body: null };
      const reply = {
        status(code) { outcome.statusCode = code; return this; },
        json(body) { outcome.body = body; return body; },
      };
      const approved = req.body.approved === true;
      const note = String(req.body.note || '').trim();
      const booking = await Booking.findById(req.params.id).session(session);
      if (!booking) { reply.status(404).json({ error: 'Donation not found' }); return outcome; }
      if (booking.status !== 'completed') {
        reply.status(409).json({ error: 'Donation is not completed' }); return outcome;
      }
      if (!['pending', 'rejected', 'appealed'].includes(booking.proofStatus)) {
        reply.status(409).json({ error: 'Donation proof was already approved' }); return outcome;
      }

      booking.proofStatus = approved ? 'approved' : 'rejected';
      booking.verificationNote = note;
      booking.verifiedAt = new Date();
      booking.verifiedBy = req.uid;
      if (approved) {
        booking.appealReason = '';
        booking.appealedAt = null;
        const year = new Date().getFullYear();
        const rand = Math.floor(100000 + Math.random() * 900000);
        booking.certificateNo = `OBC-CERT-${year}-${rand}`;
        booking.certificateIssuedAt = new Date();
        const donor = await Donor.findOne({ uid: booking.donorUid }).session(session).lean();
        const nextDonationUnits = Number(donor?.lastDonationUnits ?? 0) + 1;
        await Donor.findOneAndUpdate(
          { uid: booking.donorUid },
          { $set: {
            lastDonationDate: booking.donatedAt,
            lastDonationUnits: nextDonationUnits,
            hospitalBookingActive: false,
            bookingStatus: 'completed',
            showToOthers: false,
            readyAnyTime: false,
          } },
          { upsert: true, new: true, session },
        );
      } else {
        booking.certificateNo = '';
        booking.certificateIssuedAt = null;
      }
      await booking.save({ session });
      reply.json(serializeAdminDonation(booking));
      return outcome;
    });
    return res.status(result.statusCode).json(result.body);
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[Admin PATCH /donations/:id/verify]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});
router.get('/stats', async (req, res) => {
  try {
    // Run all counts in parallel for speed
    const [
      totalUsers,
      registeredDonors,
      activeBookings,
      completedDonations,
      bloodBanks,
      pendingRequests,
    ] = await Promise.all([
      // Total Firebase users — list and count (max 1000 per page; fine for now)
      admin.auth().listUsers(1000).then(r => r.users.length).catch(() => 0),
      // Donors who completed registration
      Donor.countDocuments({ registered: true, manualEntry: { $ne: true } }),
      // Active (booked/confirmed) bookings
      Booking.countDocuments({ status: { $in: ['booked', 'confirmed'] } }),
      // Completed donations
      Booking.countDocuments({ status: 'completed' }),
      // Blood banks in directory
      BloodBank.countDocuments(),
      // Blood requests not yet fulfilled or cancelled
      BloodRequest.countDocuments({ status: { $nin: ['fulfilled', 'cancelled'] } }),
    ]);

    res.json({
      totalUsers,
      registeredDonors,
      activeBookings,
      completedDonations,
      bloodBanks,
      pendingRequests,
    });
  } catch (err) {
    console.error('[Admin GET /stats]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /admin/users ─────────────────────────────────────────────────────────
// Returns all Firebase users with their donor/booking status.
router.get('/users', async (req, res) => {
  try {
    // Fetch Firebase users list (up to 1000)
    const listResult = await admin.auth().listUsers(1000);
    const firebaseUsers = listResult.users;

    // Fetch all donor docs and active bookings in one query each
    const [donors, activeBookings] = await Promise.all([
      Donor.find({ registered: true, manualEntry: { $ne: true } })
        .select('uid bloodGroup donationStream')
        .lean(),
      Booking.find({ status: { $in: ['booked', 'confirmed'] } })
        .select('donorUid')
        .lean(),
    ]);

    // Build lookup sets for O(1) checks
    const donorUids      = new Set(donors.map(d => d.uid));
    const bookedUids     = new Set(activeBookings.map(b => b.donorUid));
    const donorByUid     = Object.fromEntries(donors.map(d => [d.uid, d]));

    const users = firebaseUsers.map(u => ({
      displayName: u.displayName || '',
      email:       u.email       || '',
      createdAt:   u.metadata.creationTime,
      isDonor:     donorUids.has(u.uid),
      hasBooking:  bookedUids.has(u.uid),
      bloodGroup:  donorByUid[u.uid]?.bloodGroup || '',
    }));

    // Sort: donors first, then by creation date descending
    users.sort((a, b) => {
      if (a.isDonor !== b.isDonor) return a.isDonor ? -1 : 1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    res.json(users);
  } catch (err) {
    console.error('[Admin GET /users]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
