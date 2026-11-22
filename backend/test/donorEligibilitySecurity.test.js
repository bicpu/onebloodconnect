const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const http = require('node:http');
const Module = require('node:module');

const donorModelPath = require.resolve('../src/models/Donor');
const donorRequestModelPath = require.resolve('../src/models/DonorRequest');
const authPath = require.resolve('../src/middleware/auth');
const routesPath = require.resolve('../src/routes/donors');
const donorRequestRoutesPath = require.resolve('../src/routes/donorRequests');
const originalDonorModel = require.cache[donorModelPath];
const originalDonorRequestModel = require.cache[donorRequestModelPath];
const originalAuth = require.cache[authPath];
const originalDonorRoutes = require.cache[routesPath];
const originalDonorRequestRoutes = require.cache[donorRequestRoutesPath];
const records = new Map();

function matchesFilter(record, query) {
  if (query.bookingStatus?.$in && !query.bookingStatus.$in.includes(record.bookingStatus)) return false;
  if (query.hospitalBookingActive?.$ne === true && record.hospitalBookingActive === true) return false;
  if (query.showToOthers !== undefined && record.showToOthers !== query.showToOthers) return false;
  if (query.registered !== undefined && record.registered !== query.registered) return false;
  if (query.manualEntry?.$ne === true && record.manualEntry === true) return false;
  if (typeof query.publicRef === 'string' && record.publicRef !== query.publicRef) return false;
  if (query.publicRef && typeof query.publicRef === 'object' &&
      (typeof record.publicRef !== 'string' || record.publicRef === '')) return false;
  if (query.uid?.$ne && record.uid === query.uid.$ne) return false;
  if (query.bloodGroup !== undefined && record.bloodGroup !== query.bloodGroup) return false;
  if (query.$or) {
    const cutoff = query.$or[1].lastDonationDate.$lte;
    const completedDate = record.lastDonationDate;
    const completedIsEligible = completedDate instanceof Date &&
      !Number.isNaN(completedDate.getTime()) && completedDate <= cutoff;
    const stateIsEligible = query.$or[0].bookingStatus.$in.includes(record.bookingStatus) ||
      (record.bookingStatus === 'completed' && completedIsEligible);
    if (!stateIsEligible) return false;
  }
  return true;
}

function queryResult(value) {
  return {
    select() { return this; },
    sort() { return this; },
    async lean() { return value; },
  };
}

const donorModelMock = new Module(donorModelPath);
donorModelMock.filename = donorModelPath;
donorModelMock.loaded = true;
donorModelMock.exports = {
  async findOneAndUpdate(filter, update, options = {}) {
    let record = records.get(filter.uid);
    const inserted = !record;
    if (inserted) {
      if (!options.upsert) return null;
      record = {
        uid: filter.uid,
        registered: false,
        publicRef: null,
        lastDonationDate: null,
        lastDonationUnits: null,
        coolingEndsAt: null,
        selfReportedLastDonationDate: null,
        selfReportedLastDonationUnits: null,
        hospitalBookingActive: false,
        bookingStatus: 'ready_to_donate',
      };
    }
    Object.assign(record, update.$set || {});
    if (inserted) Object.assign(record, update.$setOnInsert || {});
    records.set(filter.uid, record);
    return { ...record };
  },
  find(query) {
    const matches = [...records.values()]
      .filter((record) => matchesFilter(record, query))
      .map((record) => ({ ...record }));
    return queryResult(matches);
  },
  findOne(query) {
    const match = [...records.values()].find((record) => matchesFilter(record, query));
    return queryResult(match ? { ...match } : null);
  },
};

const donorRequestModelMock = new Module(donorRequestModelPath);
donorRequestModelMock.filename = donorRequestModelPath;
donorRequestModelMock.loaded = true;
donorRequestModelMock.exports = {
  async create(request) {
    return { _id: 'mock-donor-request', status: 'pending', ...request };
  },
};

const authMock = new Module(authPath);
authMock.filename = authPath;
authMock.loaded = true;
authMock.exports = (req, _res, next) => {
  req.uid = req.headers['x-test-uid'];
  req.firebaseUser = { name: 'Test Donor', email: 'test@example.invalid' };
  next();
};

require.cache[donorModelPath] = donorModelMock;
require.cache[donorRequestModelPath] = donorRequestModelMock;
require.cache[authPath] = authMock;
const donorRoutes = require('../src/routes/donors');
const donorRequestRoutes = require('../src/routes/donorRequests');

after(() => {
  delete require.cache[routesPath];
  delete require.cache[donorRequestRoutesPath];
  if (originalDonorModel) require.cache[donorModelPath] = originalDonorModel;
  else delete require.cache[donorModelPath];
  if (originalDonorRequestModel) require.cache[donorRequestModelPath] = originalDonorRequestModel;
  else delete require.cache[donorRequestModelPath];
  if (originalAuth) require.cache[authPath] = originalAuth;
  else delete require.cache[authPath];
  if (originalDonorRoutes) require.cache[routesPath] = originalDonorRoutes;
  if (originalDonorRequestRoutes) require.cache[donorRequestRoutesPath] = originalDonorRequestRoutes;
});

