const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const http = require('node:http');
const Module = require('node:module');
const { createDonorSearchRateLimit } = require('../src/middleware/donorSearchRateLimit');

const routesPath = require.resolve('../src/routes/donors');
const cachedRoutes = require.cache[routesPath];
const previousLoad = Module._load;
let currentTime = 1_800_000_000_000;
let lastFilter;
let lastSort;
let lastSkip;
let lastLimit;
let findCalls = 0;

const donorRows = Array.from({ length: 40 }, (_, index) => {
  const sequence = String(index + 1).padStart(24, '0');
  return {
    _id: sequence,
    uid: `private-uid-${index + 1}`,
    publicRef: `public-ref-${index + 1}`,
    fullName: `Donor ${index + 1}`,
    bloodGroup: 'O+',
    city: 'Puducherry',
    donationStream: 'Whole Blood',
    readyAnyTime: true,
    phone: `private-phone-${index + 1}`,
    email: `private-${index + 1}@example.invalid`,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    showToOthers: true,
    registered: true,
    manualEntry: false,
    bookingStatus: 'ready_to_donate',
  };
});

const manualDonor = {
  _id: '64b000000000000000000099',
  uid: 'internal-manual-uid',
  email: 'internal@example.invalid',
  publicRef: 'internal-public-ref',
  fullName: 'Manual Donor',
  bloodGroup: 'A+',
  phone: '555-0100',
  city: 'Puducherry',
  donationStream: 'Whole Blood',
  readyAnyTime: true,
  createdAt: new Date('2026-02-01T00:00:00.000Z'),
  healthEligibility: { privateAnswer: true },
  consentAccepted: true,
};

function sortRows(rows, sort) {
  return [...rows].sort((left, right) => {
    for (const [field, direction] of Object.entries(sort)) {
      const a = left[field];
      const b = right[field];
      if (a < b) return -direction;
      if (a > b) return direction;
    }
    return 0;
  });
}

const Donor = {
  find(filter) {
    findCalls += 1;
    lastFilter = filter;
    let rows = donorRows;
    return {
      select(projection) { this.projection = projection; return this; },
      sort(sort) { lastSort = sort; rows = sortRows(rows, sort); return this; },
      skip(value) { lastSkip = value; rows = rows.slice(value); return this; },
      limit(value) { lastLimit = value; rows = rows.slice(0, value); return this; },
      async lean() { return rows; },
    };
  },
  async findOneAndUpdate() {
    return { toObject: () => ({ ...manualDonor }) };
  },
};

const authenticate = (req, _res, next) => {
  req.uid = req.headers['x-test-uid'] || 'test-user';
  req.firebaseUser = {
    uid: req.uid,
    roles: typeof req.headers['x-test-role'] === 'string'
      ? req.headers['x-test-role'].split(',')
      : [],
  };
  next();
};
const rateLimit = createDonorSearchRateLimit({
  windowMs: 60_000,
  userMax: 2,
  ipMax: 100,
  now: () => currentTime,
});

const stubs = new Map([
  ['../middleware/auth', authenticate],
  ['../middleware/donorSearchRateLimit', rateLimit],
  ['../models/Donor', Donor],
]);

delete require.cache[routesPath];
Module._load = function (request, parent, isMain) {
  if (parent?.filename === routesPath && stubs.has(request)) return stubs.get(request);
  return previousLoad.call(this, request, parent, isMain);
};
const donorRoutes = require(routesPath);
Module._load = previousLoad;

