const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const BloodRequest = require('../models/BloodRequest');
const Donor        = require('../models/Donor');

router.use(authenticate);

// ─── Expiry helper ────────────────────────────────────────────────────────────
function expiryHours(urgency) {
  if (urgency === 'Critical Red') return 12;
  if (urgency === 'Urgent')       return 24;
  return 48; // Standard
}

// ─── POST /blood-requests ─────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  try {
    const {
      patientName, patientAge, patientGender,
      bloodGroup, units, component, urgency,
      hospital, ward, bedNumber, hubZone,
      attender, contactPhone,
      targetFacilityName, targetFacilityUid, targetFacilityAddress, targetFacilityPhone,
      emergencyPushEnabled, notifyNss,
      attachmentFileName,
    } = req.body;

    if (!patientName || !bloodGroup || !units) {
      return res.status(400).json({ error: 'patientName, bloodGroup, and units are required' });
    }

    const now      = new Date();
    const hours    = expiryHours(urgency || 'Urgent');
    const expiresAt = new Date(now.getTime() + hours * 60 * 60 * 1000);

    const request = await BloodRequest.create({
      requesterUid:         req.uid,
      patientName,
      patientAge:           patientAge    || null,
      patientGender:        patientGender || 'Male',
      bloodGroup,
      units,
      component:            component     || 'Whole Blood',
      urgency:              urgency       || 'Urgent',
      hospital:             hospital      || '',
      ward:                 ward          || '',
      bedNumber:            bedNumber     || '',
      hubZone:              hubZone       || '',
      attender:             attender      || '',
      contactPhone:         contactPhone  || '',
      targetFacilityName:    targetFacilityName    || '',
      targetFacilityUid:     targetFacilityUid     || '',
      targetFacilityAddress: targetFacilityAddress || '',
      targetFacilityPhone:   targetFacilityPhone   || '',
      emergencyPushEnabled: emergencyPushEnabled !== false,
      notifyNss:            notifyNss     !== false,
      attachmentFileName:   attachmentFileName || null,
      status:               'received',
      unitsRemaining:       units,
      expiresAt,
      timeline: [{ step: 'Request Received', time: now, note: 'Confirmed by facility' }],
    });

    res.status(201).json(request);
  } catch (err) {
    console.error('[BloodRequest POST /]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /blood-requests/:id/respond ───────────────────────────────────────
// Donor commits to donating N units. Rules:
//   • Same blood group only
//   • No active commitment elsewhere
//   • One response per request per user
//   • Auto-fulfils when unitsRemaining hits 0
router.patch('/:id/respond', async (req, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Blood request not found' });

    if (request.requesterUid === req.uid) {
      return res.status(400).json({ error: 'You cannot respond to your own request' });
    }

    // Check expiry
    if (request.expiresAt && new Date() > request.expiresAt) {
      request.status = 'cancelled';
      request.timeline.push({ step: 'Expired', time: new Date(), note: 'Request expired' });
      await request.save();
      return res.status(400).json({ error: 'This request has expired' });
    }

    if (['fulfilled', 'cancelled'].includes(request.status)) {
      return res.status(400).json({ error: `Request is already ${request.status}` });
    }

    // ── Blood group check (same group only) ───────────────────────────────────
    const donor = await Donor.findOne({ uid: req.uid }).lean();
    const donorBloodGroup = donor?.bloodGroup || '';
    if (donorBloodGroup && donorBloodGroup !== request.bloodGroup) {
      return res.status(400).json({
        error: 'incompatible_blood_group',
        message: `This request needs ${request.bloodGroup} blood. Your blood group is ${donorBloodGroup}.`,
      });
    }

    // ── One active commitment rule ─────────────────────────────────────────────
    if (donor?.activeCommitmentRequestId) {
      // Verify the commitment request still exists and is open
      const activeReq = await BloodRequest.findById(donor.activeCommitmentRequestId).lean();
      if (activeReq && !['fulfilled', 'cancelled'].includes(activeReq.status)) {
        return res.status(409).json({
          error: 'active_commitment_exists',
          message: 'You already have an active commitment. Cancel it before responding to another request.',
          activeRequestId: donor.activeCommitmentRequestId,
        });
      }
      // Stale pointer — clear it
      await Donor.findOneAndUpdate({ uid: req.uid }, { $set: { activeCommitmentRequestId: null } });
    }

    // ── Duplicate guard ───────────────────────────────────────────────────────
    const alreadyResponded = request.responses.some(r => r.responderUid === req.uid);
    if (alreadyResponded) {
      return res.status(409).json({ error: 'already_responded' });
    }

    const { unitsCommitted, responderName } = req.body;
    const units = Math.max(1, Math.floor(Number(unitsCommitted) || 1));

    if (request.unitsRemaining == null) request.unitsRemaining = request.units;

    const actualUnits = Math.min(units, request.unitsRemaining);

    request.responses.push({
      responderUid:   req.uid,
      responderName:  responderName || '',
      unitsCommitted: actualUnits,
      respondedAt:    new Date(),
    });

    request.unitsRemaining = Math.max(0, request.unitsRemaining - actualUnits);

    request.timeline.push({
      step: 'Donor Responded',
      time: new Date(),
      note: `${responderName || 'A donor'} committed ${actualUnits} unit${actualUnits !== 1 ? 's' : ''}`,
    });

    if (request.unitsRemaining <= 0) {
      request.status = 'fulfilled';
      request.timeline.push({
        step: 'Request Fulfilled',
        time: new Date(),
        note: 'All required units have been committed by donors',
      });
    }

    await request.save();

    // Mark donor's active commitment
    await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: { activeCommitmentRequestId: request._id.toString() } },
      { upsert: true }
    );

    res.json(request);
  } catch (err) {
    console.error('[BloodRequest PATCH /:id/respond]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /blood-requests/:id/withdraw ──────────────────────────────────────
// Donor withdraws their response BEFORE donation.
// Restores unitsRemaining; re-opens request if it was fulfilled.
router.patch('/:id/withdraw', async (req, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Blood request not found' });

    const responseIdx = request.responses.findIndex(r => r.responderUid === req.uid);
    if (responseIdx === -1) {
      return res.status(400).json({ error: 'You have not responded to this request' });
    }

    const withdrawn = request.responses[responseIdx];

    // Remove the response entry
    request.responses.splice(responseIdx, 1);

    // Restore units
    if (request.unitsRemaining == null) request.unitsRemaining = 0;
    request.unitsRemaining += withdrawn.unitsCommitted;

    // Re-open if it was fulfilled
    if (request.status === 'fulfilled') {
      request.status = 'received';
      request.timeline.push({
        step: 'Re-opened',
        time: new Date(),
        note: `${withdrawn.responderName || 'A donor'} withdrew — ${withdrawn.unitsCommitted} unit${withdrawn.unitsCommitted !== 1 ? 's' : ''} need(s) a new donor`,
      });
    }

    request.timeline.push({
      step: 'Donor Withdrew',
      time: new Date(),
      note: `${withdrawn.responderName || 'A donor'} cancelled their commitment of ${withdrawn.unitsCommitted} unit${withdrawn.unitsCommitted !== 1 ? 's' : ''}`,
    });

    await request.save();

    // Clear donor's active commitment
    await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: { activeCommitmentRequestId: null } }
    );

    res.json(request);
  } catch (err) {
    console.error('[BloodRequest PATCH /:id/withdraw]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-requests/active ──────────────────────────────────────────────
// Returns all open, non-expired requests from OTHER users.
// Enriched per-caller with: hasResponded, canDonate, hasActiveCommitment, unitsRemaining, expiresAt.
router.get('/active', async (req, res) => {
  try {
    const now = new Date();

    // Auto-expire any overdue requests in bulk
    await BloodRequest.updateMany(
      { status: { $nin: ['cancelled', 'fulfilled'] }, expiresAt: { $lte: now } },
      { $set: { status: 'cancelled' }, $push: { timeline: { step: 'Expired', time: now, note: 'Request expired' } } }
    );

    const requests = await BloodRequest.find({
      requesterUid: { $ne: req.uid },
      status: { $nin: ['cancelled', 'fulfilled'] },
      // Facility-targeted requests belong only to that blood bank and must
      // never appear in the public donor feed.
      $and: [
        {
          $or: [
            { targetFacilityUid: { $exists: false } },
            { targetFacilityUid: '' },
            { targetFacilityUid: null },
          ],
        },
        {
          $or: [
            { targetFacilityName: { $exists: false } },
            { targetFacilityName: '' },
            { targetFacilityName: null },
          ],
        },
      ],
    })
      .sort({ createdAt: -1 })
      .lean();

    // Get caller's donor profile for blood group + active commitment check
    const donor = await Donor.findOne({ uid: req.uid }).lean();
    const donorBloodGroup         = donor?.bloodGroup || '';
    const activeCommitmentId      = donor?.activeCommitmentRequestId || null;
    const hasActiveCommitment     = !!activeCommitmentId;

    const enriched = requests.map(r => ({
      ...r,
      hasResponded:         (r.responses || []).some(resp => resp.responderUid === req.uid),
      unitsRemaining:       r.unitsRemaining != null ? r.unitsRemaining : r.units,
      // canDonate: donor has no blood group set (unregistered) OR blood groups match
      canDonate:            !donorBloodGroup || donorBloodGroup === r.bloodGroup,
      hasActiveCommitment:  hasActiveCommitment && activeCommitmentId !== r._id.toString(),
      isMyActiveCommitment: activeCommitmentId === r._id.toString(),
    }));

    res.json(enriched);
  } catch (err) {
    console.error('[BloodRequest GET /active]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-requests/my ───────────────────────────────────────────────────
router.get('/my', async (req, res) => {
  try {
    const requests = await BloodRequest.find({ requesterUid: req.uid })
      .sort({ createdAt: -1 })
      .lean();
    res.json(requests);
  } catch (err) {
    console.error('[BloodRequest GET /my]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-requests/:id ──────────────────────────────────────────────────
// Returns full request to the requester, enriched with donor contact details.
router.get('/:id', async (req, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id).lean();
    if (!request) return res.status(404).json({ error: 'Blood request not found' });
    if (request.requesterUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });

    // Enrich each response with the donor's phone and blood group from the Donor collection
    const enrichedResponses = await Promise.all(
      (request.responses || []).map(async (resp) => {
        const donor = await Donor.findOne({ uid: resp.responderUid })
          .select('phone bloodGroup fullName')
          .lean();
        return {
          ...resp,
          responderPhone:      donor?.phone      || '',
          responderBloodGroup: donor?.bloodGroup  || '',
          responderFullName:   donor?.fullName    || resp.responderName || '',
        };
      })
    );

    res.json({ ...request, responses: enrichedResponses });
  } catch (err) {
    console.error('[BloodRequest GET /:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /blood-requests/:id/cancel ────────────────────────────────────────
router.patch('/:id/cancel', async (req, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id);
    if (!request) return res.status(404).json({ error: 'Blood request not found' });
    if (request.requesterUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    if (['fulfilled', 'cancelled'].includes(request.status)) {
      return res.status(400).json({ error: `Cannot cancel a ${request.status} request` });
    }
    request.status = 'cancelled';
    request.timeline.push({ step: 'Cancelled', time: new Date(), note: 'Cancelled by requester' });
    await request.save();
    res.json(request);
  } catch (err) {
    console.error('[BloodRequest PATCH /:id/cancel]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
