const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { isActiveBookingDuplicateError } = require('../src/bookings/bookingErrors');

const backendRoot = path.resolve(__dirname, '..');
function source(file) {
  return fs.readFileSync(path.join(backendRoot, file), 'utf8');
}

test('unique partial index enforces one booked or confirmed booking per donor', () => {
  const model = source('src/models/Booking.js');
  assert.match(model, /bookingSchema\.index\(\s*\{ donorUid: 1 \},\s*\{\s*unique: true,\s*name: 'uniq_active_booking_per_donor',\s*partialFilterExpression: \{\s*status: \{ \$in: \['booked', 'confirmed'\] \}/);
  assert.doesNotMatch(model.match(/bookingSchema\.index\([\s\S]*?\);/)[0], /facilityAccountId|facilityDirectoryId|slotDate|slotTime/);
});

test('booking creation retains the donor-wide rule and resolves facility ownership server-side', () => {
  const routes = source('src/routes/bookings.js');
  const create = routes.slice(routes.indexOf("router.post('/',"), routes.indexOf("router.get('/active',"));
  assert.match(create, /const facility = await resolveFacilitySelection/);
  assert.match(create, /donorUid: req\.uid/);
  assert.match(create, /status:\s*\{ \$in: ACTIVE_BOOKING_STATUSES \}/);
  assert.doesNotMatch(create, /donorUid:\s*req\.body|facilityAccountId:\s*req\.body|facilityDirectoryId:\s*req\.body/);
  assert.match(create, /facilityAccountId:\s*facility\.facilityAccountId/);
  assert.match(create, /facilityDirectoryId:\s*facility\.facilityDirectoryId/);
});

test('cancelled and completed bookings are outside the active uniqueness rule', () => {
  const model = source('src/models/Booking.js');
  const routes = source('src/routes/bookings.js');
  assert.match(model, /status: \{ \$in: \['booked', 'confirmed'\] \}/);
  assert.match(routes, /router\.patch\('\/:id\/cancel'[\s\S]*?booking\.status = 'cancelled'[\s\S]*?await booking\.save\(\{ session \}\)/);
  assert.match(routes, /router\.patch\('\/:id\/complete'[\s\S]*?booking\.status\s*=\s*'completed'[\s\S]*?await booking\.save\(\{ session \}\)/);
});

test('active booking duplicate-key errors are distinguished from unrelated unique conflicts', () => {
  assert.equal(isActiveBookingDuplicateError({ code: 11000, keyPattern: { donorUid: 1 } }), true);
  assert.equal(isActiveBookingDuplicateError({
    code: 11000,
    message: 'E11000 duplicate key index: uniq_active_booking_per_donor',
  }), true);
  assert.equal(isActiveBookingDuplicateError({ code: 11000, keyPattern: { bookingRef: 1 } }), false);
  assert.equal(isActiveBookingDuplicateError({ code: 11000, keyPattern: { uid: 1 } }), false);
  assert.equal(isActiveBookingDuplicateError({ code: 121 }), false);

  const routes = source('src/routes/bookings.js');
  assert.match(routes, /if \(isActiveBookingDuplicateError\(err\)\)[\s\S]*?res\.status\(409\)\.json\([\s\S]*?active_booking_exists/);
});
