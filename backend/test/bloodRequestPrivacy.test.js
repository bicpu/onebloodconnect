const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  serializeBloodRequest,
  serializeRequesterBloodRequest,
  serializeFacilityBloodRequest,
} = require('../src/privacy/donorResponses');

const root = path.resolve(__dirname, '..');
const repoRoot = path.resolve(root, '..');
const read = (base, file) => fs.readFileSync(path.join(base, file), 'utf8');

test('public donor feed omits patient, requester, participant, facility, and internal identifiers', () => {
  const record = {
    _id: 'action-id', requesterUid: 'requester-uid', responderUid: 'donor-uid',
    patientName: 'Patient', patientAge: 50, patientGender: 'Other',
    hospital: 'Hospital', ward: 'ICU', bedNumber: '4', attender: 'Attender',
    contactPhone: 'private-phone', email: 'private-email',
    targetFacilityAccountId: 'account-id', targetFacilityDirectoryId: 'directory-id',
    targetFacilityUid: 'bank-uid', targetFacilityName: 'Bank', targetFacilityPhone: 'bank-phone',
    attachmentFileName: 'report.pdf', facilityReviewedBy: 'admin-uid',
    responses: [{ _id: 'nested-id', responderUid: 'donor-uid', responderName: 'Donor' }],
    timeline: [{ note: 'private details' }],
    bloodGroup: 'O+', units: 2, unitsRemaining: 1, component: 'Whole Blood',
    urgency: 'Urgent', hubZone: 'North zone', status: 'received',
  };
  const result = serializeBloodRequest(record, 'donor-uid');
  for (const field of [
    'requesterUid', 'responderUid', 'patientName', 'patientAge', 'patientGender',
    'hospital', 'ward', 'bedNumber', 'attender', 'contactPhone', 'email',
    'targetFacilityAccountId', 'targetFacilityDirectoryId', 'targetFacilityUid',
    'targetFacilityName', 'targetFacilityPhone', 'attachmentFileName',
    'facilityReviewedBy', 'responses', 'timeline',
  ]) assert.equal(result[field], undefined, `${field} must not be exposed`);
  assert.deepEqual(
    Object.keys(result).sort(),
    ['_id', 'bloodGroup', 'units', 'unitsRemaining', 'component', 'urgency',
      'hubZone', 'status', 'hasResponded', 'myUnitsCommitted'].sort(),
  );
  assert.equal(result.hubZone, '', 'unrecognized client-supplied location text is not returned');
});

test('donor feed preserves only the existing coarse hub labels', () => {
  assert.equal(
    serializeBloodRequest({ hubZone: 'JIPMER / Gorimedu' }).hubZone,
    'JIPMER / Gorimedu',
  );
  assert.equal(
    serializeBloodRequest({ hubZone: 'Patient address and phone' }).hubZone,
    '',
  );
});

test('owner and targeted-facility views retain required operational details but omit UIDs and account IDs', () => {
  const record = {
    _id: 'request-id', requesterUid: 'uid', targetFacilityAccountId: 'bank-id',
    targetFacilityDirectoryId: 'directory-id', facilityReviewedBy: 'admin-uid',
    patientName: 'Patient', hospital: 'Hospital', contactPhone: 'phone',
    bloodGroup: 'A+', units: 1,
  };
  for (const result of [serializeRequesterBloodRequest(record), serializeFacilityBloodRequest(record)]) {
    assert.equal(result.patientName, 'Patient');
    assert.equal(result.contactPhone, 'phone');
    assert.equal(result.requesterUid, undefined);
    assert.equal(result.targetFacilityAccountId, undefined);
    assert.equal(result.targetFacilityDirectoryId, undefined);
    assert.equal(result.facilityReviewedBy, undefined);
  }
});

test('targeted request visibility and response access are checked server-side', () => {
  const routes = read(root, 'src/routes/bloodRequests.js');
  assert.match(routes, /router\.get\('\/active'[\s\S]*targetFacilityAccountId[\s\S]*targetFacilityDirectoryId[\s\S]*targetFacilityUid[\s\S]*targetFacilityName[\s\S]*targetFacilityAddress[\s\S]*targetFacilityPhone/);
  assert.match(routes, /router\.patch\('\/:id\/respond'[\s\S]*select\('\+targetFacilityAccountId \+targetFacilityDirectoryId'\)[\s\S]*request_not_available/);
  assert.match(routes, /requesterUid:\s*req\.uid/);
  assert.match(routes, /request\.requesterUid !== req\.uid/);
  assert.match(routes, /serializeRequesterBloodRequest\(request\)/);
});

test('blood bank request endpoints use an explicit facility response allowlist after ownership checks', () => {
  const routes = read(root, 'src/routes/bloodBankAccounts.js');
  assert.match(routes, /facilityOwnershipFilter\('targetFacilityAccountId', account\)/);
  assert.match(routes, /findOne\(\{ _id: req\.params\.id, \.\.\.ownership \}\)/);
  assert.match(routes, /requests\.map\(serializeFacilityBloodRequest\)/);
  assert.match(routes, /serializeFacilityBloodRequest\(request\)/);
});

test('donor UI uses coarse area and does not render public patient or contact fields', () => {
  const emergencyPage = read(repoRoot, 'lib/emergency_response_page.dart');
  const dashboard = read(repoRoot, 'lib/dashboard.dart');
  assert.match(emergencyPage, /widget\.request\['hubZone'\]/);
  assert.doesNotMatch(emergencyPage, /patientName|contactPhone|attender|Clipboard/);
  assert.match(dashboard, /r\['hubZone'\]/);
  assert.doesNotMatch(dashboard, /r\['hospital'\]/);
});
