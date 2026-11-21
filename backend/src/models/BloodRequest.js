const mongoose = require('mongoose');

/**
 * BloodRequest — created when a user broadcasts an emergency blood request
 * from RequestBloodPage.
 */
const bloodRequestSchema = new mongoose.Schema(
  {
    // Firebase UID of the user who created this request
    requesterUid: { type: String, required: true, index: true },

    // Patient info
    patientName:   { type: String, required: true },
    patientAge:    { type: Number },
    patientGender: { type: String, enum: ['Male', 'Female', 'Other'], default: 'Male' },

    // Blood requirements
    bloodGroup:  { type: String, required: true },
    units:       { type: Number, required: true, min: 1 },
    component:   { type: String, default: 'Whole Blood' },

    // Urgency: Critical Red | Urgent | Standard
    urgency: {
      type: String,
      enum: ['Critical Red', 'Urgent', 'Standard'],
      default: 'Urgent',
    },

    // Hospital destination
    hospital:  { type: String, default: '' },
    ward:      { type: String, default: '' },
    bedNumber: { type: String, default: '' },
    hubZone:   { type: String, default: '' },

    // Attender / contact
    attender:      { type: String, default: '' },
    contactPhone:  { type: String, default: '' },

    // Dispatch settings
    emergencyPushEnabled: { type: Boolean, default: true },
    notifyNss:            { type: Boolean, default: true },

    // Attached document (file name only; actual upload is out-of-scope for this backend)
    attachmentFileName: { type: String, default: null },

    // Request lifecycle status
    status: {
      type: String,
      enum: [
        'pending',        // just submitted
        'received',       // confirmed by facility
        'verifying',      // checking donor eligibility / stock
        'preparing',      // preparing for pickup
        'ready',          // ready for collection
        'fulfilled',      // blood has been collected
        'cancelled',      // cancelled by requester or admin
      ],
      default: 'pending',
    },

    // Target facility details (set by admin / matching engine)
    targetFacilityAccountId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BloodBankAccount',
      default: null,
      select: false,
    },
    targetFacilityDirectoryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BloodBank',
      default: null,
      select: false,
    },
    targetFacilityName:    { type: String, default: '' },
    targetFacilityUid:     { type: String, default: '' },
    targetFacilityAddress: { type: String, default: '' },
    targetFacilityPhone:   { type: String, default: '' },
    facilityReviewStatus:  {
      type: String,
      enum: ['pending', 'accepted', 'rejected'],
      default: 'pending',
    },
    facilityReviewComment: { type: String, default: '' },
    facilityReviewedAt:    { type: Date, default: null },
    facilityReviewedBy:    { type: String, default: '' },

    // Timeline events — array of { step, time, note }
    timeline: [
      {
        step:  { type: String },
        time:  { type: Date, default: Date.now },
        note:  { type: String, default: '' },
      },
    ],

    // ── Crowd-sourced response tracking ──────────────────────────────────────
    // How many units are still needed (starts equal to `units`, decrements per response)
    unitsRemaining: { type: Number, default: null },   // null = not yet initialised (legacy)

    // Each donor who commits units adds an entry here
    responses: [
      {
        responderUid:  { type: String, required: true },
        responderName: { type: String, default: '' },
        unitsCommitted:{ type: Number, required: true, min: 1 },
        respondedAt:   { type: Date,   default: Date.now },
      },
    ],

    // Auto-expiry — set on creation. Request auto-closes if not fulfilled before this.
    // Critical Red: 12h · Urgent: 24h · Standard: 48h
    expiresAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('BloodRequest', bloodRequestSchema);
