const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  FacilitySelectionError,
  createFacilityResolver,
  facilityOwnershipFilter,
  hasFacilityOwnership,
} = require('../src/facilities/facilitySelection');

const backendRoot = path.resolve(__dirname, '..');
const idA = '64b000000000000000000001';
const idB = '64b000000000000000000002';
const refA = 'a4f8e222-33c4-4c31-8f06-741883d2c921';
const refB = 'b4f8e222-33c4-4c31-8f06-741883d2c922';

function source(file) {
  return fs.readFileSync(path.join(backendRoot, file), 'utf8');
}

test('facility reference resolves to the selected account ObjectId, not its editable name', async () => {
  const accounts = new Map([
    [refA, { _id: idA, name: 'Same Facility', address: 'Old address', isVerified: true, isActive: true }],
    [refB, { _id: idB, name: 'Same Facility', address: 'Different address', isVerified: true, isActive: true }],
  ]);
  const resolve = createFacilityResolver({
    findAccountByRef: async (ref) => accounts.get(ref),
    findDirectoryById: async () => null,
  });

  const selectedA = await resolve({ facilityRef: refA });
  const selectedB = await resolve({ facilityRef: refB });
  assert.equal(selectedA.facilityAccountId, idA);
  assert.equal(selectedB.facilityAccountId, idB);
  assert.equal(selectedA.facilityName, selectedB.facilityName);
  assert.equal(selectedA.facilityAddress, 'Old address');
});

test('ownership is tied to account ObjectId despite same or changed display names', () => {
  const bankA = { _id: idA, name: 'Shared Name' };
  const bankB = { _id: idB, name: 'Shared Name' };
  const record = { facilityAccountId: idA, facilityName: 'Renamed Bank' };

  assert.deepEqual(facilityOwnershipFilter('facilityAccountId', bankA), { facilityAccountId: idA });
  assert.equal(hasFacilityOwnership(record, 'facilityAccountId', bankA), true);
  assert.equal(hasFacilityOwnership(record, 'facilityAccountId', bankB), false);
  assert.equal(hasFacilityOwnership({ facilityAccountId: idA }, 'facilityAccountId', {
    _id: idA,
    name: 'Current Name',
  }), true);
});

