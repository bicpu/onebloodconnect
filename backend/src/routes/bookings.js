const express      = require('express');
const router       = express.Router();
const authenticate = require('../middleware/auth');
const Booking      = require('../models/Booking');
const Donor        = require('../models/Donor');

router.use(authenticate);

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
      facilityName, facilityAddress, facilityPhone,
      slotDate, slotTime,
      donorName, bloodGroup, component, coolingDays,
      units,
    } = req.body;

    if (!facilityName || !slotDate) {
      return res.status(400).json({ error: 'facilityName and slotDate are required' });
    }

    // Prevent duplicate active bookings — only one at a time
    const existing = await Booking.findOne({
      donorUid: req.uid,
      status:   { $in: ['booked', 'confirmed'] },
    });
    if (existing) {
      return res.status(409).json({
        error:   'active_booking_exists',
        booking: existing,
        message: 'You already have an active booking. Complete or cancel it before booking again.',
      });
    }

    const year       = new Date().getFullYear();
    const rand       = Math.floor(1000 + Math.random() * 9000);
    const bookingRef = `OBC-APP-${year}-${rand}`;

    const booking = await Booking.create({
      donorUid:        req.uid,
      facilityName,
      facilityAddress: facilityAddress || '',
      facilityPhone:   facilityPhone   || '',
      slotDate:        new Date(slotDate),
      slotTime:        slotTime    || '',
      bookingRef,
      status:          'confirmed',
      donorName:       donorName   || '',
      bloodGroup:      bloodGroup  || '',
      component:       component   || 'Whole Blood',
      coolingDays:     coolingDays || 90,
      units:           units || 1,
    });

    await Donor.findOneAndUpdate(
      { uid: req.uid },
      {
        $set: {
          hospitalBookingActive: true,
          bookingStatus:         'confirmed',
        },
      },
      { upsert: true }
    );

    res.status(201).json(booking);
  } catch (err) {
    console.error('[Booking POST /]', err);
    res.status(500).json({ error: 'Server error' });
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
      return res.json({ active: true, booking: active });
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
        booking: pending,
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
          ...cooling,
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
    res.json(booking);
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
    res.json(bookings);
  } catch (err) {
    console.error('[Booking GET /history]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/:id ────────────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const bookingDoc = await Booking.findById(req.params.id);
    const booking = bookingDoc ? await normalizePendingDonationDate(bookingDoc) : null;
    if (!booking)                        return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid)    return res.status(403).json({ error: 'Forbidden' });
    res.json(booking.toObject());
  } catch (err) {
    console.error('[Booking GET /:id]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── GET /bookings/:id/certificate ──────────────────────────────────────────
router.get('/:id/certificate', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id).lean();
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

// ─── PATCH /bookings/:id/complete ─────────────────────────────────────────────
// Donor marks their donation as done.
// Body: { donationPhotoUrl, doctorSlipUrl }
// Sets donatedAt, coolingEndsAt, status=completed.
// Also updates Donor.lastDonationDate and clears hospitalBookingActive.
router.patch('/:id/complete', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking)                        return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid)    return res.status(403).json({ error: 'Forbidden' });
    if (booking.status === 'completed')  return res.status(409).json({ error: 'Already completed' });
    if (booking.status === 'cancelled')  return res.status(409).json({ error: 'Booking was cancelled' });

    const { donationPhotoUrl, doctorSlipUrl } = req.body;

    // Proof may be uploaded days after the appointment. The donation date is
    // the completed hospital slot date, not the proof submission timestamp.
    const donatedAt     = new Date(booking.slotDate);
    if (Number.isNaN(donatedAt.getTime())) {
      return res.status(422).json({ error: 'Booking has an invalid slot date' });
    }
    const coolingEndsAt = new Date(donatedAt);
    coolingEndsAt.setDate(coolingEndsAt.getDate() + (booking.coolingDays || 90));

    booking.status           = 'completed';
    booking.donatedAt        = donatedAt;
    booking.coolingEndsAt    = coolingEndsAt;
    booking.donationPhotoUrl = donationPhotoUrl || '';
    booking.doctorSlipUrl    = doctorSlipUrl    || '';
    booking.proofStatus      = 'pending';
    booking.verificationNote = '';
    booking.verifiedAt       = null;
    booking.verifiedBy       = '';
    booking.certificateNo    = '';
    booking.certificateIssuedAt = null;
    await booking.save();

    // Keep the donation pending until a blood bank/admin verifies the proof.
    await Donor.findOneAndUpdate(
      { uid: req.uid },
      {
        $set: {
          hospitalBookingActive: false,
          bookingStatus:         'proof_pending',
        },
      },
      { upsert: true }
    );

    res.json(booking);
  } catch (err) {
    console.error('[Booking PATCH /:id/complete]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/not-donated ─────────────────────────────────────────
router.patch('/:id/not-donated', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid) return res.status(403).json({ error: 'Forbidden' });
    if (booking.status === 'completed') {
      return res.status(409).json({ error: 'Donation proof has already been submitted' });
    }
    booking.status = 'cancelled';
    booking.notDonatedReason = String(req.body.reason || '').trim();
    await booking.save();
    await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: { hospitalBookingActive: false, bookingStatus: 'ready_to_donate' } },
    );
    res.json(booking);
  } catch (err) {
    console.error('[Booking PATCH /:id/not-donated]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ─── PATCH /bookings/:id/cancel ───────────────────────────────────────────────
router.patch('/:id/cancel', async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking)                      return res.status(404).json({ error: 'Booking not found' });
    if (booking.donorUid !== req.uid)  return res.status(403).json({ error: 'Forbidden' });

    booking.status = 'cancelled';
    await booking.save();

    await Donor.findOneAndUpdate(
      { uid: req.uid },
      { $set: { hospitalBookingActive: false, bookingStatus: 'ready_to_donate' } }
    );

    res.json(booking);
  } catch (err) {
    console.error('[Booking PATCH /:id/cancel]', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
