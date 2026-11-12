const mongoose = require('mongoose');

/**
 * BloodBank — created by admin to appear in the Search page.
 */
const bloodBankSchema = new mongoose.Schema(
  {
    name:       { type: String, required: true, trim: true },
    address:    { type: String, default: '' },
    city:       { type: String, default: '' },
    phone:      { type: String, default: '' },
    hours:      { type: String, default: '8:00 AM – 6:00 PM' },
    isVerified: { type: Boolean, default: true },

    // Blood group stock — { 'O+': 12, 'A-': 5, ... }
    stock: {
      type: Map,
      of: Number,
      default: {},
    },

    // Admin flag — manually entered vs auto-synced
    manualEntry: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('BloodBank', bloodBankSchema);
