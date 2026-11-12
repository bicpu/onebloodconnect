const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const Donor        = require('../models/Donor');
const Booking      = require('../models/Booking');
const BloodRequest = require('../models/BloodRequest');
const BloodBank    = require('../models/BloodBank');
const { admin }    = require('../config/firebase');

router.use(authenticate);

// ─── GET /admin/donations/pending ───────────────────────────────────────────
router.get('/donations/pending', async (_req, res) => {
  try {
    const donations = await Booking.find({
      status: 'completed',
      proofStatus: { $in: ['pending', 'approved', 'rejected', 'appealed'] },
    }).sort({ updatedAt: -1 }).lean();
    res.json(donations);
  } catch (err) {
    console.error('[Admin GET /donations/pending]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /admin/donations/:id/verify ───────────────────────────────────────
router.patch('/donations/:id/verify', async (req, res) => {
  try {
    const approved = req.body.approved === true;
    const note = String(req.body.note || '').trim();
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Donation not found' });
    if (booking.status !== 'completed') {
      return res.status(409).json({ error: 'Donation is not completed' });
    }
    if (!['pending', 'rejected', 'appealed'].includes(booking.proofStatus)) {
      return res.status(409).json({ error: 'Donation proof was already approved' });
    }

    booking.proofStatus = approved ? 'approved' : 'rejected';
    booking.verificationNote = note;
    booking.verifiedAt = new Date();
    booking.verifiedBy = req.uid;
    if (approved) {
      booking.appealReason = '';
      booking.appealedAt = null;
    }

    if (approved) {
      const year = new Date().getFullYear();
      const rand = Math.floor(100000 + Math.random() * 900000);
      booking.certificateNo = `OBC-CERT-${year}-${rand}`;
      booking.certificateIssuedAt = new Date();
      const donor = await Donor.findOne({ uid: booking.donorUid });
      const nextDonationUnits = Number(donor?.lastDonationUnits ?? 0) + 1;
      await Donor.findOneAndUpdate(
        { uid: booking.donorUid },
        {
          $set: {
            lastDonationDate: booking.donatedAt,
            lastDonationUnits: nextDonationUnits,
            hospitalBookingActive: false,
            bookingStatus: 'completed',
            showToOthers: false,
            readyAnyTime: false,
          },
        },
        { upsert: true, new: true },
      );
    } else {
      booking.certificateNo = '';
      booking.certificateIssuedAt = null;
    }

    await booking.save();
    res.json(booking);
  } catch (err) {
    console.error('[Admin PATCH /donations/:id/verify]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /admin/stats ─────────────────────────────────────────────────────────
// Returns platform-wide counts for the admin dashboard.
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
      uid:         u.uid,
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
