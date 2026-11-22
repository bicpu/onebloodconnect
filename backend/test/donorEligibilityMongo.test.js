const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const express = require('express');
const http = require('node:http');
const Module = require('node:module');

const mongoTestUri = process.env.ONEBLOOD_MONGODB_TEST_URI;

test('MongoDB integration: donor eligibility states and completed cooldown are enforced on both routes', {
  skip: !mongoTestUri && 'Set ONEBLOOD_MONGODB_TEST_URI to a disposable test database to run.',
}, async () => {
  const parsedUri = new URL(mongoTestUri);
  const databaseName = parsedUri.pathname.replace(/^\//, '').split('/')[0];
  assert.match(databaseName, /test/i, 'refusing to run unless the database name contains "test"');
  assert.ok(
    ['localhost', '127.0.0.1', '[::1]', '::1'].includes(parsedUri.hostname),
    'refusing to run against a non-local MongoDB host',
  );

  const mongoose = require('mongoose');
  const Donor = require('../src/models/Donor');
  const DonorRequest = require('../src/models/DonorRequest');
  const authPath = require.resolve('../src/middleware/auth');
  const donorRoutesPath = require.resolve('../src/routes/donors');
  const donorRequestRoutesPath = require.resolve('../src/routes/donorRequests');
  const originalAuth = require.cache[authPath];
  const originalDonorRoutes = require.cache[donorRoutesPath];
  const originalDonorRequestRoutes = require.cache[donorRequestRoutesPath];
  const authMock = new Module(authPath);
  authMock.filename = authPath;
  authMock.loaded = true;
  authMock.exports = (req, _res, next) => {
    req.uid = req.headers['x-test-uid'];
    req.firebaseUser = {};
    next();
  };

  const prefix = `donor-eligibility-${crypto.randomUUID()}-`;
  const now = Date.now();
  const day = 24 * 60 * 60 * 1000;
  const rows = [
    { uid: `${prefix}missing-status`, publicRef: crypto.randomUUID(), expected: false },
    { uid: `${prefix}null-status`, publicRef: crypto.randomUUID(), bookingStatus: null, expected: false },
    { uid: `${prefix}unknown-status`, publicRef: crypto.randomUUID(), bookingStatus: 'future_status', expected: false },
    { uid: `${prefix}proof-pending`, publicRef: crypto.randomUUID(), bookingStatus: 'proof_pending', expected: false },
    { uid: `${prefix}completed-old`, publicRef: crypto.randomUUID(), bookingStatus: 'completed', lastDonationDate: new Date(now - 91 * day), expected: true },
    { uid: `${prefix}completed-recent`, publicRef: crypto.randomUUID(), bookingStatus: 'completed', lastDonationDate: new Date(now - 89 * day), expected: false },
    { uid: `${prefix}completed-missing-date`, publicRef: crypto.randomUUID(), bookingStatus: 'completed', expected: false },
    { uid: `${prefix}completed-null-date`, publicRef: crypto.randomUUID(), bookingStatus: 'completed', lastDonationDate: null, expected: false },
    { uid: `${prefix}completed-invalid-date`, publicRef: crypto.randomUUID(), bookingStatus: 'completed', lastDonationDate: 'not-a-date', expected: false },
    { uid: `${prefix}booked`, publicRef: crypto.randomUUID(), bookingStatus: 'booked', expected: false },
    { uid: `${prefix}confirmed`, publicRef: crypto.randomUUID(), bookingStatus: 'confirmed', expected: false },
    { uid: `${prefix}active-booking`, publicRef: crypto.randomUUID(), bookingStatus: 'ready_to_donate', hospitalBookingActive: true, expected: false },
    { uid: `${prefix}cancelled`, publicRef: crypto.randomUUID(), bookingStatus: 'cancelled', expected: true },
    { uid: `${prefix}ready`, publicRef: crypto.randomUUID(), bookingStatus: 'ready_to_donate', expected: true },
  ];
  let server;

  require.cache[authPath] = authMock;
  const donorRoutes = require('../src/routes/donors');
  const donorRequestRoutes = require('../src/routes/donorRequests');
  const app = express();
  app.use(express.json());
  app.use('/donors', donorRoutes);
  app.use('/donor-requests', donorRequestRoutes);

  try {
    await mongoose.connect(mongoTestUri, { serverSelectionTimeoutMS: 5000 });
    await Donor.collection.insertMany(rows.map((row) => {
      const { expected: _expected, ...document } = row;
      return {
        ...document,
        fullName: 'Integration Test Donor',
        bloodGroup: 'O+',
        showToOthers: true,
        registered: true,
        manualEntry: false,
        hospitalBookingActive: document.hospitalBookingActive ?? false,
      };
    }));

    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;

    const searchResponse = await fetch(`${base}/donors/search`, {
      headers: { 'x-test-uid': `${prefix}searcher` },
    });
    assert.equal(searchResponse.status, 200);
    const searchResults = await searchResponse.json();
    const eligibleRefs = rows.filter((row) => row.expected).map((row) => row.publicRef).sort();
    assert.deepEqual(searchResults.map((donor) => donor.publicRef).sort(), eligibleRefs);

    for (const row of rows) {
      const response = await fetch(`${base}/donor-requests`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-test-uid': `${prefix}requester`,
        },
        body: JSON.stringify({
          donorRef: row.publicRef,
          patientName: 'Integration Test Patient',
          bloodGroup: 'O+',
          units: 1,
        }),
      });
      assert.equal(response.status, row.expected ? 201 : 404, `${row.uid} targeting result`);
      const result = await response.json();
      if (!row.expected) assert.deepEqual(result, { error: 'Donor not found' });
    }
  } finally {
    if (server?.listening) {
      await new Promise((resolve) => server.close(resolve));
    }
    if (mongoose.connection.readyState !== 0) {
      await DonorRequest.deleteMany({ requesterUid: { $regex: `^${prefix}` } });
      await Donor.collection.deleteMany({ uid: { $regex: `^${prefix}` } });
      await mongoose.disconnect();
    }
    delete require.cache[donorRoutesPath];
    delete require.cache[donorRequestRoutesPath];
    if (originalDonorRoutes) require.cache[donorRoutesPath] = originalDonorRoutes;
    if (originalDonorRequestRoutes) require.cache[donorRequestRoutesPath] = originalDonorRequestRoutes;
    if (originalAuth) require.cache[authPath] = originalAuth;
    else delete require.cache[authPath];
  }
});
