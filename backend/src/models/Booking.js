const mongoose = require('mongoose');
const PrivateImageMetadata = require('./PrivateImageMetadata');

/**
 * Booking — represents a hospital slot booked by a donor.
 */
const bookingSchema = new mongoose.Schema(
  {
    // Firebase UID of the donor
    donorUid: { type: String, required: true, index: true },

    // Facility details
    facilityAccountId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BloodBankAccount',
      default: null,
      select: false,
    },
    facilityDirectoryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BloodBank',
      default: null,
      select: false,
    },
    facilityName:    { type: String, required: true },
    facilityAddress: { type: String, default: '' },
    facilityPhone:   { type: String, default: '' },

    // Slot details
    slotDate: { type: Date, required: true },
    slotTime: { type: String, default: '' },

    // Booking reference displayed to user
    bookingRef: { type: String, required: true, unique: true },

    // Status lifecycle: booked → confirmed → completed | cancelled
    status: {
      type: String,
      enum: ['booked', 'confirmed', 'completed', 'cancelled'],
      default: 'booked',
    },

    // Donor meta at time of booking (denormalised for display)
    donorName:  { type: String, default: '' },
    bloodGroup: { type: String, default: '' },

    // ── Donation completion fields (set when donor marks donation done) ──────
    donatedAt:       { type: Date,   default: null },   // actual donation timestamp
    donationPhotoUrl:{ type: String, default: '' },     // selfie / photo proof
    doctorSlipUrl:   { type: String, default: '' },     // doctor slip / receipt
    donationPhoto:   { type: PrivateImageMetadata, default: null },
    doctorSlip:      { type: PrivateImageMetadata, default: null },
    proofStatus: {
      type: String,
      enum: ['not_submitted', 'pending', 'approved', 'rejected', 'appealed'],
      default: 'not_submitted',
    },
    verificationNote: { type: String, default: '' },
    verifiedAt:       { type: Date, default: null },
    verifiedBy:       { type: String, default: '' },
    certificateNo:    { type: String, default: '' },
    certificateIssuedAt: { type: Date, default: null },
    notDonatedReason: { type: String, default: '' },
    appealReason:     { type: String, default: '' },
    appealedAt:       { type: Date, default: null },

    // Cooling period end date — computed from donatedAt + component cooling days
    coolingEndsAt:   { type: Date,   default: null },
    coolingDays:     { type: Number, default: 90 },     // 90 | 7 | 28
    component:       { type: String, default: 'Whole Blood' },
    units:           { type: Number, default: 1, min: 1 },
  },
  { timestamps: true }
);

// Enforce the existing one-active-booking-per-donor rule atomically in MongoDB.
// Cancelled and completed bookings are excluded, so donors may book again.
bookingSchema.index(
  { donorUid: 1 },
  {
    unique: true,
    name: 'uniq_active_booking_per_donor',
    partialFilterExpression: {
      status: { $in: ['booked', 'confirmed'] },
    },
  },
);

module.exports = mongoose.model('Booking', bookingSchema);
