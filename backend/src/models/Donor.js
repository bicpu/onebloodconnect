const mongoose = require('mongoose');

/**
 * Donor document — one per Firebase user UID.
 * Mirrors the Firestore `donors/{uid}` fields used across the Flutter app.
 */
const donorSchema = new mongoose.Schema(
  {
    // Firebase UID — used as the primary lookup key
    uid: { type: String, required: true, unique: true, index: true },

    fullName:  { type: String, default: '' },
    email:     { type: String, default: '' },
    profilePhotoUrl: { type: String, default: '' },
    bloodGroup: { type: String, default: '' },
    dateOfBirth: { type: Date, default: null },
    gender: { type: String, default: '' },
    state: { type: String, default: '' },
    pincode: { type: String, default: '' },
    lastDonationType: { type: String, default: '' },
    lastDonationHospital: { type: String, default: '' },
    coolingEndsAt: { type: Date, default: null },
    healthEligibility: { type: mongoose.Schema.Types.Mixed, default: {} },
    emergencyAvailable: { type: Boolean, default: false },
    consentAccepted: { type: Boolean, default: false },

    // Donation availability flags
    readyAnyTime:  { type: Boolean, default: false },
    showToOthers:  { type: Boolean, default: false },
    preferredVenue: { type: String, default: 'Not selected yet' },

    // Active commitment — the BloodRequest _id this donor has committed to respond to.
    // Cleared when they withdraw or after donation is marked complete.
    // Prevents a donor from committing to multiple requests simultaneously.
    activeCommitmentRequestId: { type: String, default: null },

    // Last donation details
    lastDonationDate:  { type: Date, default: null },
    lastDonationUnits: { type: Number, default: null },

    // Donor registration flag
    registered: { type: Boolean, default: false },

    // Hospital booking details
    hospitalBookingActive: { type: Boolean, default: false },
    bookingStatus: {
      type: String,
      enum: ['ready_to_donate', 'booked', 'confirmed', 'completed', 'cancelled'],
      default: 'ready_to_donate',
    },

    // Donation stream selected on registration
    donationStream: { type: String, default: 'Whole Blood' },

    // Contact & location (used for manual entries and search display)
    phone: { type: String, default: '' },
    city:  { type: String, default: '' },

    // Whether this donor was added manually by admin (no Firebase account)
    manualEntry: { type: Boolean, default: false },

    // Pre-screening answers stored as a plain object { "0": true, "1": false, ... }
    preScreeningAnswers: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true } // adds createdAt and updatedAt automatically
);

module.exports = mongoose.model('Donor', donorSchema);
