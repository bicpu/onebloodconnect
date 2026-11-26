const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const http = require('node:http');
const Module = require('node:module');
const path = require('node:path');
const { createRequireVerifiedBloodBank } = require('../src/middleware/requireVerifiedBloodBank');

const bankRoutesPath = require.resolve('../src/routes/bloodBankAccounts');
const bookingRoutesPath = require.resolve('../src/routes/bookings');
const bloodRequestRoutesPath = require.resolve('../src/routes/bloodRequests');
const previousCache = new Map([
  bankRoutesPath, bookingRoutesPath, bloodRequestRoutesPath,
].map((file) => [file, require.cache[file]]));
const previousLoad = Module._load;

const idA = '64b000000000000000000001';
const idB = '64b000000000000000000002';
const idUnmatched = '64b000000000000000000003';
const refA = 'a4f8e222-33c4-4c31-8f06-741883d2c921';
const refB = 'b4f8e222-33c4-4c31-8f06-741883d2c922';
const accounts = new Map();
const requests = new Map();
const bookings = new Map();
const capturedCreates = { bookings: [], requests: [] };

function query(value) {
  const resolve = () => typeof value === 'function' ? value() : value;
  const result = {
    limit() { return this; },
    select() { return this; },
    sort() { return this; },
    lean() { return Promise.resolve(resolve()); },
    session() { return Promise.resolve(resolve()); },
  };
  return result;
}

function matches(record, filter) {
  return Object.entries(filter).every(([key, expected]) => {
    if (key === '_id' || key === 'facilityAccountId' || key === 'targetFacilityAccountId' ||
        key === 'facilityDirectoryId' || key === 'targetFacilityDirectoryId' ||
        key === 'facilityRef' || key === 'isVerified' || key === 'isActive' ||
        key === 'status' || key === 'proofStatus') {
      if (expected && typeof expected === 'object' && '$nin' in expected) {
        return !expected.$nin.includes(record[key]);
      }
      return record[key] === expected;
    }
    return true;
  });
}

const BloodBankAccount = {
  findOne(filter) { return query(accounts.get(filter.uid) || null); },
  find(filter) {
    return query(() => [...accounts.values()].filter((account) => matches(account, filter)));
  },
};

function attachSave(record, collection) {
  record.saveCount = record.saveCount || 0;
  record.save = async function save() {
    this.saveCount += 1;
    collection.set(String(this._id), this);
    return this;
  };
  return record;
}

const BloodRequest = {
  find(filter) {
    return query(() => [...requests.values()].filter((record) => matches(record, filter)));
  },
  findOne(filter) {
    const record = [...requests.values()].find((item) => matches(item, filter)) || null;
    return Promise.resolve(record);
  },
  async updateMany() {},
  async create(values) {
    const record = attachSave({ _id: `created-request-${capturedCreates.requests.length + 1}`, ...values, timeline: values.timeline || [] }, requests);
    capturedCreates.requests.push(record);
    requests.set(String(record._id), record);
    return record;
  },
};

class Booking {
  constructor(values) {
    Object.assign(this, values);
    this._id = `created-booking-${capturedCreates.bookings.length + 1}`;
    this.saveCount = 0;
    capturedCreates.bookings.push(this);
  }
  async save() {
    this.saveCount += 1;
    bookings.set(String(this._id), this);
    return this;
  }
  static find(filter) {
    return query(() => [...bookings.values()].filter((record) => matches(record, filter)));
  }
  static findOne(filter) {
    const record = [...bookings.values()].find((item) => matches(item, filter)) || null;
    const result = Promise.resolve(record);
    result.session = () => result;
    return result;
  }
}

const Donor = {
  async findOneAndUpdate() { return null; },
  findOne() { return query(null); },
};
const BloodBank = { findOne() { return query(null); } };
const authenticate = (req, _res, next) => {
  req.uid = req.headers['x-test-uid'];
  req.firebaseUser = { uid: req.uid };
  next();
};
const requireBank = createRequireVerifiedBloodBank(async (uid) => accounts.get(uid) || null);
const transactionStubs = {
  createTransactionRunner: () => async (work) => work({ testSession: true }),
  sendTransactionUnavailable: () => false,
};
const privacyStubs = {
  serializeFacilityBloodRequest: (value) => value,
  serializeFacilityDonation: (value) => value,
  serializeRequesterBloodRequest: (value) => value,
  serializeBloodRequest: (value) => value,
};

