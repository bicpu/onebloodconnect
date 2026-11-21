const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { createRequireVerifiedBloodBank } = require('../src/middleware/requireVerifiedBloodBank');
const backendRoot = path.resolve(__dirname, '..');

function responseRecorder() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

async function invoke(middleware, req) {
  const res = responseRecorder();
  let nextCalled = false;
  await middleware(req, res, () => { nextCalled = true; });
  return { res, nextCalled };
}

function source(file) {
  return fs.readFileSync(path.join(backendRoot, file), 'utf8');
}

test('bank status middleware requires an account, verification, and active state', async () => {
  const cases = [
    { account: null, error: 'bank_account_not_found' },
    { account: { _id: '64b000000000000000000001', isVerified: false, isActive: true }, error: 'bank_not_verified' },
    { account: { _id: '64b000000000000000000001', isVerified: true, isActive: false }, error: 'bank_inactive' },
    { account: { _id: '64b000000000000000000001', isVerified: 1, isActive: true }, error: 'bank_not_verified' },
    { account: { _id: '64b000000000000000000001', isVerified: true, isActive: true }, error: null },
    { account: { isVerified: true, isActive: true }, error: 'bank_ownership_unavailable' },
  ];

  for (const { account, error } of cases) {
    const middleware = createRequireVerifiedBloodBank(async (uid) => {
      assert.equal(uid, 'bank-uid');
      return account;
    });
    const req = { uid: 'bank-uid' };
    const { res, nextCalled } = await invoke(middleware, req);
    if (error) {
      assert.equal(res.statusCode, 403);
      assert.equal(res.body.error, error);
      assert.equal(nextCalled, false);
      assert.equal(req.bankAccount, undefined);
    } else {
      assert.equal(nextCalled, true);
      assert.equal(req.bankAccount, account);
    }
  }
});

test('bank status lookup failure does not allow the operation', async () => {
  const middleware = createRequireVerifiedBloodBank(async () => {
    throw new Error('database unavailable');
  });
  const { res, nextCalled } = await invoke(middleware, { uid: 'bank-uid' });
  assert.equal(res.statusCode, 500);
  assert.equal(res.body.error, 'bank_status_unavailable');
  assert.equal(nextCalled, false);
});

test('registration forces pending verification and profile updates exclude status fields', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  const register = routes.slice(routes.indexOf("router.post('/register'"), routes.indexOf('router.use(authenticate)'));
  assert.match(register, /isVerified:\s*false/);
  assert.doesNotMatch(register, /req\.body\.isVerified|req\.body\.isActive/);
  assert.match(routes, /const profileFields = \[[\s\S]*?'registrationNo'[\s\S]*?'pincode'/);
  assert.doesNotMatch(routes.match(/const profileFields = \[([\s\S]*?)\];/)[1], /isVerified|isActive|stock|slots|doctors|nurses|hours/);
  assert.match(routes, /approvalRequiredFields\.some/);
});