async function withApi(run) {
  records.clear();
  const app = express();
  app.use(express.json());
  app.use('/donors', donorRoutes);
  app.use('/donor-requests', donorRequestRoutes);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    await run(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((err) => err ? reject(err) : resolve()));
  }
}

async function postJson(base, path, uid, body) {
  return fetch(`${base}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-test-uid': uid },
    body: JSON.stringify(body),
  });
}

async function patchJson(base, path, uid, body) {
  return fetch(`${base}${path}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', 'x-test-uid': uid },
    body: JSON.stringify(body),
  });
}

test('PATCH /donors/me cannot change or clear canonical donation and booking state', async () => {
  await withApi(async (base) => {
    const donatedAt = new Date();
    records.set('donor-1', {
      uid: 'donor-1', registered: true, publicRef: 'ref-1', showToOthers: false,
      lastDonationDate: donatedAt, lastDonationUnits: 2, hospitalBookingActive: true,
      bookingStatus: 'completed', coolingEndsAt: new Date(donatedAt.getTime() + 90 * 86400000),
    });

    const response = await patchJson(base, '/donors/me', 'donor-1', {
      lastDonationDate: null,
      lastDonationUnits: null,
      hospitalBookingActive: false,
      bookingStatus: 'ready_to_donate',
      fullName: 'Updated name',
    });
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.fullName, 'Updated name');
    assert.equal(new Date(body.lastDonationDate).getTime(), donatedAt.getTime());
    assert.equal(body.lastDonationUnits, 2);
    assert.equal(body.hospitalBookingActive, true);
    assert.equal(body.bookingStatus, 'completed');
  });
});

test('repeat registration ignores client donation history and preserves canonical eligibility state', async () => {
  await withApi(async (base) => {
    const donatedAt = new Date();
    const coolingEndsAt = new Date(donatedAt.getTime() + 90 * 86400000);
    records.set('donor-2', {
      uid: 'donor-2', registered: true, publicRef: 'ref-2',
      lastDonationDate: donatedAt, lastDonationUnits: 3, coolingEndsAt,
      hospitalBookingActive: false, bookingStatus: 'completed',
    });

    const response = await postJson(base, '/donors/register', 'donor-2', {
      fullName: 'Donor Two', bloodGroup: 'O+', showToOthers: true, readyAnyTime: true,
      lastDonationDate: new Date(donatedAt.getTime() - 200 * 86400000).toISOString(),
      lastDonationUnits: 7,
    });
    assert.equal(response.status, 201);
    const body = await response.json();
    assert.equal(new Date(body.lastDonationDate).getTime(), donatedAt.getTime());
    assert.equal(body.lastDonationUnits, 3);
    assert.equal(new Date(body.coolingEndsAt).getTime(), coolingEndsAt.getTime());
    assert.equal(body.hospitalBookingActive, false);
    assert.equal(body.bookingStatus, 'completed');
    assert.equal(new Date(body.selfReportedLastDonationDate).getTime(), donatedAt.getTime() - 200 * 86400000);
    assert.equal(body.selfReportedLastDonationUnits, 7);

    const search = await fetch(`${base}/donors/search`, { headers: { 'x-test-uid': 'other-user' } });
    assert.equal(search.status, 200);
    assert.deepEqual(await search.json(), []);
  });
});

test('missing, null, unknown, and proof-pending statuses are excluded from search and donor targeting', async () => {
  await withApi(async (base) => {
    const cases = [
      { uid: 'missing-status', publicRef: '00000000-0000-4000-8000-000000000001' },
      { uid: 'null-status', publicRef: '00000000-0000-4000-8000-000000000002', bookingStatus: null },
      { uid: 'unknown-status', publicRef: '00000000-0000-4000-8000-000000000003', bookingStatus: 'future_status' },
      { uid: 'proof-pending-status', publicRef: '00000000-0000-4000-8000-000000000004', bookingStatus: 'proof_pending' },
    ];
    for (const donor of cases) {
      records.set(donor.uid, {
        ...donor, registered: true, showToOthers: true, manualEntry: false,
        bloodGroup: 'O+', lastDonationDate: null,
      });
    }

    const searchResponse = await fetch(`${base}/donors/search`, {
      headers: { 'x-test-uid': 'searcher' },
    });
    assert.equal(searchResponse.status, 200);
    assert.deepEqual(await searchResponse.json(), []);

    for (const donor of cases) {
      const response = await postJson(base, '/donor-requests', 'requester', {
        donorRef: donor.publicRef, patientName: 'Patient', bloodGroup: 'O+', units: 1,
      });
      assert.equal(response.status, 404, `${donor.uid} must not be targetable`);
      assert.deepEqual(await response.json(), { error: 'Donor not found' });
    }
  });
});

