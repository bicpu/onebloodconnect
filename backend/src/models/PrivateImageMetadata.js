const mongoose = require('mongoose');

module.exports = new mongoose.Schema({
  key: { type: String, required: true },
  mimeType: { type: String, enum: ['image/jpeg', 'image/png'], required: true },
  size: { type: Number, required: true, min: 1 },
  checksum: { type: String, required: true },
  uploadedAt: { type: Date, required: true },
}, { _id: false });
