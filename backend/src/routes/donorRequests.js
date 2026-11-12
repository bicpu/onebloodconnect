const express       = require('express');
const router        = express.Router();
const authenticate  = require('../middleware/auth');
const DonorRequest  = require('../models/DonorRequest');
const Donor         = require('../models/Donor');

router.use(authenticate);

// ─── POST /donor-requests ─────────────────────────────────────────────────────
// Requester sends a contact request to a specific donor.
router.post('/', async (req, res) => {
  try {
    const {
      donorId,
      donorUid,        // Flutter now sends this alongside donorId
      patientName, patientAge, patientGender,
      bloodGroup, units, component, urgency,
      hospital, ward, bedNumber,
      attender, contactPhone,
      requesterName, requesterPhone,
    } = req.body;

    if (!patientName || !bloodGroup || !units) {
      return res.status(400).json({ error: 'patientName, bloodGroup, and units are required' });
    }

    // Look up donor — prefer uid lookup (reliable string) over ObjectId (can be empty)
    let donor = null;
    if (donorUid) {
      donor = await Donor.findOne({ uid: donorUid }).lean();
    }
    if (!donor && donorId) {
      try { donor = await Donor.findById(donorId).lean(); } catch (_) {}
    }
    if (!donor) return res.status(404).json({ error: 'Donor not found' });

    // Prevent the donor from contacting themselves
    if (donor.uid === req.uid) {
      return res.status(400).json({ error: 'You cannot contact yourself as a donor' });
    }

    const request = await DonorRequest.create({
      requesterUid:    req.uid,
      requesterName:   requesterName || '',
      requesterPhone:  requesterPhone || '',
      donorId:         donor._id,
      donorUid:        donor.uid,      // store the Firebase UID for reliable inbox lookup
      donorName:       donor.fullName || '',
      donorBloodGroup: donor.bloodGroup || '',
      patientName,
      patientAge:      patientAge  || null,
      patientGender:   patientGender || 'Male',
      bloodGroup,
      units,
      component:       component   || 'Whole Blood',
      urgency:         urgency     || 'Urgent',
      hospital:        hospital    || '',
      ward:            ward        || '',
      bedNumber:       bedNumber   || '',
      attender:        attender    || '',
      contactPhone:    contactPhone || '',
    });

    res.status(201).json(request);
  } catch (err) {
    console.error('[DonorRequest POST /]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /donor-requests/sent ─────────────────────────────────────────────────
// Returns all requests sent BY the current user (requester view).
router.get('/sent', async (req, res) => {
  try {
    const requests = await DonorRequest.find({ requesterUid: req.uid })
      .sort({ createdAt: -1 })
      .lean();
    res.json(requests);
  } catch (err) {
    console.error('[DonorRequest GET /sent]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /donor-requests/inbox ────────────────────────────────────────────────
// Returns all requests sent TO the current user (donor inbox).
// Queries by donorUid (Firebase UID string) — avoids ObjectId mismatch.
router.get('/inbox', async (req, res) => {
  try {
    const requests = await DonorRequest.find({
      donorUid: req.uid,
      status:   { $nin: ['cancelled'] },
    })
      .sort({ createdAt: -1 })
      .lean();

    res.json(requests);
  } catch (err) {
    console.error('[DonorRequest GET /inbox]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /donor-requests/:id ──────────────────────────────────────────────────
// Returns a single request. Accessible by the requester or the target donor.
router.get('/:id', async (req, res) => {
  try {
    const request = await DonorRequest.findById(req.params.id).lean();
    if (!request) return res.status(404).json({ error: 'Request not found' });

    // Check the caller is either the requester or the donor (use donorUid string — avoids ObjectId issues)
    const isDonor     = request.donorUid === req.uid;
    const isRequester = request.requesterUid === req.uid;

    if (!isDonor && !isRequester) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json(request);
  } catch (err) {
    console.error('[DonorRequest GET /:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /donor-requests/:id/accept ────────────────────────────────────────
// Donor accepts the request. Sets status=accepted, confirmedAt, optional note.
router.patch('/:id/accept', async (req, res) => {
  try {
    const request = await DonorRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });

    if (request.donorUid !== req.uid) {
      return res.status(403).json({ error: 'Only the target donor can accept this request' });
    }

    if (request.status !== 'pending') {
      return res.status(400).json({ error: `Cannot accept a ${request.status} request` });
    }

    request.status      = 'accepted';
    request.confirmedAt = new Date();
    request.donorNote   = req.body.donorNote || '';
    await request.save();

    res.json(request);
  } catch (err) {
    console.error('[DonorRequest PATCH /:id/accept]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /donor-requests/:id/decline ───────────────────────────────────────
// Donor declines the request.
router.patch('/:id/decline', async (req, res) => {
  try {
    const request = await DonorRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });

    if (request.donorUid !== req.uid) {
      return res.status(403).json({ error: 'Only the target donor can decline this request' });
    }

    if (!['pending', 'accepted'].includes(request.status)) {
      return res.status(400).json({ error: `Cannot decline a ${request.status} request` });
    }

    request.status       = 'declined';
    request.cancelledBy  = 'donor';
    request.cancelReason = req.body.reason || '';
    await request.save();

    res.json(request);
  } catch (err) {
    console.error('[DonorRequest PATCH /:id/decline]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /donor-requests/:id/cancel ────────────────────────────────────────
// Requester cancels the request (before donation).
router.patch('/:id/cancel', async (req, res) => {
  try {
    const request = await DonorRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });

    if (request.requesterUid !== req.uid) {
      return res.status(403).json({ error: 'Only the requester can cancel this request' });
    }

    if (['donated', 'completed'].includes(request.status)) {
      return res.status(400).json({ error: `Cannot cancel a ${request.status} request` });
    }

    request.status       = 'cancelled';
    request.cancelledBy  = 'requester';
    request.cancelReason = req.body.reason || '';
    await request.save();

    res.json(request);
  } catch (err) {
    console.error('[DonorRequest PATCH /:id/cancel]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /donor-requests/:id/complete ──────────────────────────────────────
// Donor marks donation as done, uploads proof.
// Also sets showToOthers=false and enters cooling period on the Donor document.
router.patch('/:id/complete', async (req, res) => {
  try {
    const request = await DonorRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Request not found' });

    if (request.donorUid !== req.uid) {
      return res.status(403).json({ error: 'Only the target donor can complete this request' });
    }

    if (request.status !== 'accepted') {
      return res.status(400).json({ error: 'Request must be accepted before completing' });
    }

    const { donationPhotoUrl, doctorSlipUrl } = req.body;

    const donatedAt = new Date();
    request.status           = 'completed';
    request.donatedAt        = donatedAt;
    request.donationPhotoUrl = donationPhotoUrl || '';
    request.doctorSlipUrl    = doctorSlipUrl    || '';
    await request.save();

    // Compute cooling period (use component on the request)
    const component = (request.component || '').toLowerCase();
    let coolingDays = 90;
    if (component.includes('platelet')) coolingDays = 7;
    else if (component.includes('plasma')) coolingDays = 28;

    // Hide donor from search + update last donation
    const donor = await Donor.findOne({ uid: req.uid });
    const nextDonationUnits = Number(donor?.lastDonationUnits ?? 0) + 1;
    await Donor.findOneAndUpdate(
      { uid: req.uid },
      {
        $set: {
          lastDonationDate:      donatedAt,
          lastDonationUnits:    nextDonationUnits,
          hospitalBookingActive: false,
          bookingStatus:         'completed',
          showToOthers:          false,
          readyAnyTime:          false,
        },
      },
      { upsert: true, new: true }
    );

    res.json({ ...request.toObject(), coolingDays });
  } catch (err) {
    console.error('[DonorRequest PATCH /:id/complete]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
