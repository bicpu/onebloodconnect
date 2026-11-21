const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createTransactionRunner, TransactionUnavailableError } = require('../src/db/transactions');

const backendRoot = path.resolve(__dirname, '..');
function source(file) {
  return fs.readFileSync(path.join(backendRoot, file), 'utf8');
}

function fakeTransactionalRunner(state) {
  return createTransactionRunner(async () => ({
    async withTransaction(work) {
      const before = structuredClone(state);
      try {
        return await work(this);
      } catch (error) {
        for (const key of Object.keys(state)) delete state[key];
        Object.assign(state, before);
        throw error;
      }
    },
    async endSession() {},
  }));
}

test('transaction wrapper rolls back document state when the second write fails', async () => {
  const state = { bookingStatus: 'confirmed', donorStatus: 'confirmed' };
  const run = fakeTransactionalRunner(state);
  await assert.rejects(run(async () => {
    state.bookingStatus = 'completed';
    throw new Error('simulated donor update failure');
  }), /simulated donor update failure/);
  assert.deepEqual(state, { bookingStatus: 'confirmed', donorStatus: 'confirmed' });
});

test('retry after aborted transaction commits the two related states once', async () => {
  const state = { requestStatus: 'received', donorCommitment: null, attempts: 0 };
  const run = fakeTransactionalRunner(state);
  const operation = async (failSecondWrite) => run(async () => {
    state.attempts += 1;
    state.requestStatus = 'fulfilled';
    if (failSecondWrite) throw new Error('simulated donor pointer write failure');
    state.donorCommitment = 'request-ref';
  });

  await assert.rejects(operation(true), /simulated donor pointer write failure/);
  assert.deepEqual(state, { requestStatus: 'received', donorCommitment: null, attempts: 0 });
  await operation(false);
  assert.deepEqual(state, { requestStatus: 'fulfilled', donorCommitment: 'request-ref', attempts: 1 });
});

test('unsupported MongoDB transaction topology fails closed with an explicit error', async () => {
  const run = createTransactionRunner(async () => ({
    async withTransaction() {
      const error = new Error('Transaction numbers are only allowed on a replica set member or mongos');
      error.code = 20;
      throw error;
    },
    async endSession() {},
  }));
  await assert.rejects(run(async () => {}), (error) => error instanceof TransactionUnavailableError &&
    error.code === 'transactions_unavailable');
});

test('all identified multi-document mutations pass one MongoDB session to their writes', () => {
  const bookings = source('src/routes/bookings.js');
  const bloodRequests = source('src/routes/bloodRequests.js');
  const bankRoutes = source('src/routes/bloodBankAccounts.js');
  const adminRoutes = source('src/routes/admin.js');
  const donorRequests = source('src/routes/donorRequests.js');

  for (const [name, routes, marker] of [
    ['booking create', bookings, "router.post('/', async (req, res) => {"],
    ['booking completion', bookings, "router.patch('/:id/complete', async (req, res) => {"],
    ['booking cancellation', bookings, "router.patch('/:id/cancel', async (req, res) => {"],
    ['booking not-donated', bookings, "router.patch('/:id/not-donated', async (req, res) => {"],
    ['blood response', bloodRequests, "router.patch('/:id/respond', async (req, res) => {"],
    ['blood withdrawal', bloodRequests, "router.patch('/:id/withdraw', async (req, res) => {"],
    ['bank donation verification', bankRoutes, "router.patch('/donations/:id/verify', requireVerifiedBloodBank"],
    ['admin donation verification', adminRoutes, "router.patch('/donations/:id/verify', async (req, res) => {"],
    ['direct donor-request completion', donorRequests, "router.patch('/:id/complete', async (req, res) => {"],
  ]) {
    const start = routes.indexOf(marker);
    assert.notEqual(start, -1, `${name} route exists`);
    const nextRoute = routes.indexOf('\nrouter.', start + marker.length);
    const section = routes.slice(start, nextRoute < 0 ? routes.length : nextRoute);
    assert.match(section, /runInTransaction\(async \(session\)/, `${name} runs in a transaction`);
    assert.match(section, /\{ session \}/, `${name} passes the session to its writes`);
    assert.match(section, /sendTransactionUnavailable\(err, res\)/, `${name} fails closed without transaction support`);
  }
});

test('existing authorization and stable ownership checks remain on transactional workflows', () => {
  const bookings = source('src/routes/bookings.js');
  const bloodRequests = source('src/routes/bloodRequests.js');
  const bankRoutes = source('src/routes/bloodBankAccounts.js');
  const adminRoutes = source('src/routes/admin.js');
  const donorRequests = source('src/routes/donorRequests.js');
  assert.match(bookings, /router\.use\(authenticate\)/);
  assert.match(bloodRequests, /router\.use\(authenticate\)/);
  assert.match(bankRoutes, /router\.patch\('\/donations\/:id\/verify', requireVerifiedBloodBank/);
  assert.match(bankRoutes, /facilityOwnershipFilter\('facilityAccountId', req\.bankAccount\)/);
  assert.match(adminRoutes, /router\.use\(authenticate, authorizeRoles\('admin'\)\)/);
  assert.match(donorRequests, /request\.donorUid !== req\.uid/);
});

test('blood-bank stock profile mutation remains a single-document update', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  const profile = routes.slice(routes.indexOf("router.patch('/me'"), routes.indexOf("router.get('/active-requests'"));
  assert.match(profile, /findOneAndUpdate\(/);
  assert.doesNotMatch(profile, /Booking\.|BloodRequest\.|Donor\./);
});