test('missing and invalid stable identifiers fail closed', async () => {
  assert.equal(facilityOwnershipFilter('facilityAccountId', { name: 'Bank' }), null);
  assert.equal(facilityOwnershipFilter('facilityAccountId', { _id: 'not-an-object-id' }), null);
  assert.equal(hasFacilityOwnership({ facilityAccountId: null }, 'facilityAccountId', { _id: idA }), false);

  const resolve = createFacilityResolver({
    findAccountByRef: async () => ({ name: 'Bank', isVerified: true, isActive: true }),
    findDirectoryById: async () => null,
  });
  await assert.rejects(resolve({ facilityRef: refA }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'facility_ownership_unavailable');
  await assert.rejects(resolve({ directoryId: 'bad-id' }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'invalid_facility_reference');

  await assert.rejects(resolve({ facilityRef: 'not-a-uuid' }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'invalid_facility_reference');
  await assert.rejects(resolve({ facilityRef: refA, directoryId: idA }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'one_facility_reference_required');
});

test('ambiguous facility references and unverified directory entries are rejected', async () => {
  const duplicateResolver = createFacilityResolver({
    findAccountByRef: async () => [
      { _id: idA, name: 'Bank A', isVerified: true, isActive: true },
      { _id: idB, name: 'Bank B', isVerified: true, isActive: true },
    ],
    findDirectoryById: async () => null,
  });
  await assert.rejects(duplicateResolver({ facilityRef: refA }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'facility_reference_ambiguous');

  const unverifiedDirectoryResolver = createFacilityResolver({
    findAccountByRef: async () => null,
    findDirectoryById: async () => ({ _id: idA, name: 'Unverified', isVerified: false }),
  });
  await assert.rejects(unverifiedDirectoryResolver({ directoryId: idA }), (error) =>
    error instanceof FacilitySelectionError && error.code === 'facility_unavailable');
});

test('unverified and inactive account selections cannot create linked records', async () => {
  for (const account of [
    { _id: idA, isVerified: false, isActive: true },
    { _id: idA, isVerified: true, isActive: false },
  ]) {
    const resolve = createFacilityResolver({
      findAccountByRef: async () => account,
      findDirectoryById: async () => null,
    });
    await assert.rejects(resolve({ facilityRef: refA }), (error) =>
      error instanceof FacilitySelectionError && error.code === 'facility_unavailable');
  }
});

test('booking and blood-request creation persist resolver-derived IDs and not client names or UIDs', () => {
  const bookings = source('src/routes/bookings.js');
  const requests = source('src/routes/bloodRequests.js');
  assert.match(bookings, /const facility = await resolveFacilitySelection/);
  assert.match(bookings, /facilityAccountId:\s*facility\.facilityAccountId/);
  assert.match(bookings, /facilityDirectoryId:\s*facility\.facilityDirectoryId/);
  assert.doesNotMatch(bookings, /facilityName,\s*facilityAddress,\s*facilityPhone/);

  assert.match(requests, /facility = await resolveFacilitySelection/);
  assert.match(requests, /targetFacilityAccountId:\s*facility\?\.facilityAccountId/);
  assert.match(requests, /targetFacilityDirectoryId:\s*facility\?\.facilityDirectoryId/);
  assert.doesNotMatch(requests, /targetFacilityUid:\s*targetFacilityUid/);
});

test('registration generates facilityRef server-side and profile updates cannot overwrite it', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  const model = source('src/models/BloodBankAccount.js');
  const registration = routes.slice(
    routes.indexOf("router.post('/register'"),
    routes.indexOf('// The profile/status endpoints remain available'),
  );
  assert.match(routes, /facilityRef:\s*randomUUID\(\)/);
  assert.doesNotMatch(registration, /const\s*\{[^}]*\bfacilityRef\b[^}]*\}\s*=\s*req\.body/s);
  assert.match(routes, /const updateFields\s*=\s*\[\.\.\.profileFields,\s*'hours',\s*\.\.\.operationalFields\]/);
  assert.doesNotMatch(routes, /const profileFields\s*=\s*\[[^\]]*facilityRef/s);
  assert.match(model, /facilityRef:\s*\{[^}]*unique:\s*true[^}]*sparse:\s*true[^}]*immutable:\s*true/s);
});

test('resolver route queries cap account matches and select only verified directory entries', () => {
  for (const routeFile of ['src/routes/bookings.js', 'src/routes/bloodRequests.js']) {
    const routes = source(routeFile);
    assert.match(routes, /BloodBankAccount\.find\(\{[\s\S]*?facilityRef,[\s\S]*?isVerified:\s*true,[\s\S]*?isActive:\s*true,[\s\S]*?\}\)\.limit\(2\)/);
    assert.match(routes, /BloodBank\.findOne\(\{\s*_id:\s*id,\s*isVerified:\s*true\s*\}\)/);
  }
});

test('blood-bank request and donation access queries use only stable account ownership IDs', () => {
  const routes = source('src/routes/bloodBankAccounts.js');
  assert.match(routes, /facilityOwnershipFilter\('targetFacilityAccountId', account\)/);
  assert.match(routes, /facilityOwnershipFilter\('facilityAccountId', req\.bankAccount\)/);
  assert.match(routes, /BloodRequest\.findOne\(\{ _id: req\.params\.id, \.\.\.ownership \}\)/);
  assert.match(routes, /Booking\.findOne\(\{ _id: req\.params\.id, \.\.\.ownership \}\)/);
  assert.doesNotMatch(routes, /targetFacilityName\s*===\s*account\.name|facilityName:\s*req\.bankAccount\.name/);
});
