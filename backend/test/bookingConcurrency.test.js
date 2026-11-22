const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
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

test('booking detail ID lookup is owner-scoped before its normalizer can save', async () => {
  const routePath = path.join(backendRoot, 'src/routes/bookings.js');
  const previousModule = require.cache[routePath];
  const previousLoad = Module._load;
  const registrations = [];
  const router = { use(...args) { registrations.push({ type: 'use', args }); return this; } };
  for (const method of ['get', 'post', 'patch', 'put', 'delete']) {
    router[method] = (pathName, ...handlers) => {
      registrations.push({ type: method, path: pathName, handler: handlers.at(-1) });
      return router;
    };
  }

  const record = {
    _id: 'booking-1',
    donorUid: 'owner-uid',
    status: 'completed',
    proofStatus: 'pending',
    slotDate: new Date('2026-01-01T00:00:00.000Z'),
    donatedAt: new Date('2025-12-31T00:00:00.000Z'),
    coolingDays: 90,
    saveCount: 0,
    async save() { this.saveCount += 1; },
    toObject() { return { _id: this._id, donorUid: this.donorUid, donatedAt: this.donatedAt }; },
  };
  const lookupFilters = [];
  const Booking = {
    findOne(filter) {
      lookupFilters.push(filter);
      return Promise.resolve(
        filter._id === record._id && filter.donorUid === record.donorUid ? record : null,
      );
    },
  };
  const stubs = new Map([
    ['express', { Router: () => router }],
    ['../middleware/auth', (_req, _res, next) => next()],
    ['../models/Booking', Booking],
    ['../models/Donor', {}],
    ['../models/BloodBankAccount', {}],
    ['../models/BloodBank', {}],
    ['../bookings/bookingErrors', { isActiveBookingDuplicateError: () => false }],
    ['../db/transactions', {
      createTransactionRunner: () => async () => {},
      sendTransactionUnavailable: () => false,
    }],
    ['../facilities/facilitySelection', {
      createFacilityResolver: () => async () => ({}),
      FacilitySelectionError: class FacilitySelectionError extends Error {},
    }],
  ]);

  delete require.cache[routePath];
  Module._load = function (request, parent, isMain) {
    if (parent?.filename === routePath && stubs.has(request)) return stubs.get(request);
    return previousLoad.call(this, request, parent, isMain);
  };

  try {
    require(routePath);
    const detailRoute = registrations.find((entry) => entry.type === 'get' && entry.path === '/:id');
    assert.ok(detailRoute, 'booking detail route is registered');
    assert.ok(registrations.findIndex((entry) => entry.type === 'use') < registrations.indexOf(detailRoute),
      'authentication middleware is registered before the detail route');

    const invoke = async (uid) => {
      const res = {
        statusCode: 200,
        body: null,
        status(code) { this.statusCode = code; return this; },
        json(body) { this.body = body; return this; },
      };
      await detailRoute.handler({ params: { id: record._id }, uid }, res);
      return res;
    };

    const substitutedIdResponse = await invoke('attacker-uid');
    assert.equal(substitutedIdResponse.statusCode, 404);
    assert.deepEqual(substitutedIdResponse.body, { error: 'Booking not found' });
    assert.deepEqual(lookupFilters[0], { _id: record._id, donorUid: 'attacker-uid' });
    assert.equal(record.saveCount, 0, 'unauthorized ID lookup must not invoke the date normalizer save');

    const ownerResponse = await invoke('owner-uid');
    assert.equal(ownerResponse.statusCode, 200);
    assert.equal(ownerResponse.body.donorUid, 'owner-uid');
    assert.deepEqual(lookupFilters[1], { _id: record._id, donorUid: 'owner-uid' });
    assert.equal(record.saveCount, 1, 'owner retains the legacy date normalization behavior');
  } finally {
    Module._load = previousLoad;
    delete require.cache[routePath];
    if (previousModule) require.cache[routePath] = previousModule;
  }
});
