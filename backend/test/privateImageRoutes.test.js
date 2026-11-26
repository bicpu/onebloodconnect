const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const http = require('node:http');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const Module = require('node:module');
const sharp = require('sharp');
const store = require('../src/storage/privateImageStore');

const tempRoot = path.join(os.tmpdir(), `oneblood-private-route-${process.pid}-${Date.now()}`);
const previousStoragePath = process.env.PRIVATE_FILE_STORAGE_PATH;
process.env.PRIVATE_FILE_STORAGE_PATH = tempRoot;

const accountAId = '64b000000000000000000001';
const accountBId = '64b000000000000000000002';
const bankAccounts = new Map([
  ['bank-a', { _id: accountAId, uid: 'bank-a', isVerified: true, isActive: true }],
  ['bank-b', { _id: accountBId, uid: 'bank-b', isVerified: true, isActive: true }],
  ['bank-pending', { _id: '64b000000000000000000003', uid: 'bank-pending', isVerified: false, isActive: true }],
]);
const bookings = new Map();
const donorRequests = new Map();

function matches(record, filter) {
  if (!record) return false;
  return Object.entries(filter).every(([key, value]) => String(record[key] ?? '') === String(value ?? ''));
}

const Booking = {
  async findOne(filter) {
    const record = bookings.get(String(filter._id));
    return matches(record, filter) ? record : null;
  },
  async findById(id) {
    return bookings.get(String(id)) || null;
  },
};
const DonorRequest = {
  async findOne(filter) {
    const record = donorRequests.get(String(filter._id));
    return matches(record, filter) ? record : null;
  },

  findById(id) {
    return {
      lean: async () => donorRequests.get(String(id)) || null,
    };
  },
};
const BloodBankAccount = {
  findOne(filter) {
    return { lean: async () => bankAccounts.get(filter.uid) || null };
  },
  find() { return { limit() { return this; }, select() { return this; }, lean: async () => [] }; },
};
const authenticate = (req, _res, next) => {
  req.uid = req.headers['x-test-uid'] || '';
  req.firebaseUser = { uid: req.uid, roles: (req.headers['x-test-roles'] || '').split(',').filter(Boolean) };
  next();
};
const requireVerifiedBloodBank = async (req, res, next) => {
  const account = bankAccounts.get(req.uid);
  if (!account) return res.status(403).json({ error: 'bank_account_not_found' });
  if (account.isVerified !== true) return res.status(403).json({ error: 'bank_not_verified' });
  if (account.isActive !== true) return res.status(403).json({ error: 'bank_inactive' });
  req.bankAccount = account;
  next();
};

const routeModules = [
  '../src/routes/bookings', '../src/routes/donorRequests',
  '../src/routes/admin', '../src/routes/bloodBankAccounts',
].map((relative) => require.resolve(relative));
const priorCache = new Map(routeModules.map((key) => [key, require.cache[key]]));
const originalLoad = Module._load;
const appStubs = new Map([
  ['../middleware/auth', authenticate],
  ['../middleware/requireVerifiedBloodBank', requireVerifiedBloodBank],
  ['../models/Booking', Booking],
  ['../models/DonorRequest', DonorRequest],
  ['../models/Donor', {}],
  ['../models/BloodBankAccount', BloodBankAccount],
  ['../models/BloodBank', {}],
  ['../models/BloodRequest', {}],
  ['../config/firebase', { admin: {} }],
]);
for (const key of routeModules) delete require.cache[key];
Module._load = function (request, parent, isMain) {
  if (parent && routeModules.includes(parent.filename) && appStubs.has(request)) {
    return appStubs.get(request);
  }
  return originalLoad.call(this, request, parent, isMain);
};
const bookingRoutes = require('../src/routes/bookings');
const donorRequestRoutes = require('../src/routes/donorRequests');
const adminRoutes = require('../src/routes/admin');
const bankRoutes = require('../src/routes/bloodBankAccounts');
Module._load = originalLoad;

async function createServer() {
  const app = express();
  app.use(express.json());
  app.use('/bookings', bookingRoutes);
  app.use('/donor-requests', donorRequestRoutes);
  app.use('/admin', adminRoutes);
  app.use('/blood-bank-accounts', bankRoutes);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server;
}

