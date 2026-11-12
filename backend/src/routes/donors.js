const express    = require('express');
const router     = express.Router();
const authenticate = require('../middleware/auth');
const Donor      = require('../models/Donor');

// All routes below require a valid Firebase ID token
router.use(authenticate);

// ─── GET /donors/me ───────────────────────────────────────────────────────────
// Returns the current user's donor document (creates a shell doc if missing).
router.get('/me', async (req, res) => {
  try {
    let donor = await Donor.findOne({ uid: req.uid });

    if (!donor) {
      // First visit — return empty structure so the Flutter app knows the user
      // is NOT yet registered.
      return res.json({ registered: false });
    }

    res.json(donor);
  } catch (err) {
    console.error('[Donor GET /me]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── POST /donors/register ────────────────────────────────────────────────────
// Called from DonateBloodPage when the user completes registration.
// Creates or fully replaces the donor profile.
router.post('/register', async (req, res) => {
  try {
    const {
      fullName,
      email,
      bloodGroup,
      donationStream,
      preScreeningAnswers,
      readyAnyTime,
      showToOthers,
      lastDonationDate,
      lastDonationUnits,
      phone, dateOfBirth, gender, city, state, pincode, preferredVenue,
      profilePhotoUrl,
      lastDonationType, lastDonationHospital, healthEligibility,
      emergencyAvailable, consentAccepted,
    } = req.body;

    const update = {
      uid:                req.uid,
      fullName:           fullName   || req.firebaseUser.name || 'Donor',
      email:              email      || req.firebaseUser.email || '',
      profilePhotoUrl:    profilePhotoUrl || '',
      bloodGroup:         bloodGroup || '',
      donationStream:     donationStream || 'Whole Blood',
      preScreeningAnswers: preScreeningAnswers || {},
      readyAnyTime:       readyAnyTime  === true,
      showToOthers:       showToOthers  === true,
      registered:         true,
      hospitalBookingActive: false,
      bookingStatus:      'ready_to_donate',
      phone:              phone || '',
      dateOfBirth:        dateOfBirth ? new Date(dateOfBirth) : null,
      gender:             gender || '',
      city:               city || '',
      state:              state || '',
      pincode:            pincode || '',
      preferredVenue:     preferredVenue || 'Not selected yet',
      lastDonationType:   lastDonationType || '',
      lastDonationHospital: lastDonationHospital || '',
      healthEligibility: healthEligibility || {},
      emergencyAvailable: emergencyAvailable === true,
      consentAccepted:    consentAccepted === true,
    };

    if (lastDonationDate)  update.lastDonationDate  = new Date(lastDonationDate);
    if (lastDonationUnits) update.lastDonationUnits = lastDonationUnits;
    if (lastDonationDate) {
      const coolingDays = lastDonationType === 'Platelets' ? 7
        : lastDonationType === 'Plasma' ? 28 : 90;
      update.coolingEndsAt = new Date(new Date(lastDonationDate).getTime() +
        coolingDays * 24 * 60 * 60 * 1000);
      update.bookingStatus = 'completed';
      update.showToOthers = false;
      update.readyAnyTime = false;
    }

    const donor = await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: update },
      { upsert: true, new: true, runValidators: true }
    );

    res.status(201).json(donor);
  } catch (err) {
    console.error('[Donor POST /register]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /donors/me ─────────────────────────────────────────────────────────
// Partial update — used by venue preference, ready-any-time toggle, etc.
router.patch('/me', async (req, res) => {
  try {
    // Whitelist updatable fields to avoid accidental overwrites
    const allowed = [
      'readyAnyTime',
      'showToOthers',
      'preferredVenue',
      'bloodGroup',
      'lastDonationDate',
      'lastDonationUnits',
      'hospitalBookingActive',
      'bookingStatus',
      'donationStream',
      'preScreeningAnswers',
      'fullName', 'email', 'phone', 'profilePhotoUrl', 'dateOfBirth', 'gender', 'city', 'state',
      'pincode', 'preferredVenue', 'lastDonationType', 'lastDonationHospital',
      'healthEligibility', 'emergencyAvailable', 'consentAccepted',
    ];

    const update = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        // Convert ISO string dates to Date objects
        if ((key === 'lastDonationDate' || key === 'dateOfBirth') && req.body[key]) {
          update[key] = new Date(req.body[key]);
        } else {
          update[key] = req.body[key];
        }
      }
    }

    if (Object.keys(update).length === 0) {
      return res.status(400).json({ error: 'No updatable fields provided' });
    }

    const donor = await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: update },
      { new: true, upsert: true, runValidators: true }
    );

    res.json(donor);
  } catch (err) {
    console.error('[Donor PATCH /me]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /donors/search ───────────────────────────────────────────────────────
// Returns donors who have showToOthers=true, are registered, and are NOT
// currently in a cooling period (i.e. bookingStatus != 'completed', OR their
// last donation was long enough ago that they are eligible again).
// Used by SearchPage. Optional ?bloodGroup=O%2B filter.
router.get('/search', async (req, res) => {
  try {
    const { bloodGroup } = req.query;

    // Cooling periods: Platelets 7d, Plasma 28d, everything else 90d.
    // We use the most conservative value (90 days) as the server-side guard.
    // The client computes the exact period per stream, so this is belt-and-suspenders.
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

    const query = {
      showToOthers: true,
      registered:   true,
      // Never expose the signed-in donor's own profile in their search results.
      uid: { $ne: req.uid },
      // Exclude donors who completed a donation within the last 90 days
      $or: [
        { bookingStatus: { $ne: 'completed' } },
        { lastDonationDate: { $lte: ninetyDaysAgo } },
        { lastDonationDate: null },
      ],
    };
    if (bloodGroup) query.bloodGroup = bloodGroup;

    const donors = await Donor.find(query)
      .select('fullName bloodGroup city donationStream phone manualEntry uid')
      .sort({ createdAt: -1 })
      .lean();

    res.json(donors);
  } catch (err) {
    console.error('[Donor GET /search]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /donors/manual ───────────────────────────────────────────────────────
// Returns only manually-added donors (admin view).
router.get('/manual', async (req, res) => {
  try {
    const donors = await Donor.find({ manualEntry: true })
      .sort({ createdAt: -1 })
      .lean();
    res.json(donors);
  } catch (err) {
    console.error('[Donor GET /manual]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── POST /donors/manual ─────────────────────────────────────────────────────
// Admin adds a donor manually (no Firebase account needed).
router.post('/manual', async (req, res) => {
  try {
    const { fullName, bloodGroup, phone, city, donationStream, readyAnyTime } = req.body;

    if (!fullName || !bloodGroup) {
      return res.status(400).json({ error: 'fullName and bloodGroup are required' });
    }

    // Use phone as a pseudo-uid so we can upsert without a real Firebase uid
    const pseudoUid = `manual_${phone || Date.now()}`;

    const donor = await Donor.findOneAndUpdate(
      { uid: pseudoUid },
      {
        $set: {
          uid:            pseudoUid,
          fullName:       fullName.trim(),
          bloodGroup:     bloodGroup.trim(),
          phone:          phone          || '',
          city:           city           || '',
          donationStream: donationStream || 'Whole Blood',
          readyAnyTime:   readyAnyTime   !== false,
          showToOthers:   true,
          registered:     true,
          manualEntry:    true,
        },
      },
      { upsert: true, new: true, runValidators: false }
    );

    res.status(201).json(donor);
  } catch (err) {
    console.error('[Donor POST /manual]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── DELETE /donors/manual/:id ────────────────────────────────────────────────
// Admin removes a manually-added donor.
router.delete('/manual/:id', async (req, res) => {
  try {
    const donor = await Donor.findOneAndDelete({
      _id:         req.params.id,
      manualEntry: true,
    });
    if (!donor) return res.status(404).json({ error: 'Manual donor not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('[Donor DELETE /manual/:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
