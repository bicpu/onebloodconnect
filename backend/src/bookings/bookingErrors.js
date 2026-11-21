const ACTIVE_BOOKING_INDEX_NAME = 'uniq_active_booking_per_donor';

function isActiveBookingDuplicateError(error) {
  if (error?.code !== 11000) return false;

  if (error.keyPattern) {
    const keys = Object.keys(error.keyPattern);
    return keys.length === 1 && keys[0] === 'donorUid';
  }

  return String(error.message || '').includes(ACTIVE_BOOKING_INDEX_NAME);
}

module.exports = { isActiveBookingDuplicateError };
