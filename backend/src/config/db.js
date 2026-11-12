const mongoose = require('mongoose');

/**
 * Connects to MongoDB using the MONGODB_URI environment variable.
 * Exits the process on connection failure so misconfiguration is
 * immediately visible in server logs.
 */
async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log(`[MongoDB] Connected to ${mongoose.connection.name}`);
  } catch (err) {
    console.error('[MongoDB] Connection failed:', err.message);
    process.exit(1);
  }
}

module.exports = connectDB;