const routeStubs = new Map([
  [bankRoutesPath, new Map([
    ['../middleware/auth', authenticate],
    ['../middleware/requireVerifiedBloodBank', requireBank],
    ['../models/BloodBankAccount', BloodBankAccount],
    ['../models/BloodRequest', BloodRequest],
    ['../models/Donor', Donor],
    ['../models/Booking', Booking],
    ['../privacy/donorResponses', privacyStubs],
    ['../db/transactions', transactionStubs],
  ])],
  [bookingRoutesPath, new Map([
    ['../middleware/auth', authenticate],
    ['../models/Booking', Booking],
    ['../models/Donor', Donor],
    ['../models/BloodBankAccount', BloodBankAccount],
    ['../models/BloodBank', BloodBank],
    ['../db/transactions', transactionStubs],
  ])],
  [bloodRequestRoutesPath, new Map([
    ['../middleware/auth', authenticate],
    ['../models/BloodRequest', BloodRequest],
    ['../models/Donor', Donor],
    ['../models/BloodBankAccount', BloodBankAccount],
    ['../models/BloodBank', BloodBank],
    ['../privacy/donorResponses', privacyStubs],
    ['../db/transactions', transactionStubs],
  ])],
]);

Module._load = function (request, parent, isMain) {
  const stubs = parent?.filename && routeStubs.get(path.resolve(parent.filename));
  if (stubs?.has(request)) return stubs.get(request);
  return previousLoad.call(this, request, parent, isMain);
};

delete require.cache[bankRoutesPath];
delete require.cache[bookingRoutesPath];
delete require.cache[bloodRequestRoutesPath];
const bankRouter = require(bankRoutesPath);
const bookingRouter = require(bookingRoutesPath);
const bloodRequestRouter = require(bloodRequestRoutesPath);
Module._load = previousLoad;

function resetFixtures() {
  accounts.clear();
  requests.clear();
  bookings.clear();
  capturedCreates.bookings.length = 0;
  capturedCreates.requests.length = 0;
  accounts.set('bank-a-uid', {
    _id: idA, uid: 'bank-a-uid', facilityRef: refA,
    name: 'Shared Facility', isVerified: true, isActive: true,
  });
  accounts.set('bank-b-uid', {
    _id: idB, uid: 'bank-b-uid', facilityRef: refB,
    name: 'Shared Facility', isVerified: true, isActive: true,
  });
}

