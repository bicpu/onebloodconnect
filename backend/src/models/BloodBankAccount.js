const mongoose = require('mongoose');

/**
 * BloodBankAccount — one document per registered blood bank.
 * The uid is the Firebase Auth UID created during self-registration.
 */
const bloodBankAccountSchema = new mongoose.Schema(
  {
    // Firebase UID — primary lookup key
    uid: { type: String, required: true, unique: true, index: true },

    // ── Identity ────────────────────────────────────────────────────────────
    name:          { type: String, required: true, trim: true },
    registrationNo:{ type: String, default: '' },   // hospital/bank reg number
    email:         { type: String, required: true, lowercase: true, trim: true },
    phone:         { type: String, default: '' },
    website:       { type: String, default: '' },

    // ── Location ────────────────────────────────────────────────────────────
    address:       { type: String, default: '' },
    city:          { type: String, default: '' },
    state:         { type: String, default: '' },
    pincode:       { type: String, default: '' },

    // ── Operating hours ─────────────────────────────────────────────────────
    hours:         { type: String, default: '8:00 AM – 6:00 PM' },

    // ── Blood stock — { 'O+': 12, 'A-': 5, ... } ───────────────────────────
    stock: { type: Map, of: Number, default: {} },

    // ── Donation slots — array of time strings, e.g. ['9:00 AM','11:00 AM'] ──
    slots: [{ type: String }],

    // ── Staff ───────────────────────────────────────────────────────────────
    doctors: [
      {
        name:        { type: String, default: '' },
        speciality:  { type: String, default: '' },
        phone:       { type: String, default: '' },
        available:   { type: String, default: '' }, // e.g. "Mon–Fri 9AM–5PM"
      },
    ],
    nurses: [
      {
        name:  { type: String, default: '' },
        phone: { type: String, default: '' },
        shift: { type: String, default: '' },
      },
    ],

    // ── Verification ────────────────────────────────────────────────────────
    isVerified:  { type: Boolean, default: false }, // set by super-admin
    isActive:    { type: Boolean, default: true  },
  },
  { timestamps: true }
);

module.exports = mongoose.model('BloodBankAccount', bloodBankAccountSchema);