test('all bank operational routes apply the verified-and-active middleware', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  for (const route of [
    "router.get('/active-requests', requireVerifiedBloodBank",
    "router.patch('/requests/:id/review', requireVerifiedBloodBank",
    "router.get('/stats', requireVerifiedBloodBank",
    "router.get('/donations/pending', requireVerifiedBloodBank",
    "router.patch('/donations/:id/verify', requireVerifiedBloodBank",
  ]) {
    assert.ok(routes.includes(route), `missing guard for ${route}`);
  }
  assert.match(routes, /router\.patch\('\/me', async \(req, res, next\)/);
  assert.match(routes, /if \(approvalRequiredFields\.some/);
});

test('donation endpoints are registered at router initialization exactly once', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  const statsStart = routes.indexOf("router.get('/stats'");
  const donationRegistrationStart = routes.indexOf('// Registered at startup', statsStart);
  assert.notEqual(statsStart, -1, 'stats route must exist');
  assert.notEqual(donationRegistrationStart, -1, 'top-level donation routes must follow stats handler');

  // Isolate the stats route through the next top-level registration. This
  // catches the original defect where router.get/router.patch calls appeared
  // inside the stats callback and were only run after an HTTP request.
  const statsHandler = routes.slice(statsStart, donationRegistrationStart);
  assert.match(statsHandler, /router\.get\('\/stats',[\s\S]*?\n\}\);\s*$/);
  const statsCallback = statsHandler.slice(statsHandler.indexOf('=> {') + '=> {'.length);
  assert.doesNotMatch(statsCallback, /router\.(?:get|post|patch|put|delete)\(/);

  assert.equal((routes.match(/router\.get\('\/donations\/pending'/g) || []).length, 1);
  assert.equal((routes.match(/router\.patch\('\/donations\/:id\/verify'/g) || []).length, 1);
  assert.match(routes.slice(donationRegistrationStart), /^\/\/ Registered at startup[\s\S]*?^router\.get\('\/donations\/pending'/m);
  assert.match(routes.slice(donationRegistrationStart), /^router\.patch\('\/donations\/:id\/verify'/m);
  assert.match(routes, /router\.get\('\/donations\/pending', requireVerifiedBloodBank/);
  assert.match(routes, /router\.patch\('\/donations\/:id\/verify', requireVerifiedBloodBank/);
  assert.match(routes, /facilityOwnershipFilter\('facilityAccountId', req\.bankAccount\)/);
  assert.match(routes, /Booking\.findOne\(\{ _id: req\.params\.id, \.\.\.ownership \}\)/);
});

test('directory reads filter by both active and verified state', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  assert.match(routes, /router\.get\('\/all', async/);
  assert.match(routes, /isActive: true,[\s\S]*?isVerified: true,[\s\S]*?facilityRef: \{ \$type: 'string', \$ne: '' \}/);
  const directory = routes.slice(routes.indexOf("router.get('/all'"));
  assert.match(directory, /\.select\(\{\s*_id: 0,\s*facilityRef: 1,\s*name: 1,\s*address: 1,\s*city: 1,\s*phone: 1,\s*hours: 1,\s*isVerified: 1,\s*stock: 1,\s*\}\)/);
  assert.doesNotMatch(directory, /uid: 1|email: 1|website: 1|registrationNo: 1|isActive: 1|slots: 1|doctors: 1|nurses: 1|facilityAccountId/);
});

test('pending account listing and approval are behind the admin router guard', () => {
  const routes = source('src/routes/admin.js');
  assert.match(routes, /router\.use\(authenticate, authorizeRoles\('admin'\)\)/);
  assert.match(routes, /router\.get\('\/blood-bank-accounts\/pending'/);
  assert.match(routes, /router\.patch\('\/blood-bank-accounts\/:id\/approve'/);
  const pending = routes.slice(
    routes.indexOf("router.get('/blood-bank-accounts/pending'"),
    routes.indexOf("router.patch('/blood-bank-accounts/:id/approve'"),
  );
  assert.match(pending, /\.select\(\{\s*name: 1,\s*registrationNo: 1,\s*email: 1,\s*phone: 1,\s*address: 1,\s*city: 1,\s*state: 1,\s*\}\)/);
  assert.doesNotMatch(pending, /uid: 1|stock: 1|slots: 1|doctors: 1|nurses: 1|isActive: 1/);
  const approval = routes.slice(
    routes.indexOf("router.patch('/blood-bank-accounts/:id/approve'"),
    routes.indexOf("// ─── GET /admin/donations/pending"),
  );
  assert.match(approval, /\{ _id: req\.params\.id, isVerified: \{ \$ne: true \} \}/);
  assert.match(approval, /\$set:\s*\{ isVerified: true \}/);
  assert.doesNotMatch(approval, /req\.body|isActive:/);
});