test('completed cooldown, active booking, and eligible statuses are enforced on search and donor targeting', async () => {
  await withApi(async (base) => {
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    const cases = [
      { uid: 'completed-old', publicRef: '00000000-0000-4000-8000-000000000011', bookingStatus: 'completed', lastDonationDate: new Date(now - 91 * day), expected: true },
      { uid: 'completed-recent', publicRef: '00000000-0000-4000-8000-000000000012', bookingStatus: 'completed', lastDonationDate: new Date(now - 89 * day), expected: false },
      { uid: 'completed-missing-date', publicRef: '00000000-0000-4000-8000-000000000013', bookingStatus: 'completed', expected: false },
      { uid: 'completed-null-date', publicRef: '00000000-0000-4000-8000-000000000014', bookingStatus: 'completed', lastDonationDate: null, expected: false },
      { uid: 'completed-invalid-date', publicRef: '00000000-0000-4000-8000-000000000015', bookingStatus: 'completed', lastDonationDate: 'not-a-date', expected: false },
      { uid: 'booked', publicRef: '00000000-0000-4000-8000-000000000016', bookingStatus: 'booked', expected: false },
      { uid: 'confirmed', publicRef: '00000000-0000-4000-8000-000000000017', bookingStatus: 'confirmed', expected: false },
      { uid: 'active-booking', publicRef: '00000000-0000-4000-8000-000000000018', bookingStatus: 'ready_to_donate', hospitalBookingActive: true, expected: false },
      { uid: 'cancelled', publicRef: '00000000-0000-4000-8000-000000000019', bookingStatus: 'cancelled', lastDonationDate: null, expected: true },
      { uid: 'ready', publicRef: '00000000-0000-4000-8000-000000000020', bookingStatus: 'ready_to_donate', lastDonationDate: null, expected: true },
    ];

    for (const donor of cases) {
      records.set(donor.uid, {
        ...donor, registered: true, showToOthers: true, manualEntry: false,
        hospitalBookingActive: donor.hospitalBookingActive ?? false,
        bloodGroup: 'O+', fullName: donor.uid,
      });
    }

    const searchResponse = await fetch(`${base}/donors/search`, {
      headers: { 'x-test-uid': 'searcher' },
    });
    assert.equal(searchResponse.status, 200);
    const searchResults = await searchResponse.json();
    const expectedRefs = cases.filter((donor) => donor.expected).map((donor) => donor.publicRef).sort();
    assert.deepEqual(searchResults.map((donor) => donor.publicRef).sort(), expectedRefs);

    for (const donor of cases) {
      const response = await postJson(base, '/donor-requests', 'requester', {
        donorRef: donor.publicRef, patientName: 'Patient', bloodGroup: 'O+', units: 1,
      });
      assert.equal(response.status, donor.expected ? 201 : 404, `${donor.uid} targeting result`);
    }
  });
});

test('new registration stores donor-reported history separately from canonical eligibility state', async () => {
  await withApi(async (base) => {
    const reportedAt = new Date();
    const response = await postJson(base, '/donors/register', 'new-donor', {
      fullName: 'New Donor', bloodGroup: 'A+', lastDonationDate: reportedAt.toISOString(),
      lastDonationUnits: 1,
    });
    assert.equal(response.status, 201);
    const body = await response.json();
    assert.equal(body.lastDonationDate, null);
    assert.equal(body.lastDonationUnits, null);
    assert.equal(body.bookingStatus, 'ready_to_donate');
    assert.equal(new Date(body.selfReportedLastDonationDate).getTime(), reportedAt.getTime());
    assert.equal(body.selfReportedLastDonationUnits, 1);
  });
});

test('donor search rejects object and operator-shaped blood-group query values', async () => {
  await withApi(async (base) => {
    for (const query of [
      'bloodGroup%5B%24ne%5D=O%2B',
      'bloodGroup%5B%24regex%5D=%2E%2A',
    ]) {
      const response = await fetch(`${base}/donors/search?${query}`, {
        headers: { 'x-test-uid': 'searcher' },
      });
      assert.equal(response.status, 400);
      assert.deepEqual(await response.json(), { error: 'Invalid blood group' });
    }
  });
});

test('donor search preserves filtering for supported scalar blood groups', async () => {
  await withApi(async (base) => {
    records.set('a-donor', {
      uid: 'a-donor', registered: true, publicRef: 'ref-a', showToOthers: true,
      manualEntry: false, bloodGroup: 'A+', bookingStatus: 'ready_to_donate',
    });
    records.set('o-donor', {
      uid: 'o-donor', registered: true, publicRef: 'ref-o', showToOthers: true,
      manualEntry: false, bloodGroup: 'O+', bookingStatus: 'ready_to_donate',
    });

    const response = await fetch(`${base}/donors/search?bloodGroup=O%2B`, {
      headers: { 'x-test-uid': 'searcher' },
    });
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.length, 1);
    assert.equal(body[0].bloodGroup, 'O+');
    assert.equal(body[0].publicRef, 'ref-o');
  });
});
