const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const createAuthenticate = require('../src/middleware/createAuthenticate');
const authorizeRoles = require('../src/middleware/authorizeRoles');
const updateAdminRoleClaims = require('../src/auth/adminClaims');
const { removeAdminRoleWithRevocation } = require('../scripts/manage-admin-role');

const backendRoot = path.resolve(__dirname, '..');

function responseRecorder() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

async function runMiddleware(middleware, req) {
  const res = responseRecorder();
  let nextCalled = false;
  await middleware(req, res, () => { nextCalled = true; });
  return { res, nextCalled };
}

function readRoute(name) {
  return fs.readFileSync(path.join(backendRoot, 'src', 'routes', name), 'utf8');
}

test('missing and invalid Firebase tokens return 401', async () => {
  const authenticate = createAuthenticate(async (token) => {
    if (token !== 'valid-token') throw new Error('invalid token');
    return { uid: 'user-1' };
  });

  const missing = await runMiddleware(authenticate, { headers: {} });
  assert.equal(missing.res.statusCode, 401);
  assert.equal(missing.nextCalled, false);

  const invalid = await runMiddleware(authenticate, {
    headers: { authorization: 'Bearer invalid-token' },
  });
  assert.equal(invalid.res.statusCode, 401);
  assert.equal(invalid.nextCalled, false);
});

test('verified donor token without admin role receives 403', async () => {
  const authenticate = createAuthenticate(async () => ({ uid: 'donor-1', roles: ['donor'] }));
  const req = { headers: { authorization: 'Bearer donor-token' } };
  const auth = await runMiddleware(authenticate, req);
  assert.equal(auth.nextCalled, true);

  const authorization = await runMiddleware(authorizeRoles('admin'), req);
  assert.equal(authorization.res.statusCode, 403);
  assert.equal(authorization.nextCalled, false);
});

test('admin role grants access and supports multiple roles', async () => {
  for (const roles of [['admin'], ['donor', 'admin']]) {
    const authenticate = createAuthenticate(async () => ({ uid: 'admin-1', roles }));
    const req = { headers: { authorization: 'Bearer admin-token' } };
    await runMiddleware(authenticate, req);
    const result = await runMiddleware(authorizeRoles('admin'), req);
    assert.equal(result.nextCalled, true);
    assert.equal(result.res.statusCode, 200);
  }
});

test('blood-bank-only, missing, malformed, and unknown roles are denied', async () => {
  const claimCases = [
    { uid: 'bank-1', roles: ['blood_bank'] },
    { uid: 'user-1' },
    { uid: 'user-1', roles: 'admin' },
    { uid: 'user-1', roles: [] },
    { uid: 'user-1', roles: ['superuser'] },
    { uid: 'user-1', roles: ['admin', 'superuser'] },
    { uid: 'user-1', roles: ['admin', 42] },
  ];

  for (const claims of claimCases) {
    const authenticate = createAuthenticate(async () => claims);
    const req = { headers: { authorization: 'Bearer token' } };
    await runMiddleware(authenticate, req);
    const result = await runMiddleware(authorizeRoles('admin'), req);
    assert.equal(result.res.statusCode, 403);
    assert.equal(result.nextCalled, false);
  }
});

test('request-supplied role values cannot grant access', async () => {
  const authenticate = createAuthenticate(async () => ({ uid: 'donor-1', roles: ['donor'] }));
  const req = {
    headers: { authorization: 'Bearer donor-token', 'x-role': 'admin' },
    body: { role: 'admin', roles: ['admin'] },
    query: { role: 'admin' },
  };
  await runMiddleware(authenticate, req);
  const result = await runMiddleware(authorizeRoles('admin'), req);
  assert.equal(result.res.statusCode, 403);
});

