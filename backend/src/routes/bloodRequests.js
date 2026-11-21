const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const BloodRequest = require('../models/BloodRequest');
const Donor        = require('../models/Donor');
const BloodBankAccount = require('../models/BloodBankAccount');
const BloodBank = require('../models/BloodBank');
const {
  createFacilityResolver,
  FacilitySelectionError,
} = require('../facilities/facilitySelection');
const {
  serializeBloodRequest,
  serializeRequesterBloodRequest,
} = require('../privacy/donorResponses');
const { createTransactionRunner, sendTransactionUnavailable } = require('../db/transactions');
const { commitUnits, withdrawUnits } = require('../bloodRequests/commitUnits');

const runInTransaction = createTransactionRunner(() => BloodRequest.startSession());

const resolveFacilitySelection = createFacilityResolver({
  findAccountByRef: (facilityRef) => BloodBankAccount.find({
    facilityRef,
    isVerified: true,
    isActive: true,
  }).limit(2).select('name address city phone isVerified isActive').lean(),
  findDirectoryById: (id) => BloodBank.findOne({ _id: id, isVerified: true })
    .select('name address city phone isVerified').lean(),
});

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
      targetFacilityRef, targetFacilityDirectoryId,
      targetFacilityName, targetFacilityUid, targetFacilityAddress, targetFacilityPhone,
      emergencyPushEnabled, notifyNss,
      attachmentFileName,
    } = req.body;

    if (!patientName || !bloodGroup || !units) {
      return res.status(400).json({ error: 'patientName, bloodGroup, and units are required' });
    }

    const hasLegacyTargetFields = [
      targetFacilityName, targetFacilityUid, targetFacilityAddress, targetFacilityPhone,
    ].some((value) => typeof value === 'string' && value.trim() !== '');
    const hasFacilityReference = Boolean(targetFacilityRef || targetFacilityDirectoryId);
    let facility = null;
    if (hasFacilityReference || hasLegacyTargetFields) {
      facility = await resolveFacilitySelection({
        facilityRef: targetFacilityRef,
        directoryId: targetFacilityDirectoryId,
      });
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
      targetFacilityAccountId: facility?.facilityAccountId,
      targetFacilityDirectoryId: facility?.facilityDirectoryId,
      targetFacilityName: facility?.facilityName || '',
      targetFacilityAddress: facility?.facilityAddress || '',
      targetFacilityPhone: facility?.facilityPhone || '',
      emergencyPushEnabled: emergencyPushEnabled !== false,
      notifyNss:            notifyNss     !== false,
      attachmentFileName:   attachmentFileName || null,
      status:               'received',
      unitsRemaining:       units,
      expiresAt,
      timeline: [{ step: 'Request Received', time: now, note: 'Confirmed by facility' }],
    });

    return res.status(201).json(serializeRequesterBloodRequest(request));
  } catch (err) {
    if (err instanceof FacilitySelectionError) {
      return res.status(err.status).json({ error: err.code });
    }
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
    const result = await runInTransaction(async (session) => {
      const outcome = { statusCode: 200, body: null };
      const reply = {
        status(code) { outcome.statusCode = code; return this; },
        json(body) { outcome.body = body; return body; },
      };
      const request = await BloodRequest.findById(req.params.id)
        .select('+targetFacilityAccountId +targetFacilityDirectoryId')
        .session(session);
      if (!request) { reply.status(404).json({ error: 'Blood request not found' }); return outcome; }
      const hasFacilityTarget = Boolean(
        request.targetFacilityAccountId || request.targetFacilityDirectoryId ||
        request.targetFacilityUid || request.targetFacilityName ||
        request.targetFacilityAddress || request.targetFacilityPhone
      );
      if (hasFacilityTarget) { reply.status(403).json({ error: 'request_not_available' }); return outcome; }
      if (request.requesterUid === req.uid) {
        reply.status(400).json({ error: 'You cannot respond to your own request' }); return outcome;
      }
      if (request.expiresAt && new Date() > request.expiresAt) {
        request.status = 'cancelled';
        request.timeline.push({ step: 'Expired', time: new Date(), note: 'Request expired' });
        await request.save({ session });
        reply.status(400).json({ error: 'This request has expired' }); return outcome;
      }
      if (['fulfilled', 'cancelled'].includes(request.status)) {
        reply.status(400).json({ error: `Request is already ${request.status}` }); return outcome;
      }

      const donor = await Donor.findOne({ uid: req.uid }).session(session).lean();
      const donorBloodGroup = donor?.bloodGroup || '';
      if (donorBloodGroup && donorBloodGroup !== request.bloodGroup) {
        reply.status(400).json({
          error: 'incompatible_blood_group',
          message: `This request needs ${request.bloodGroup} blood. Your blood group is ${donorBloodGroup}.`,
        });
        return outcome;
      }

      if (donor?.activeCommitmentRequestId) {
        const activeReq = await BloodRequest.findById(donor.activeCommitmentRequestId).session(session).lean();
        if (activeReq && !['fulfilled', 'cancelled'].includes(activeReq.status)) {
          reply.status(409).json({
            error: 'active_commitment_exists',
            message: 'You already have an active commitment. Cancel it before responding to another request.',
            activeRequestId: donor.activeCommitmentRequestId,
          });
          return outcome;
        }
        await Donor.findOneAndUpdate(
          { uid: req.uid, activeCommitmentRequestId: donor.activeCommitmentRequestId },
          { $set: { activeCommitmentRequestId: null } },
          { session },
        );
      }
      if (request.responses.some((response) => response.responderUid === req.uid)) {
        reply.status(409).json({ error: 'already_responded' }); return outcome;
      }

      const { unitsCommitted, responderName } = req.body;
      const units = Math.max(1, Math.floor(Number(unitsCommitted) || 1));
      const commitResult = await commitUnits({
        BloodRequest,
        request,
        uid: req.uid,
        units,
        responderName,
        session,
      });
      if (commitResult?.reason === 'no_units_remaining') {
        reply.status(409).json({ error: 'no_units_remaining' }); return outcome;
      }
      if (commitResult?.reason === 'request_expired') {
        reply.status(400).json({ error: 'This request has expired' }); return outcome;
      }
      if (commitResult?.reason === 'request_not_available') {
        reply.status(409).json({ error: 'request_not_available' }); return outcome;
      }
      if (!commitResult) {
        reply.status(409).json({ error: 'request_commitment_conflict' }); return outcome;
      }
      const committedRequest = commitResult.request;
      await Donor.findOneAndUpdate(
        { uid: req.uid },
        { $set: { activeCommitmentRequestId: committedRequest._id.toString() } },
        { upsert: true, session },
      );
      reply.json(serializeBloodRequest(committedRequest, req.uid));
      return outcome;
    });
    return res.status(result.statusCode).json(result.body);
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[BloodRequest PATCH /:id/respond]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});
router.patch('/:id/withdraw', async (req, res) => {
  try {
    const result = await runInTransaction(async (session) => {
      const outcome = { statusCode: 200, body: null };
      const reply = {
        status(code) { outcome.statusCode = code; return this; },
        json(body) { outcome.body = body; return body; },
      };
      const request = await BloodRequest.findById(req.params.id).session(session);
      if (!request) { reply.status(404).json({ error: 'Blood request not found' }); return outcome; }
      const withdrawResult = await withdrawUnits({
        BloodRequest,
        request,
        uid: req.uid,
        session,
      });
      if (withdrawResult?.reason === 'commitment_not_found') {
        reply.status(400).json({ error: 'You have not responded to this request' }); return outcome;
      }
      if (withdrawResult?.reason === 'request_units_inconsistent') {
        reply.status(409).json({ error: 'request_units_inconsistent' }); return outcome;
      }
      if (withdrawResult?.reason === 'commitment_invalid') {
        reply.status(409).json({ error: 'commitment_invalid' }); return outcome;
      }
      if (!withdrawResult) {
        reply.status(409).json({ error: 'request_commitment_conflict' }); return outcome;
      }
      await Donor.findOneAndUpdate(
        { uid: req.uid, activeCommitmentRequestId: request._id.toString() },
        { $set: { activeCommitmentRequestId: null } },
        { session },
      );
      reply.json(serializeBloodRequest(withdrawResult.request, req.uid));
      return outcome;
    });
    return res.status(result.statusCode).json(result.body);
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[BloodRequest PATCH /:id/withdraw]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});
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
            { targetFacilityAccountId: { $exists: false } },
            { targetFacilityAccountId: null },
          ],
        },
        {
          $or: [
            { targetFacilityDirectoryId: { $exists: false } },
            { targetFacilityDirectoryId: null },
          ],
        },
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
        {
          $or: [
            { targetFacilityAddress: { $exists: false } },
            { targetFacilityAddress: '' },
            { targetFacilityAddress: null },
          ],
        },
        {
          $or: [
            { targetFacilityPhone: { $exists: false } },
            { targetFacilityPhone: '' },
            { targetFacilityPhone: null },
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

    return res.json(enriched.map((request) => serializeBloodRequest(request, req.uid)));
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
    return res.json(requests.map(serializeRequesterBloodRequest));
  } catch (err) {
    console.error('[BloodRequest GET /my]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /blood-requests/:id ──────────────────────────────────────────────────
// Returns the request to its owner without responder identifiers or contacts.
router.get('/:id', async (req, res) => {
  try {
    const request = await BloodRequest.findById(req.params.id)
      .select('+targetFacilityAccountId +targetFacilityDirectoryId')
      .lean();
    if (!request) return res.status(404).json({ error: 'Blood request not found' });
    if (request.requesterUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });

    return res.json(serializeRequesterBloodRequest(request));
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
    return res.json(serializeRequesterBloodRequest(request));
  } catch (err) {
    console.error('[BloodRequest PATCH /:id/cancel]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
