const express = require('express');
const { randomUUID } = require('node:crypto');
const router = express.Router();
const authenticate = require('../middleware/auth');
const requireVerifiedBloodBank = require('../middleware/requireVerifiedBloodBank');
const BloodBankAccount = require('../models/BloodBankAccount');
const BloodRequest = require('../models/BloodRequest');
const Donor = require('../models/Donor');
const Booking = require('../models/Booking');
const { facilityOwnershipFilter } = require('../facilities/facilitySelection');
const {
  serializeFacilityDonation,
  serializeFacilityBloodRequest,
} = require('../privacy/donorResponses');
const { createTransactionRunner, sendTransactionUnavailable } = require('../db/transactions');

const runInTransaction = createTransactionRunner(() => Booking.startSession());

// Called after Firebase signup. Approval and active state are always server-set.
router.post('/register', authenticate, async (req, res) => {
  try {
    const {
      name, registrationNo, email, phone, website,
      address, city, state, pincode, hours,
    } = req.body;

    if (!name || !email) {
      return res.status(400).json({ error: 'name and email are required' });
    }

    const existing = await BloodBankAccount.findOne({ uid: req.uid });
    if (existing) {
      return res.status(409).json({ error: 'already_registered', account: existing });
    }

    const account = await BloodBankAccount.create({
      uid: req.uid,
      facilityRef: randomUUID(),
      name: name.trim(),
      registrationNo: registrationNo || '',
      email: email.toLowerCase().trim(),
      phone: phone || '',
      website: website || '',
      address: address || '',
      city: city || '',
      state: state || '',
      pincode: pincode || '',
      hours: hours || '8:00 AM – 6:00 PM',
      stock: {},
      slots: [],
      doctors: [],
      nurses: [],
      isVerified: false,
    });

    return res.status(201).json(account);
  } catch (err) {
    console.error('[BloodBankAccount POST /register]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// The profile/status endpoints remain available to authenticated pending banks.
router.use(authenticate);

router.get('/me', async (req, res) => {
  try {
    const account = await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) return res.status(404).json({ error: 'not_registered' });

    const stock = account.stock instanceof Map
      ? Object.fromEntries(account.stock)
      : (account.stock || {});
    return res.json({ ...account, stock });
  } catch (err) {
    console.error('[BloodBankAccount GET /me]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

const operationalFields = ['stock', 'slots', 'doctors', 'nurses'];
const approvalRequiredFields = ['hours', ...operationalFields];
const profileFields = [
  'name', 'registrationNo', 'phone', 'website',
  'address', 'city', 'state', 'pincode',
];
const updateFields = [...profileFields, 'hours', ...operationalFields];

router.patch('/me', async (req, res, next) => {
  if (approvalRequiredFields.some((field) => req.body[field] !== undefined)) {
    return requireVerifiedBloodBank(req, res, next);
  }
  return next();
}, async (req, res) => {
  try {
    const update = {};
    for (const key of updateFields) {
      if (req.body[key] !== undefined) update[key] = req.body[key];
    }
    if (Object.keys(update).length === 0) {
      return res.status(400).json({ error: 'No updatable fields provided' });
    }

    const account = req.bankAccount || await BloodBankAccount.findOne({ uid: req.uid }).lean();
    if (!account) return res.status(404).json({ error: 'not_registered' });
    // Pending and inactive accounts may correct basic profile fields, but cannot
    // change hours, stock, slots, or staff. Verification flags are never writable.
    if (approvalRequiredFields.some((field) => update[field] !== undefined) &&
        (!req.bankAccount || account.isVerified !== true || account.isActive !== true)) {
      return res.status(403).json({
        error: account.isActive === false ? 'bank_inactive' : 'bank_not_verified',
      });
    }

    const updated = await BloodBankAccount.findOneAndUpdate(
      { uid: req.uid },
      { $set: update },
      { new: true, runValidators: true },
    ).lean();
    if (!updated) return res.status(404).json({ error: 'not_registered' });

    const stock = updated.stock instanceof Map
      ? Object.fromEntries(updated.stock)
      : (updated.stock || {});
    return res.json({ ...updated, stock });
  } catch (err) {
    console.error('[BloodBankAccount PATCH /me]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/active-requests', requireVerifiedBloodBank, async (req, res) => {
  try {
    const account = req.bankAccount;
    const ownership = facilityOwnershipFilter('targetFacilityAccountId', account);
    if (!ownership) return res.status(403).json({ error: 'bank_ownership_unavailable' });
    const now = new Date();
    await BloodRequest.updateMany(
      { status: { $nin: ['cancelled', 'fulfilled'] }, expiresAt: { $lte: now } },
      {
        $set: { status: 'cancelled' },
        $push: { timeline: { step: 'Expired', time: now, note: 'Request expired' } },
      },
    );

    const requests = await BloodRequest.find({
      ...ownership,
      status: { $nin: ['cancelled', 'fulfilled'] },
    }).sort({ createdAt: -1 }).lean();
    return res.json(requests.map(serializeFacilityBloodRequest));
  } catch (err) {
    console.error('[BloodBankAccount GET /active-requests]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/requests/:id/review', requireVerifiedBloodBank, async (req, res) => {
  try {
    const account = req.bankAccount;
    const ownership = facilityOwnershipFilter('targetFacilityAccountId', account);
    if (!ownership) return res.status(403).json({ error: 'bank_ownership_unavailable' });
    const request = await BloodRequest.findOne({ _id: req.params.id, ...ownership });
    if (!request) return res.status(404).json({ error: 'Blood request not found' });

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
    return res.json(serializeFacilityBloodRequest(request));
  } catch (err) {
    console.error('[BloodBank PATCH /requests/:id/review]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.get('/stats', requireVerifiedBloodBank, async (req, res) => {
  try {
    const account = req.bankAccount;
    const ownership = facilityOwnershipFilter('targetFacilityAccountId', account);
    if (!ownership) return res.status(403).json({ error: 'bank_ownership_unavailable' });
    const [totalUsers, openRequests] = await Promise.all([
      Donor.countDocuments({ registered: true }),
      BloodRequest.countDocuments({
        ...ownership,
        status: { $nin: ['cancelled', 'fulfilled'] },
      }),
    ]);
    const stock = account.stock instanceof Map
      ? Object.fromEntries(account.stock)
      : (account.stock || {});
    const totalUnits = Object.values(stock).reduce((sum, value) => sum + (Number(value) || 0), 0);
    return res.json({
      name: account.name,
      isVerified: account.isVerified,
      totalUnits,
      stockGroups: Object.keys(stock).length,
      totalUsers,
      openRequests,
      doctors: (account.doctors || []).length,
      nurses: (account.nurses || []).length,
      slots: (account.slots || []).length,
    });
  } catch (err) {
    console.error('[BloodBankAccount GET /stats]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// Registered at startup (not from inside another request handler).
router.get('/donations/pending', requireVerifiedBloodBank, async (req, res) => {
  try {
    const ownership = facilityOwnershipFilter('facilityAccountId', req.bankAccount);
    if (!ownership) return res.status(403).json({ error: 'bank_ownership_unavailable' });
    const donations = await Booking.find({
      ...ownership,
      status: 'completed',
      proofStatus: 'pending',
    }).select('_id donorName bloodGroup component bookingRef status donatedAt proofStatus createdAt')
      .sort({ donatedAt: -1 }).lean();
    return res.json(donations.map(serializeFacilityDonation));
  } catch (err) {
    console.error('[BloodBank GET /donations/pending]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/donations/:id/verify', requireVerifiedBloodBank, async (req, res) => {
  try {
    const result = await runInTransaction(async (session) => {
      const outcome = { statusCode: 200, body: null };
      const reply = {
        status(code) { outcome.statusCode = code; return this; },
        json(body) { outcome.body = body; return body; },
      };
      const ownership = facilityOwnershipFilter('facilityAccountId', req.bankAccount);
      if (!ownership) { reply.status(403).json({ error: 'bank_ownership_unavailable' }); return outcome; }
      const booking = await Booking.findOne({ _id: req.params.id, ...ownership }).session(session);
      if (!booking) { reply.status(404).json({ error: 'Donation not found' }); return outcome; }
      if (booking.status !== 'completed') {
        reply.status(409).json({ error: 'Donation is not completed' }); return outcome;
      }
      if (booking.proofStatus !== 'pending') {
        reply.status(409).json({ error: 'Donation proof was already reviewed' }); return outcome;
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
      }
      await booking.save({ session });
      reply.json(serializeFacilityDonation(booking));
      return outcome;
    });
    return res.status(result.statusCode).json(result.body);
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[BloodBank PATCH /donations/:id/verify]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});
router.get('/all', async (_req, res) => {
  try {
    const accounts = await BloodBankAccount.find({
      isActive: true,
      isVerified: true,
      facilityRef: { $type: 'string', $ne: '' },
    })
      .select({
        _id: 0,
        facilityRef: 1,
        name: 1,
        address: 1,
        city: 1,
        phone: 1,
        hours: 1,
        isVerified: 1,
        stock: 1,
      })
      .sort({ createdAt: -1 })
      .lean();
    const enriched = accounts.map((account) => ({
      facilityRef: account.facilityRef,
      name: account.name,
      address: account.address,
      city: account.city,
      phone: account.phone,
      hours: account.hours,
      isVerified: account.isVerified,
      stock: account.stock instanceof Map
        ? Object.fromEntries(account.stock)
        : (account.stock || {}),
    }));
    return res.json(enriched);
  } catch (err) {
    console.error('[BloodBankAccount GET /all]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