async function withServer(run) {
  const server = await createServer();
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

async function pngDataUri() {
  const bytes = await sharp({ create: { width: 2, height: 2, channels: 3, background: '#990000' } })
    .png().toBuffer();
  return `data:image/png;base64,${bytes.toString('base64')}`;
}

function get(base, urlPath, uid, roles = '') {
  return fetch(`${base}${urlPath}`, { headers: { 'x-test-uid': uid, 'x-test-roles': roles } });
}

test('booking and donor-request proof reads enforce owner and participant access without returning Base64 in records', async () => {
  await fs.mkdir(tempRoot, { recursive: true });
  const metadata = await store.storeDataUri(await pngDataUri());
  bookings.set('booking-owned', {
    _id: 'booking-owned', donorUid: 'donor-a', facilityAccountId: accountAId,
    status: 'completed', donationPhoto: metadata, donationPhotoUrl: '',
    doctorSlip: null, doctorSlipUrl: '',
  });
  donorRequests.set('request-owned', {
    _id: 'request-owned', donorUid: 'donor-a', requesterUid: 'requester-a',
    status: 'completed', donationPhoto: metadata, donationPhotoUrl: '',
    doctorSlip: null, doctorSlipUrl: '',
  });

  await withServer(async (base) => {
    const donorProof = await get(base, '/bookings/booking-owned/proof/donation-photo', 'donor-a');
    assert.equal(donorProof.status, 200);
    assert.equal(donorProof.headers.get('content-type'), 'image/png');
    assert.equal(donorProof.headers.get('cache-control'), 'private, no-store');
    assert.equal(donorProof.headers.get('x-content-type-options'), 'nosniff');
    assert.ok((await donorProof.arrayBuffer()).byteLength > 0);
    assert.equal((await get(base, '/bookings/booking-owned/proof/donation-photo', 'donor-b')).status, 404);

    const targetDonor = await get(base, '/donor-requests/request-owned/proof/donation-photo', 'donor-a');
    assert.equal(targetDonor.status, 200);
    assert.equal((await get(base, '/donor-requests/request-owned/proof/donation-photo', 'requester-a')).status, 404);
    assert.equal((await get(base, '/donor-requests/request-owned/proof/donation-photo', 'unrelated')).status, 404);
  });
});

test('admin image route requires admin role and facility image route requires verified account ownership', async () => {
  await fs.mkdir(tempRoot, { recursive: true });
  const metadata = await store.storeDataUri(await pngDataUri());
  bookings.set('bank-owned-booking', {
    _id: 'bank-owned-booking', donorUid: 'donor-a', facilityAccountId: accountAId,
    status: 'completed', doctorSlip: metadata, doctorSlipUrl: '',
  });

  await withServer(async (base) => {
    assert.equal((await get(base, '/admin/donations/bank-owned-booking/proof/doctor-slip', 'ordinary-user')).status, 403);
    assert.equal((await get(base, '/admin/donations/bank-owned-booking/proof/doctor-slip', 'admin-user', 'admin')).status, 200);
    assert.equal((await get(base, '/blood-bank-accounts/donations/bank-owned-booking/proof/doctor-slip', 'bank-a')).status, 200);
    assert.equal((await get(base, '/blood-bank-accounts/donations/bank-owned-booking/proof/doctor-slip', 'bank-b')).status, 404);
    assert.equal((await get(base, '/blood-bank-accounts/donations/bank-owned-booking/proof/doctor-slip', 'bank-pending')).status, 403);
  });
});

test('record APIs expose image availability but never include private bytes or storage keys', async () => {
  await fs.mkdir(tempRoot, { recursive: true });
  const metadata = await store.storeDataUri(await pngDataUri());
  bookings.set('booking-view', {
    _id: 'booking-view', donorUid: 'donor-a', status: 'completed',
    donationPhoto: metadata, donationPhotoUrl: '', doctorSlipUrl: '',
  });
  donorRequests.set('request-view', {
    _id: 'request-view', donorUid: 'donor-a', requesterUid: 'requester-a', status: 'completed',
    donationPhoto: metadata, donationPhotoUrl: '', doctorSlipUrl: '',
  });

  await withServer(async (base) => {
    const booking = await (await get(base, '/bookings/booking-view', 'donor-a')).json();
    assert.equal(booking.donationPhotoAvailable, true);
    assert.equal(booking.donationPhotoUrl, undefined);
    assert.equal(booking.donationPhoto, undefined);
    assert.equal(JSON.stringify(booking).includes(metadata.key), false);

    const request = await (await get(base, '/donor-requests/request-view', 'donor-a')).json();
    assert.equal(request.donationPhotoAvailable, true);
    assert.equal(request.donationPhotoUrl, undefined);
    assert.equal(request.donationPhoto, undefined);
    assert.equal(JSON.stringify(request).includes(metadata.key), false);
  });
});

after(async () => {
  await fs.rm(tempRoot, { recursive: true, force: true });
  if (previousStoragePath === undefined) delete process.env.PRIVATE_FILE_STORAGE_PATH;
  else process.env.PRIVATE_FILE_STORAGE_PATH = previousStoragePath;
  for (const key of routeModules) {
    delete require.cache[key];
    const cached = priorCache.get(key);
    if (cached) require.cache[key] = cached;
  }
});
