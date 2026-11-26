const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const Booking      = require('../models/Booking');
const Donor        = require('../models/Donor');
const BloodBankAccount = require('../models/BloodBankAccount');
const BloodBank = require('../models/BloodBank');
const privateImageStore = require('../storage/privateImageStore');
const sendPrivateImage = require('../storage/imageResponse');
const { PrivateImageError } = require('../storage/privateImageStore');
const { serializeBooking } = require('../privacy/donorResponses');
const { isActiveBookingDuplicateError } = require('../bookings/bookingErrors');
const {
  createTransactionRunner,
  sendTransactionUnavailable,
} = require('../db/transactions');
const {
  createFacilityResolver,
  FacilitySelectionError,
} = require('../facilities/facilitySelection');

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

const ACTIVE_BOOKING_STATUSES = ['booked', 'confirmed'];
const runInTransaction = createTransactionRunner(() => Booking.startSession());

async function normalizePendingDonationDate(booking) {
  if (
    booking?.status === 'completed' &&
    booking.proofStatus === 'pending' &&
    booking.slotDate &&
    (!booking.donatedAt ||
      new Date(booking.donatedAt).getTime() !== new Date(booking.slotDate).getTime())
  ) {
    booking.donatedAt = new Date(booking.slotDate);
    booking.coolingEndsAt = new Date(booking.slotDate);
    booking.coolingEndsAt.setDate(
      booking.coolingEndsAt.getDate() + (booking.coolingDays || 90),
    );
    await booking.save();
  }
  return booking;
}