function makeServer() {
  const app = express();
  app.use(express.json());
  app.use('/donors', donorRoutes);
  const server = http.createServer(app);
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

async function withServer(run) {
  const server = await makeServer();
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

function get(base, query = '', uid = 'reader') {
  return fetch(`${base}/donors/search${query}`, { headers: { 'x-test-uid': uid } });
}

test('donor search applies bounded pages, stable ordering, and a privacy allowlist', async () => {
  findCalls = 0;
  await withServer(async (base) => {
    let response = await get(base, '', 'default-page');
    assert.equal(response.status, 200);
    let results = await response.json();
    assert.equal(results.length, 25);
    assert.deepEqual(lastSort, { createdAt: -1, _id: -1 });
    assert.equal(lastSkip, 0);
    assert.equal(lastLimit, 25);
    assert.deepEqual(lastFilter.showToOthers, true);
    assert.equal(lastFilter.consentAccepted, undefined, 'visibility semantics remain unchanged');
    assert.deepEqual(results.map((record) => record.publicRef),
      donorRows.slice().reverse().slice(0, 25).map((record) => record.publicRef));
    for (const result of results) {
      assert.deepEqual(Object.keys(result).sort(), [
        'publicRef', 'fullName', 'bloodGroup', 'city', 'donationStream', 'readyAnyTime',
      ].sort());
      assert.equal(result.uid, undefined);
      assert.equal(result.phone, undefined);
      assert.equal(result.email, undefined);
      assert.equal(result._id, undefined);
    }

    response = await get(base, '?page=2&pageSize=10', 'second-page');
    assert.equal(response.status, 200);
    results = await response.json();
    assert.equal(results.length, 10);
    assert.equal(lastSkip, 10);
    assert.equal(lastLimit, 10);
    assert.deepEqual(results.map((record) => record.publicRef),
      donorRows.slice().reverse().slice(10, 20).map((record) => record.publicRef));

    response = await get(base, '?pageSize=1000', 'maximum-page');
    assert.equal(response.status, 200);
    results = await response.json();
    assert.equal(results.length, 40);
    assert.equal(lastLimit, 100, 'oversized page sizes are clamped to the strict maximum');

    const invalidQueries = [
      ['?page=0', 'Pagination parameters must be positive integers'],
      ['?page=-1', 'Pagination parameters must be positive integers'],
      ['?page=1.5', 'Pagination parameters must be positive integers'],
      ['?page=abc', 'Pagination parameters must be positive integers'],
      ['?page=10001', 'Page is too large'],
      ['?pageSize=0', 'Pagination parameters must be positive integers'],
      ['?pageSize=nope', 'Pagination parameters must be positive integers'],
      ['?pageSize=1&pageSize=2', 'Pagination parameters must be positive integers'],
    ];
    for (const [index, [query, expectedError]] of invalidQueries.entries()) {
      response = await get(base, query, `invalid-${index}`);
      assert.equal(response.status, 400, `${query} is rejected`);
      assert.equal((await response.json()).error, expectedError);
    }
    assert.equal(findCalls, 3, 'invalid pagination is rejected before reaching Mongo queries');
  });
});

test('donor search returns HTTP 429 after the per-user threshold and resets after the window', async () => {
  currentTime += 60_001;
  await withServer(async (base) => {
    assert.equal((await get(base, '', 'rate-limited-user')).status, 200);
    assert.equal((await get(base, '', 'rate-limited-user')).status, 200);
    const limited = await get(base, '', 'rate-limited-user');
    assert.equal(limited.status, 429);
    assert.deepEqual(await limited.json(), { error: 'rate_limit_exceeded' });
    assert.ok(Number(limited.headers.get('retry-after')) > 0);

    currentTime += 60_001;
    assert.equal((await get(base, '', 'rate-limited-user')).status, 200);
  });
});

test('donor search secondary IP threshold limits account rotation from one client address', async () => {
  let now = 1_800_000_100_000;
  const ipLimit = createDonorSearchRateLimit({
    windowMs: 60_000,
    userMax: 10,
    ipMax: 2,
    now: () => now,
  });
  const app = express();
  app.use((req, _res, next) => {
    req.uid = req.headers['x-test-uid'];
    next();
  });
  app.get('/search', ipLimit, (_req, res) => res.json({ ok: true }));
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const base = `http://127.0.0.1:${server.address().port}/search`;
    assert.equal((await fetch(base, { headers: { 'x-test-uid': 'account-a' } })).status, 200);
    assert.equal((await fetch(base, { headers: { 'x-test-uid': 'account-b' } })).status, 200);
    const limited = await fetch(base, { headers: { 'x-test-uid': 'account-c' } });
    assert.equal(limited.status, 429);
    assert.deepEqual(await limited.json(), { error: 'rate_limit_exceeded' });
    now += 60_001;
    assert.equal((await fetch(base, { headers: { 'x-test-uid': 'account-c' } })).status, 200);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
});

test('manual donor creation response contains only admin workflow fields', async () => {
  await withServer(async (base) => {
    const response = await fetch(`${base}/donors/manual`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-test-uid': 'administrator',
        'x-test-role': 'admin',
      },
      body: JSON.stringify({ fullName: 'Manual Donor', bloodGroup: 'A+', phone: '555-0100' }),
    });
    assert.equal(response.status, 201);
    const body = await response.json();
    assert.deepEqual(Object.keys(body).sort(), [
      '_id', 'fullName', 'bloodGroup', 'phone', 'city', 'donationStream', 'readyAnyTime', 'createdAt',
    ].sort());
    assert.equal(body.phone, '555-0100');
    for (const field of ['uid', 'email', 'publicRef', 'healthEligibility', 'consentAccepted']) {
      assert.equal(Object.hasOwn(body, field), false);
    }
  });
});

after(() => {
  delete require.cache[routesPath];
  if (cachedRoutes) require.cache[routesPath] = cachedRoutes;
});