function appServer() {
  const app = express();
  app.use(express.json());
  app.use('/bank', bankRouter);
  app.use('/bookings', bookingRouter);
  app.use('/blood-requests', bloodRequestRouter);
  const server = http.createServer(app);
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function request(base, method, route, uid, body) {
  return fetch(`${base}${route}`, {
    method,
    headers: {
      'x-test-uid': uid,
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function withServer(run) {
  const server = await appServer();
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('facility-owned request and donation routes enforce account ObjectId ownership over HTTP', async () => {
  resetFixtures();
  const ownRequest = attachSave({
    _id: 'request-a', targetFacilityAccountId: idA, facilityName: 'Old Facility Name',
    status: 'pending', facilityReviewStatus: 'pending', timeline: [],
  }, requests);
  const otherRequest = attachSave({
    _id: 'request-b', targetFacilityAccountId: idB, facilityName: 'Shared Facility',
    status: 'pending', facilityReviewStatus: 'pending', timeline: [],
  }, requests);
  requests.set(ownRequest._id, ownRequest);
  requests.set(otherRequest._id, otherRequest);

  const donationCases = [
    { id: 'donation-a', facilityAccountId: idA, facilityName: 'Old Facility Name' },
    { id: 'donation-b', facilityAccountId: idB, facilityName: 'Shared Facility' },
    { id: 'donation-missing', facilityName: 'Shared Facility' },
    { id: 'donation-null', facilityAccountId: null, facilityName: 'Shared Facility' },
    { id: 'donation-malformed', facilityAccountId: 'not-an-object-id', facilityName: 'Shared Facility' },
    { id: 'donation-unmatched', facilityAccountId: idUnmatched, facilityName: 'Shared Facility' },
    { id: 'donation-legacy-name-only', facilityName: 'Shared Facility' },
  ];
  const donationRecords = new Map();
  for (const item of donationCases) {
    const record = attachSave({
      _id: item.id,
      ...(Object.hasOwn(item, 'facilityAccountId') ? { facilityAccountId: item.facilityAccountId } : {}),
      facilityName: item.facilityName,
      status: 'completed', proofStatus: 'pending', donorUid: `donor-${item.id}`,
      donatedAt: new Date('2026-01-01T00:00:00Z'),
    }, bookings);
    bookings.set(record._id, record);
    donationRecords.set(record._id, record);
  }

  await withServer(async (base) => {
    let response = await request(base, 'GET', '/bank/active-requests', 'bank-a-uid');
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map((record) => record._id), ['request-a']);

    response = await request(base, 'PATCH', '/bank/requests/request-a/review', 'bank-a-uid', {
      accepted: true, comment: 'Reviewed by owner',
    });
    assert.equal(response.status, 200);
    assert.equal(ownRequest.facilityReviewStatus, 'accepted');
    assert.equal(ownRequest.saveCount, 1);

    // Bank B deliberately has the same mutable display name as Bank A.
    response = await request(base, 'PATCH', '/bank/requests/request-a/review', 'bank-b-uid', {
      accepted: false, comment: 'Attempted by other bank',
    });
    assert.equal(response.status, 404);
    assert.equal(ownRequest.facilityReviewStatus, 'accepted');
    assert.equal(ownRequest.saveCount, 1);

    accounts.get('bank-a-uid').name = 'Renamed Facility';
    accounts.get('bank-b-uid').name = 'Renamed Facility';
    response = await request(base, 'GET', '/bank/active-requests', 'bank-a-uid');
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map((record) => record._id), ['request-a']);
    response = await request(base, 'PATCH', '/bank/requests/request-a/review', 'bank-b-uid', {
      accepted: true, comment: 'Name collision after rename',
    });
    assert.equal(response.status, 404);

    response = await request(base, 'GET', '/bank/donations/pending', 'bank-a-uid');
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map((record) => record._id), ['donation-a']);

    response = await request(base, 'PATCH', '/bank/donations/donation-a/verify', 'bank-a-uid', {
      approved: false, note: 'Owner reviewed',
    });
    assert.equal(response.status, 200);
    assert.equal(donationRecords.get('donation-a').proofStatus, 'rejected');
    assert.equal(donationRecords.get('donation-a').saveCount, 1);

    for (const id of ['donation-b', 'donation-missing', 'donation-null', 'donation-malformed', 'donation-unmatched', 'donation-legacy-name-only']) {
      const record = donationRecords.get(id);
      const proofStatusBefore = record.proofStatus;
      const saveCountBefore = record.saveCount;
      response = await request(base, 'PATCH', `/bank/donations/${id}/verify`, 'bank-a-uid', {
        approved: false, note: 'Must not be applied',
      });
      assert.equal(response.status, 404, `${id} must not be discoverable through Bank A's account`);
      assert.equal(record.proofStatus, proofStatusBefore, `${id} state must remain unchanged`);
      assert.equal(record.saveCount, saveCountBefore, `${id} must not be saved`);
    }

    const malformedOwnershipRequests = [
      { id: 'request-missing', name: 'Shared Facility' },
      { id: 'request-null', targetFacilityAccountId: null, name: 'Shared Facility' },
      { id: 'request-malformed', targetFacilityAccountId: 'bad-id', name: 'Shared Facility' },
      { id: 'request-unmatched', targetFacilityAccountId: idUnmatched, name: 'Shared Facility' },
      { id: 'request-legacy-name-only', name: 'Shared Facility' },
    ];
    const requestRecords = new Map();
    for (const item of malformedOwnershipRequests) {
      const record = attachSave({
        _id: item.id,
        ...(Object.hasOwn(item, 'targetFacilityAccountId') ? { targetFacilityAccountId: item.targetFacilityAccountId } : {}),
        facilityName: item.name, status: 'pending', facilityReviewStatus: 'pending', timeline: [],
      }, requests);
      requests.set(record._id, record);
      requestRecords.set(record._id, record);
    }
    response = await request(base, 'GET', '/bank/active-requests', 'bank-a-uid');
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).map((record) => record._id), ['request-a']);
    for (const id of requestRecords.keys()) {
      const record = requestRecords.get(id);
      response = await request(base, 'PATCH', `/bank/requests/${id}/review`, 'bank-a-uid', {
        accepted: true, comment: 'Must not be applied',
      });
      assert.equal(response.status, 404, `${id} must fail closed`);
      assert.equal(record.facilityReviewStatus, 'pending');
      assert.equal(record.saveCount, 0);
    }

    // Bank B cannot verify Bank A's donation even though the display names match.
    const bankBMutationCount = ownRequest.saveCount;
    response = await request(base, 'PATCH', '/bank/donations/donation-a/verify', 'bank-b-uid', {
      approved: true,
    });
    assert.equal(response.status, 404);
    assert.equal(donationRecords.get('donation-a').proofStatus, 'rejected');
    assert.equal(ownRequest.saveCount, bankBMutationCount);
  });
});

test('booking and blood-request creation ignore client-supplied ownership and display snapshots', async () => {
  resetFixtures();
  await withServer(async (base) => {
    let response = await request(base, 'POST', '/bookings', 'donor-authenticated', {
      facilityRef: refA,
      facilityAccountId: idB,
      facilityName: 'Forged Bank B Name',
      facilityUid: 'bank-b-uid',
      donorUid: 'victim-donor-uid',
      slotDate: '2027-01-01T10:00:00.000Z',
    });
    assert.equal(response.status, 201);
    const booking = capturedCreates.bookings[0];
    assert.equal(booking.donorUid, 'donor-authenticated');
    assert.equal(String(booking.facilityAccountId), idA);
    assert.equal(booking.facilityName, 'Shared Facility');
    assert.notEqual(String(booking.facilityAccountId), idB);

    response = await request(base, 'POST', '/blood-requests', 'requester-authenticated', {
      patientName: 'Test Patient', bloodGroup: 'O+', units: 1,
      targetFacilityRef: refA,
      targetFacilityAccountId: idB,
      targetFacilityUid: 'bank-b-uid',
      targetFacilityName: 'Forged Bank B Name',
      targetFacilityAddress: 'Forged address',
    });
    assert.equal(response.status, 201);
    const bloodRequest = capturedCreates.requests[0];
    assert.equal(bloodRequest.requesterUid, 'requester-authenticated');
    assert.equal(String(bloodRequest.targetFacilityAccountId), idA);
    assert.equal(bloodRequest.targetFacilityName, 'Shared Facility');
    assert.notEqual(String(bloodRequest.targetFacilityAccountId), idB);

    const bookingCount = capturedCreates.bookings.length;
    response = await request(base, 'POST', '/bookings', 'donor-authenticated', {
      facilityAccountId: idB,
      facilityName: 'Shared Facility',
      facilityUid: 'bank-b-uid',
      slotDate: '2027-01-01T10:00:00.000Z',
    });
    assert.equal(response.status, 400);
    assert.equal(capturedCreates.bookings.length, bookingCount);

    const requestCount = capturedCreates.requests.length;
    response = await request(base, 'POST', '/blood-requests', 'requester-authenticated', {
      patientName: 'Test Patient', bloodGroup: 'O+', units: 1,
      targetFacilityUid: 'bank-b-uid',
      targetFacilityName: 'Shared Facility',
    });
    assert.equal(response.status, 400);
    assert.equal(capturedCreates.requests.length, requestCount);
  });
});

test.after(() => {
  Module._load = previousLoad;
  for (const [file, cachedModule] of previousCache) {
    delete require.cache[file];
    if (cachedModule) require.cache[file] = cachedModule;
  }
});
