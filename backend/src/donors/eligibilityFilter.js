const {
  DONOR_BOOKING_STATUSES,
  ELIGIBLE_NON_COMPLETED_STATUSES,
} = require('./bookingStatuses');

/**
 * Shared booking-state constraints for donor search and donor-request targeting.
 * Completed donors need an actual BSON date outside the 90-day cooldown;
 * missing, null, and non-date values cannot satisfy that branch.
 */
function donorEligibilityFilter(ninetyDaysAgo) {
  return {
    bookingStatus: { $in: [...DONOR_BOOKING_STATUSES] },
    hospitalBookingActive: { $ne: true },
    $or: [
      { bookingStatus: { $in: [...ELIGIBLE_NON_COMPLETED_STATUSES] } },
      {
        bookingStatus: 'completed',
        lastDonationDate: { $type: 'date', $lte: ninetyDaysAgo },
      },
    ],
  };
}

module.exports = donorEligibilityFilter;