test('trusted claim updates preserve unrelated claims and other roles', () => {
  const original = { department: 'operations', roles: ['donor', 'blood_bank'] };
  const granted = updateAdminRoleClaims(original, 'grant');
  assert.deepEqual(granted.roles, ['donor', 'blood_bank', 'admin']);
  assert.equal(granted.department, 'operations');
  assert.deepEqual(original.roles, ['donor', 'blood_bank']);

  const revoked = updateAdminRoleClaims(granted, 'revoke');
  assert.deepEqual(revoked.roles, ['donor', 'blood_bank']);
  assert.equal(revoked.department, 'operations');
});

test('trusted claim updates fail closed on unknown roles', () => {
  assert.throws(() => updateAdminRoleClaims({ roles: ['root'] }, 'grant'));
});

test('revoke reports claim-removal failure without attempting token revocation', async () => {
  let tokenRevocationAttempted = false;
  const errors = [];
  const warnings = [];

  await assert.rejects(
    removeAdminRoleWithRevocation({
      updateClaims: async () => { throw new Error('firebase details'); },
      revokeRefreshTokens: async () => { tokenRevocationAttempted = true; },
      logError: (message) => errors.push(message),
      logWarning: (message) => warnings.push(message),
    }),
    /claim removal failed/i,
  );

  assert.equal(tokenRevocationAttempted, false);
  assert.match(errors[0], /Failed to remove the administrator claim/);
  assert.equal(warnings.length, 0);
  assert.doesNotMatch(errors.join(' '), /firebase details/);
});

test('revoke warns and fails if token revocation fails after claim removal', async () => {
  let claimRemoved = false;
  let revocationAttempted = false;
  const errors = [];
  const warnings = [];

  await assert.rejects(
    removeAdminRoleWithRevocation({
      updateClaims: async () => { claimRemoved = true; },
      revokeRefreshTokens: async () => {
        revocationAttempted = true;
        throw new Error('firebase details');
      },
      logError: (message) => errors.push(message),
      logWarning: (message) => warnings.push(message),
    }),
    /revocation is incomplete/i,
  );

  assert.equal(claimRemoved, true);
  assert.equal(revocationAttempted, true);
  assert.match(errors[0], /claim was removed.*revocation failed/i);
  assert.match(warnings[0], /may remain valid until expiry/i);
  assert.match(warnings[0], /Retry this revoke command and verify/i);
  assert.match(warnings[0], /admin claim was not restored/i);
  assert.doesNotMatch([...errors, ...warnings].join(' '), /firebase details/);
});

test('all admin router routes inherit authentication and admin authorization', () => {
  const source = readRoute('admin.js');
  assert.match(source, /router\.use\(authenticate,\s*authorizeRoles\('admin'\)\)/);
  assert.equal((source.match(/router\.(?:get|post|patch|delete|put)\(/g) || []).length, 6);
});

test('Firebase token verification checks revocation', () => {
  const source = fs.readFileSync(path.join(backendRoot, 'src', 'middleware', 'auth.js'), 'utf8');
  assert.match(source, /verifyIdToken\(idToken,\s*true\)/);
});

test('admin-only bank and manual-donor routes are guarded; directory reads remain donor-accessible', () => {
  const banks = readRoute('bloodBanks.js');
  assert.match(banks, /router\.use\(authenticate\)/);
  assert.match(banks, /router\.get\('\/',\s*async/);
  assert.match(banks, /router\.post\('\/',\s*authorizeRoles\('admin'\)/);
  assert.match(banks, /router\.delete\('\/:id',\s*authorizeRoles\('admin'\)/);

  const donors = readRoute('donors.js');
  assert.match(donors, /router\.use\(authenticate\)/);
  assert.match(donors, /router\.get\('\/me',\s*async/);
  assert.match(donors, /router\.get\('\/search',\s*async/);
  assert.match(donors, /router\.get\('\/manual',\s*authorizeRoles\('admin'\)/);
  assert.match(donors, /router\.post\('\/manual',\s*authorizeRoles\('admin'\)/);
  assert.match(donors, /router\.delete\('\/manual\/:id',\s*authorizeRoles\('admin'\)/);
});
