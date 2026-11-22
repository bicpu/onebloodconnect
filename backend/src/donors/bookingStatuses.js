// Canonical values stored on Donor.bookingStatus. `proof_pending` is written by
// the booking workflow but intentionally excluded from donor eligibility until
// the reported donation has been verified and the status becomes `completed`.
const DONOR_BOOKING_STATUSES = Object.freeze([
  'ready_to_donate',
  'booked',
  'confirmed',
  'completed',
  'cancelled',
]);

const ELIGIBLE_NON_COMPLETED_STATUSES = Object.freeze([
  'ready_to_donate',
  'cancelled',
]);

module.exports = { DONOR_BOOKING_STATUSES, ELIGIBLE_NON_COMPLETED_STATUSES };