// ─── POST /bookings ───────────────────────────────────────────────────────────
// Create a new hospital slot booking (from BookHospitalSlotPage).
router.post('/', async (req, res) => {
  try {
    const {
      facilityRef, facilityDirectoryId,
      slotDate, slotTime,
      donorName, bloodGroup, component, coolingDays,
      units,
    } = req.body;

    if (!slotDate) {
      return res.status(400).json({ error: 'slotDate is required' });
    }
    const facility = await resolveFacilitySelection({ facilityRef, directoryId: facilityDirectoryId });

    // Prevent duplicate active bookings — only one at a time
    const existing = await Booking.findOne({
      donorUid: req.uid,
      status:   { $in: ACTIVE_BOOKING_STATUSES },
    });
    if (existing) {
      return res.status(409).json({
        error:   'active_booking_exists',
        booking: serializeBooking(existing),
        message: 'You already have an active booking. Complete or cancel it before booking again.',
      });
    }

    const year       = new Date().getFullYear();
    const rand       = Math.floor(1000 + Math.random() * 9000);
    const bookingRef = `OBC-APP-${year}-${rand}`;

    const booking = await runInTransaction(async (session) => {
      const created = new Booking({
        donorUid: req.uid,
        facilityAccountId: facility.facilityAccountId,
        facilityDirectoryId: facility.facilityDirectoryId,
        facilityName: facility.facilityName,
        facilityAddress: facility.facilityAddress,
        facilityPhone: facility.facilityPhone,
        slotDate: new Date(slotDate),
        slotTime: slotTime || '',
        bookingRef,
        status: 'confirmed',
        donorName: donorName || '',
        bloodGroup: bloodGroup || '',
        component: component || 'Whole Blood',
        coolingDays: coolingDays || 90,
        units: units || 1,
      });
      await created.save({ session });
      await Donor.findOneAndUpdate(
        { uid: req.uid },
        { $set: { hospitalBookingActive: true, bookingStatus: 'confirmed' } },
        { upsert: true, session },
      );
      return created;
    });

      res.status(201).json(serializeBooking(booking));
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    if (err instanceof FacilitySelectionError) {
      return res.status(err.status).json({ error: err.code });
    }
    if (isActiveBookingDuplicateError(err)) {
      let booking = null;
      try {
        booking = await Booking.findOne({
          donorUid: req.uid,
          status: { $in: ACTIVE_BOOKING_STATUSES },
        }).lean();
      } catch (_) {
        // The unique-index conflict is definitive even if fetching the
        // existing booking for the response fails.
      }
      return res.status(409).json({
        error: 'active_booking_exists',
        booking: booking ? serializeBooking(booking) : null,
        message: 'You already have an active booking. Complete or cancel it before booking again.',
      });
    }
    console.error('[Booking POST /]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/active ─────────────────────────────────────────────────────
// Returns the most recent active OR recently-completed booking for the user.
// Also returns cooling period info if the user just donated.
router.get('/active', async (req, res) => {
  try {
    // First check for an active (upcoming/confirmed) booking
    const active = await Booking.findOne({
      donorUid: req.uid,
      status:   { $in: ['booked', 'confirmed'] },
    })
      .sort({ createdAt: -1 })
      .lean();

    if (active) {
      return res.json({ active: true, booking: serializeBooking(active) });
    }

    const pending = await Booking.findOne({
      donorUid: req.uid,
      status: 'completed',
      proofStatus: { $in: ['pending', 'rejected', 'appealed'] },
    }).sort({ donatedAt: -1 }).lean();
    if (pending) {
      await normalizePendingDonationDate(await Booking.findById(pending._id));
      pending.donatedAt = pending.slotDate;
      return res.json({
        active: false,
        pending: pending.proofStatus === 'pending',
        needsAction: pending.proofStatus === 'rejected',
        appealed: pending.proofStatus === 'appealed',
        cooling: false,
        booking: serializeBooking(pending),
      });
    }

    // Then return the latest completed donation so the donor can see the
    // cooling countdown or their certificate even after the period ends.
    const now       = new Date();
    const cooling   = await Booking.findOne({
      donorUid:      req.uid,
      status:        'completed',
      proofStatus: 'approved',
    })
      .sort({ donatedAt: -1 })
      .lean();

    if (cooling) {
      // Older approved records may not have donatedAt/coolingEndsAt populated.
      // Use the booked donation date so the user still reaches the status page.
      const donatedAt = cooling.donatedAt || cooling.slotDate;
      const coolingDays = Number(cooling.coolingDays || 90);
      const coolingEndsAt = cooling.coolingEndsAt ||
        new Date(new Date(donatedAt).getTime() + coolingDays * 24 * 60 * 60 * 1000);
      return res.json({
        active: false,
        cooling: true,
        coolingComplete: coolingEndsAt <= now,
        booking: {
          ...serializeBooking(cooling),
          donatedAt,
          coolingDays,
          coolingEndsAt,
        },
      });
    }

    res.json({ active: false, cooling: false });
  } catch (err) {
    console.error('[Booking GET /active]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/appeal ──────────────────────────────────────────────
router.patch('/:id/appeal', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    if (booking.proofStatus !== 'rejected') {
      return res.status(409).json({ error: 'Only rejected proof can be appealed' });
    }
    const appealReason = String(req.body.reason || '').trim();
    if (!appealReason) return res.status(400).json({ error: 'Appeal reason is required' });
    booking.proofStatus = 'appealed';
    booking.appealReason = appealReason;
    booking.appealedAt = new Date();
    await booking.save();
    res.json(serializeBooking(booking));
  } catch (err) {
    console.error('[Booking PATCH /:id/appeal]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/history ───────────────────────────────────────────────────
router.get('/history', async (req, res) => {
  try {
    const bookings = await Booking.find({ donorUid: req.uid })
      .sort({ createdAt: -1 })
      .lean();
    res.json(bookings.map(serializeBooking));
  } catch (err) {
    console.error('[Booking GET /history]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/:id ────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    // Scope the fetch to the authenticated donor before the legacy date
    // normalizer can save any changes to the booking.
    const bookingDoc = await Booking.findOne({ _id: req.params.id, donorUid: req.uid });
    const booking = bookingDoc ? await normalizePendingDonationDate(bookingDoc) : null;
    if (!booking)                        return res.status(404).json({ error: 'Booking not found' });
    res.json(serializeBooking(booking));
  } catch (err) {
    console.error('[Booking GET /:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/:id/certificate ──────────────────────────────────────────
router.get('/:id/certificate', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id)
      .select('donorUid proofStatus certificateNo certificateIssuedAt bookingRef').lean();
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    if (booking.proofStatus !== 'approved' || !booking.certificateNo) {
      return res.status(404).json({ error: 'Certificate is not available yet' });
    }
    res.json({
      certificateNo: booking.certificateNo,
      issuedAt: booking.certificateIssuedAt,
      donorName: booking.donorName,
      bloodGroup: booking.bloodGroup,
      component: booking.component,
      donatedAt: booking.donatedAt || booking.slotDate,
      facilityName: booking.facilityName,
      bookingRef: booking.bookingRef,
    });
  } catch (err) {
    console.error('[Booking GET /:id/certificate]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:id/proof/:kind', async (req, res) => {
  try {
    const fields = {
      'donation-photo': ['donationPhoto', 'donationPhotoUrl'],
      'doctor-slip': ['doctorSlip', 'doctorSlipUrl'],
    }[req.params.kind];
    if (!fields) return res.status(404).json({ error: 'image_not_found' });
    const booking = await Booking.findOne({ _id: req.params.id, donorUid: req.uid });
    if (!booking) return res.status(404).json({ error: 'image_not_found' });
    return sendPrivateImage(res, booking[fields[0]], booking[fields[1]]);
  } catch (err) {
    console.error('[Booking GET proof] Private image lookup failed');
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/complete ─────────────────────────────────────────────
// Donor marks their donation as done.
// Body: { donationPhotoUrl, doctorSlipUrl }
// Sets donatedAt, coolingEndsAt, status=completed.
// Also updates Donor.lastDonationDate and clears hospitalBookingActive.
router.patch('/:id/complete', async (req, res) => {
  let storedImages = {};
  try {
    const { donationPhotoUrl, doctorSlipUrl } = req.body;
    if (typeof donationPhotoUrl !== 'string' || typeof doctorSlipUrl !== 'string' ||
        !donationPhotoUrl || !doctorSlipUrl) {
      return res.status(400).json({ error: 'both_proof_images_required' });
    }
    const preflight = await Booking.findById(req.params.id);
    if (!preflight) return res.status(404).json({ error: 'Booking not found' });
    if (preflight.donorUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    if (preflight.status === 'completed') return res.status(409).json({ error: 'Already completed' });
    if (preflight.status === 'cancelled') return res.status(409).json({ error: 'Booking was cancelled' });
    storedImages = await privateImageStore.storeSet({ donationPhotoUrl, doctorSlipUrl });
    const result = await runInTransaction(async (session) => {
      const booking = await Booking.findById(req.params.id).session(session);
      if (!booking) return { status: 404, body: { error: 'Booking not found' } };
      if (booking.donorUid !== req.uid) return { status: 403, body: { error: 'Forbidden' } };
      if (booking.status === 'completed') return { status: 409, body: { error: 'Already completed' } };
      if (booking.status === 'cancelled') return { status: 409, body: { error: 'Booking was cancelled' } };

      // Proof may be uploaded days after the appointment. Use the booked slot date.
      const donatedAt = new Date(booking.slotDate);
      if (Number.isNaN(donatedAt.getTime())) {
        return { status: 422, body: { error: 'Booking has an invalid slot date' } };
      }
      const coolingEndsAt = new Date(donatedAt);
      coolingEndsAt.setDate(coolingEndsAt.getDate() + (booking.coolingDays || 90));
      booking.status = 'completed';
      booking.donatedAt = donatedAt;
      booking.coolingEndsAt = coolingEndsAt;
      booking.donationPhoto = storedImages.donationPhotoUrl;
      booking.doctorSlip = storedImages.doctorSlipUrl;
      booking.donationPhotoUrl = '';
      booking.doctorSlipUrl = '';
      booking.proofStatus = 'pending';
      booking.verificationNote = '';
      booking.verifiedAt = null;
      booking.verifiedBy = '';
      booking.certificateNo = '';
      booking.certificateIssuedAt = null;
      await booking.save({ session });

      await Donor.findOneAndUpdate(
        { uid: req.uid },
        { $set: { hospitalBookingActive: false, bookingStatus: 'proof_pending' } },
        { upsert: true, session },
      );
      return { booking };
    });
    if (result.status) {
      await Promise.all(Object.values(storedImages).map((image) => privateImageStore.remove(image).catch(() => {})));
      return res.status(result.status).json(result.body);
    }
    return res.json(serializeBooking(result.booking));
  } catch (err) {
    await Promise.all(Object.values(storedImages).map((image) => privateImageStore.remove(image).catch(() => {})));
    if (sendTransactionUnavailable(err, res)) return;
    if (err instanceof PrivateImageError) return res.status(err.status).json({ error: err.code });
    console.error('[Booking PATCH /:id/complete]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/not-donated ─────────────────────────────────────────
router.patch('/:id/not-donated', async (req, res) => {
  try {
    const result = await runInTransaction(async (session) => {
      const booking = await Booking.findById(req.params.id).session(session);
      if (!booking) return { status: 404, body: { error: 'Booking not found' } };
      if (booking.donorUid !== req.uid) return { status: 403, body: { error: 'Forbidden' } };
      if (booking.status === 'completed') {
        return { status: 409, body: { error: 'Donation proof has already been submitted' } };
      }
      booking.status = 'cancelled';
      booking.notDonatedReason = String(req.body.reason || '').trim();
      await booking.save({ session });
      await Donor.findOneAndUpdate(
        { uid: req.uid },
        { $set: { hospitalBookingActive: false, bookingStatus: 'ready_to_donate' } },
        { session },
      );
      return { booking };
    });
    if (result.status) return res.status(result.status).json(result.body);
    return res.json(serializeBooking(result.booking));
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[Booking PATCH /:id/not-donated]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/cancel ───────────────────────────────────────────────
router.patch('/:id/cancel', async (req, res) => {
  try {
    const result = await runInTransaction(async (session) => {
      const booking = await Booking.findById(req.params.id).session(session);
      if (!booking) return { status: 404, body: { error: 'Booking not found' } };
      if (booking.donorUid !== req.uid) return { status: 403, body: { error: 'Forbidden' } };
      booking.status = 'cancelled';
      await booking.save({ session });
      await Donor.findOneAndUpdate(
        { uid: req.uid },
        { $set: { hospitalBookingActive: false, bookingStatus: 'ready_to_donate' } },
        { session },
      );
      return { booking };
    });
    if (result.status) return res.status(result.status).json(result.body);
    return res.json(serializeBooking(result.booking));
  } catch (err) {
    if (sendTransactionUnavailable(err, res)) return;
    console.error('[Booking PATCH /:id/cancel]', err);
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
