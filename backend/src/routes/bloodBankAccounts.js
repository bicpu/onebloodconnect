const express           = require('express');
const router            = express.Router();
const authenticate      = require('../middleware/auth');
const BloodBankAccount  = require('../models/BloodBankAccount');
const BloodRequest      = require('../models/BloodRequest');
const Donor             = require('../models/Donor');
const Booking           = require('../models/Booking');

// ─── POST /blood-bank-accounts/register ──────────────────────────────────────
// Called right after Firebase Auth signup. Saves the blood bank profile.
// No auth middleware — the client sends the new user's token.
router.post('/register', authenticate, async (req, res) => {
  try {
    const {
      name, registrationNo, email, phone, website,
      address, city, state, pincode, hours,
    } = req.body;

    if (!name || !email) {
      return res.status(400).json({ error: 'name and email are required' });
    }

    // Prevent duplicate registration for the same Firebase UID
    const existing = await BloodBankAccount.findOne({ uid: req.uid });
    if (existing) {
      return res.status(409).json({ error: 'already_registered', account: existing });
    }

    const account = await BloodBankAccount.create({
      uid:            req.uid,
      name:           name.trim(),
      registrationNo: registrationNo || '',
      email:          email.toLowerCase().trim(),
      phone:          phone          || '',
      website:        website        || '',
      address:        address        || '',
      city:           city           || '',
      state:          state          || '',
      pincode:        pincode        || '',
      hours:          hours          || '8:00 AM – 6:00 PM',
      stock:          {},
      slots:          [],
      doctors:        [],
      nurses:         [],
      isVerified:     false,
    });

    res.status(201).json(account);
  } catch (err) {
    console.error('[BloodBankAccount POST /register]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// All routes below require a valid Firebase ID token
router.use(authenticate);

// ─── GET /blood-bank-accounts/me ─────────────────────────────────────────────
// Returns the current blood bank's profile.
router.get('/me', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) {
      return res.status(404).json({ error: 'not_registered' });
    }

    // Convert Map to plain object for JSON serialisation
    const stockObj = account.stock instanceof Map
      ? Object.fromEntries(account.stock)
      : (account.stock || {});

    res.json({ ...account, stock: stockObj });
  } catch (err) {
    console.error('[BloodBankAccount GET /me]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /blood-bank-accounts/me ───────────────────────────────────────────
// Update any combination of profile fields, stock, slots, doctors, nurses.
router.patch('/me', async (req, res) => {
  try {
    const allowed = [
      'name', 'registrationNo', 'phone', 'website',
      'address', 'city', 'state', 'pincode', 'hours',
      'stock', 'slots', 'doctors', 'nurses',
    ];

    const update = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) update[key] = req.body[key];
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ error: 'No updatable fields provided' });
    }

    const account = await BloodBankAccount.findOneAndUpdate(
      { uid: req.uid },
      { $set: update },
      { new: true, runValidators: true }
    ).lean();

    if (!account) return res.status(404).json({ error: 'not_registered' });

    const stockObj = account.stock instanceof Map
      ? Object.fromEntries(account.stock)
      : (account.stock || {});

    res.json({ ...account, stock: stockObj });
  } catch (err) {
    console.error('[BloodBankAccount PATCH /me]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-bank-accounts/active-requests ────────────────────────────────
// Returns all open blood requests from the user app that are NOT cancelled/fulfilled.
// Used by the blood bank dashboard to see what's needed.
router.get('/active-requests', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) return res.status(404).json({ error: 'not_registered' });
    const now = new Date();
    // Auto-expire
    await BloodRequest.updateMany(
      { status: { $nin: ['cancelled', 'fulfilled'] }, expiresAt: { $lte: now } },
      { $set: { status: 'cancelled' },
        $push: { timeline: { step: 'Expired', time: now, note: 'Request expired' } } }
    );

    const requests = await BloodRequest.find({
      status: { $nin: ['cancelled', 'fulfilled'] },
      $or: [
        { targetFacilityUid: account.uid },
        {
          targetFacilityUid: { $in: ['', null] },
          targetFacilityName: account.name,
        },
      ],
    })
      .sort({ createdAt: -1 })
      .lean();

    res.json(requests);
  } catch (err) {
    console.error('[BloodBankAccount GET /active-requests]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /blood-bank-accounts/requests/:id/review ─────────────────────────
router.patch('/requests/:id/review', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) return res.status(404).json({ error: 'not_registered' });
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Blood request not found' });

    const belongsToBank =
      request.targetFacilityUid === account.uid ||
      (!request.targetFacilityUid && request.targetFacilityName === account.name);
    if (!belongsToBank) return res.status(403).json({ error: 'Request is not assigned to this blood bank' });

    const decision = req.body.accepted === true ? 'accepted' : 'rejected';
    const comment = String(req.body.comment || '').trim();
    if (!comment) return res.status(400).json({ error: 'A review comment is required' });

    request.facilityReviewStatus = decision;
    request.facilityReviewComment = comment;
    request.facilityReviewedAt = new Date();
    request.facilityReviewedBy = req.uid;
    request.timeline.push({
      step: decision === 'accepted' ? 'Blood Bank Accepted' : 'Blood Bank Rejected',
      time: new Date(),
      note: comment,
    });
    if (decision === 'rejected') request.status = 'cancelled';
    else if (request.status === 'pending') request.status = 'received';
    await request.save();
    res.json(request);
  } catch (err) {
    console.error('[BloodBank PATCH /requests/:id/review]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-bank-accounts/stats ──────────────────────────────────────────
// Dashboard stats for the blood bank.
router.get('/stats', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) return res.status(404).json({ error: 'not_registered' });
    const [totalUsers, openRequests] = await Promise.all([
      Donor.countDocuments({ registered: true }),
      BloodRequest.countDocuments({
        status: { $nin: ['cancelled', 'fulfilled'] },
        $or: [
          { targetFacilityUid: account.uid },
          {
            targetFacilityUid: { $in: ['', null] },
            targetFacilityName: account.name,
          },
        ],
      }),
    ]);

    const stockObj = account.stock instanceof Map
      ? Object.fromEntries(account.stock)
      : (account.stock || {});

    const totalUnits = Object.values(stockObj).reduce((s, v) => s + (Number(v) || 0), 0);

    res.json({
      name:          account.name,
      isVerified:    account.isVerified,
      totalUnits,
      stockGroups:   Object.keys(stockObj).length,
      totalUsers,
      openRequests,
      doctors:       (account.doctors || []).length,
      nurses:        (account.nurses  || []).length,
      slots:         (account.slots   || []).length,
    });

    // ─── GET /blood-bank-accounts/donations/pending ──────────────────────────────
    router.get('/donations/pending', async (req, res) => {
      try {
        const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
        if (!account) return res.status(404).json({ error: 'not_registered' });
        const donations = await Booking.find({
          facilityName: account.name,
          status: 'completed',
          proofStatus: 'pending',
        }).sort({ donatedAt: -1 }).lean();
        res.json(donations);
      } catch (err) {
        console.error('[BloodBank GET /donations/pending]', err);
        res.status(500).json({ error: 'Server error' });
      }
    });

    // ─── PATCH /blood-bank-accounts/donations/:id/verify ─────────────────────────
    router.patch('/donations/:id/verify', async (req, res) => {
      try {
        const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
        if (!account) return res.status(404).json({ error: 'not_registered' });
        const booking = await Booking.findOne({
          _id: req.params.id,
          facilityName: account.name,
        });
        if (!booking) return res.status(404).json({ error: 'Donation not found' });
        if (booking.status !== 'completed') {
          return res.status(409).json({ error: 'Donation is not completed' });
        }
        if (booking.proofStatus !== 'pending') {
          return res.status(409).json({ error: 'Donation proof was already reviewed' });
        }
        const approved = req.body.approved === true;
        booking.proofStatus = approved ? 'approved' : 'rejected';
        booking.verificationNote = String(req.body.note || '').trim();
        booking.verifiedAt = new Date();
        booking.verifiedBy = req.uid;
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
        }
        await booking.save();
        res.json(booking);
      } catch (err) {
        console.error('[BloodBank PATCH /donations/:id/verify]', err);
        res.status(500).json({ error: 'Server error' });
      }
    });
  } catch (err) {
    console.error('[BloodBankAccount GET /stats]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-bank-accounts/all ────────────────────────────────────────────
// Returns all active, verified blood bank profiles.
// Used by the user app search page and venue selection.
router.get('/all', async (req, res) => {
  try {
    const accounts = await BloodBankAccount.find({ isActive: true })
      .sort({ createdAt: -1 })
      .lean();

    const enriched = accounts.map(a => ({
      ...a,
      stock: a.stock instanceof Map ? Object.fromEntries(a.stock) : (a.stock || {}),
    }));

    res.json(enriched);
  } catch (err) {
    console.error('[BloodBankAccount GET /all]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
