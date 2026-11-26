const mongoose = require('mongoose');
const PrivateImageMetadata = require('./PrivateImageMetadata');

/**
 * DonorRequest — created when a user contacts a specific registered donor
 * from the Search page. The donor can accept or decline.
 */
const donorRequestSchema = new mongoose.Schema(
  {
    // ── Parties ──────────────────────────────────────────────────────────────
    // Firebase UID of the person who sent the request
    requesterUid:  { type: String, required: true, index: true },
    requesterName: { type: String, default: '' },
    requesterPhone:{ type: String, default: '' },

    // MongoDB _id of the Donor document being contacted
    donorId:       { type: mongoose.Schema.Types.ObjectId, ref: 'Donor', required: false, index: true },
    // Firebase UID of the donor — used for inbox lookup (avoids ObjectId serialisation issues)
    donorUid:      { type: String, default: '', index: true },
    donorName:     { type: String, default: '' },   // denormalised for display
    donorBloodGroup: { type: String, default: '' },

    // ── Patient details ───────────────────────────────────────────────────────
    patientName:   { type: String, required: true },
    patientAge:    { type: Number, default: null },
    patientGender: { type: String, enum: ['Male', 'Female', 'Other'], default: 'Male' },
    bloodGroup:    { type: String, required: true },
    units:         { type: Number, required: true, min: 1 },
    component:     { type: String, default: 'Whole Blood' },
    urgency:       { type: String, enum: ['Critical Red', 'Urgent', 'Standard'], default: 'Urgent' },

    // ── Hospital details ──────────────────────────────────────────────────────
    hospital:      { type: String, default: '' },
    ward:          { type: String, default: '' },
    bedNumber:     { type: String, default: '' },
    attender:      { type: String, default: '' },
    contactPhone:  { type: String, default: '' },

    // ── Request lifecycle ─────────────────────────────────────────────────────
    // pending → accepted → donated → completed | declined | cancelled
    status: {
      type: String,
      enum: ['pending', 'accepted', 'donated', 'completed', 'declined', 'cancelled'],
      default: 'pending',
    },

    // Set when donor accepts — confirmation details shown to requester
    confirmedAt:     { type: Date, default: null },
    donorNote:       { type: String, default: '' },   // message from donor on accept

    // Set when donor marks donation done
    donatedAt:        { type: Date,   default: null },
    donationPhotoUrl: { type: String, default: '' },
    doctorSlipUrl:    { type: String, default: '' },
    donationPhoto:    { type: PrivateImageMetadata, default: null },
    doctorSlip:       { type: PrivateImageMetadata, default: null },

    // Cancellation metadata
    cancelledBy:   { type: String, enum: ['requester', 'donor', ''], default: '' },
    cancelReason:  { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('DonorRequest', donorRequestSchema);
