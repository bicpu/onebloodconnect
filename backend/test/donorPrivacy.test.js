const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  serializeDonorSearchResult,
  serializeDonorRequest,
  serializeBloodRequest,
  serializeRequesterBloodRequest,
  serializeFacilityDonation,
  serializeAdminDonation,
} = require('../src/privacy/donorResponses');

const backendRoot = path.resolve(__dirname, '..');
function source(file) {
  return fs.readFileSync(path.join(backendRoot, file), 'utf8');
}

test('donor search serializer returns only approved public search fields', () => {
  const result = serializeDonorSearchResult({
    _id: 'mongo-id', uid: 'firebase-uid', phone: 'private-phone', email: 'private-email',
    publicRef: 'opaque-ref', fullName: 'Donor', bloodGroup: 'O+', city: 'City',
    donationStream: 'Whole Blood', readyAnyTime: true, healthEligibility: { private: true },
  });
  assert.deepEqual(result, {
    publicRef: 'opaque-ref', fullName: 'Donor', bloodGroup: 'O+', city: 'City',
    donationStream: 'Whole Blood', readyAnyTime: true,
  });
});

test('donor request responses omit donor identifiers and share requester contact only with target donor', () => {
  const record = {
    _id: 'request-id', donorId: 'donor-mongo-id', donorUid: 'donor-firebase-uid',
    requesterUid: 'requester-firebase-uid', requesterPhone: 'requester-phone',
    donorPhone: 'donor-phone', donorEmail: 'donor-email',
    patientName: 'Patient', status: 'pending', donationPhotoUrl: 'proof-photo',
  };
  const requesterView = serializeDonorRequest(record, 'requester-firebase-uid');
  const donorView = serializeDonorRequest(record, 'donor-firebase-uid');

  assert.equal(requesterView._id, 'request-id');
  assert.equal(requesterView.requesterPhone, undefined);
  assert.equal(requesterView.donationPhotoUrl, undefined);
  assert.equal(donorView.requesterPhone, 'requester-phone');
  assert.equal(donorView.donationPhotoUrl, 'proof-photo');
  for (const view of [requesterView, donorView]) {
    assert.equal(view.donorId, undefined);
    assert.equal(view.donorUid, undefined);
    assert.equal(view.requesterUid, undefined);
    assert.equal(view.donorPhone, undefined);
    assert.equal(view.donorEmail, undefined);
  }
});

test('donor-facing blood request response is an explicit minimal allowlist', () => {
  const result = serializeBloodRequest({
    _id: 'request-id', requesterUid: 'requester-uid', targetFacilityUid: 'bank-uid',
    targetFacilityAccountId: 'account-id', targetFacilityDirectoryId: 'directory-id',
    patientName: 'Patient', patientAge: 42, patientGender: 'Other',
    hospital: 'Private Hospital', ward: 'ICU', bedNumber: '15',
    attender: 'Attender', contactPhone: 'private-phone', email: 'private-email',
    attachmentFileName: 'prescription.pdf', facilityReviewComment: 'private note',
    timeline: [{ step: 'received', note: 'private timeline detail' }],
    responses: [{
      _id: 'nested-id', responderUid: 'donor-uid', responderName: 'Donor',
      responderPhone: 'donor-phone', responderBloodGroup: 'O+', unitsCommitted: 1,
    }],
    bloodGroup: 'O+', units: 2, unitsRemaining: 1, component: 'Whole Blood',
    urgency: 'Urgent', hubZone: 'North zone', status: 'received',
    createdAt: 'date', expiresAt: 'expiry', hasResponded: true,
    canDonate: true, hasActiveCommitment: false, isMyActiveCommitment: true,
  }, 'donor-uid');
  assert.deepEqual(Object.keys(result).sort(), [
    '_id', 'bloodGroup', 'canDonate', 'component', 'createdAt', 'expiresAt',
    'hasActiveCommitment', 'hasResponded', 'hubZone', 'isMyActiveCommitment',
    'myUnitsCommitted', 'status', 'units', 'unitsRemaining', 'urgency',
  ].sort());
  assert.equal(result._id, 'request-id'); // Needed for existing respond/withdraw API paths.
  assert.equal(result.myUnitsCommitted, 1);
  assert.equal(result.patientName, undefined);
  assert.equal(result.hospital, undefined);
  assert.equal(result.contactPhone, undefined);
  assert.equal(result.requesterUid, undefined);
  assert.equal(result.targetFacilityAccountId, undefined);
  assert.equal(result.responses, undefined);
});

test('blood request owner view keeps only workflow fields and strips internal identities', () => {
  const result = serializeRequesterBloodRequest({
    _id: 'request-id', requesterUid: 'requester-uid', facilityReviewedBy: 'admin-uid',
    targetFacilityAccountId: 'facility-id', patientName: 'Patient', contactPhone: 'phone',
    bloodGroup: 'O+', hospital: 'Hospital',
    responses: [{ _id: 'nested-id', responderUid: 'donor-uid', responderName: 'Donor', unitsCommitted: 1, respondedAt: 'date' }],
    timeline: [{ _id: 'event-id', step: 'received', time: 'date', note: 'note', uid: 'user-uid' }],
  });
  assert.equal(result.patientName, 'Patient');
  assert.equal(result.contactPhone, 'phone');
  assert.equal(result.requesterUid, undefined);
  assert.equal(result.facilityReviewedBy, undefined);
  assert.equal(result.targetFacilityAccountId, undefined);
  assert.deepEqual(result.responses, [{ responderName: 'Donor', unitsCommitted: 1, respondedAt: 'date' }]);
  assert.deepEqual(result.timeline, [{ step: 'received', time: 'date', note: 'note' }]);
});

test('facility and admin donation serializers omit Firebase donor UIDs', () => {
  const booking = {
    _id: 'booking-id', donorUid: 'firebase-uid', donorName: 'Donor',
    bloodGroup: 'A+', bookingRef: 'booking-ref', status: 'completed',
  };
  assert.equal(serializeFacilityDonation(booking).donorUid, undefined);
  assert.equal(serializeAdminDonation(booking).donorUid, undefined);
});

test('admin donation review retains proof fields while limiting output to its allowlist', () => {
  const result = serializeAdminDonation({
    _id: 'booking-id', donorUid: 'firebase-uid', donorEmail: 'private-email',
    donationPhotoUrl: 'proof-photo', doctorSlipUrl: 'doctor-slip',
    facilityName: 'Facility', facilityPhone: 'facility-phone',
  });
  assert.equal(result.donationPhotoUrl, 'proof-photo');
  assert.equal(result.doctorSlipUrl, 'doctor-slip');
  assert.equal(result.donorUid, undefined);
  assert.equal(result.donorEmail, undefined);
});

test('donor search uses opt-in and explicit allowlist without Mongo ID, UID, phone, or email', () => {
  const routes = source('src/routes/donors.js');
  assert.match(routes, /showToOthers:\s*true/);
  assert.match(routes, /manualEntry:\s*\{\s*\$ne:\s*true\s*\}/);
  assert.match(routes, /publicRef:\s*\{\s*\$type:\s*'string'/);
  assert.match(routes, /_id:\s*0,[\s\S]*publicRef:\s*1,[\s\S]*fullName:\s*1,[\s\S]*bloodGroup:\s*1,[\s\S]*city:\s*1,[\s\S]*donationStream:\s*1,[\s\S]*readyAnyTime:\s*1/);
  assert.match(routes, /donors\.map\(serializeDonorSearchResult\)/);
});

test('contact-by-reference ignores client UIDs and Mongo IDs and rechecks donor opt-in', () => {
  const routes = source('src/routes/donorRequests.js');
  const api = source('../lib/services/api_service.dart');
  const contactPage = fs.readFileSync(path.resolve(backendRoot, '..', 'lib/contact_donor_page.dart'), 'utf8');
  const eligibility = source('src/donors/eligibilityFilter.js');
  assert.match(routes, /donorRef,/);
  assert.match(routes, /publicRef:\s*donorRef,[\s\S]*showToOthers:\s*true,[\s\S]*registered:\s*true,[\s\S]*manualEntry:\s*\{\s*\$ne:\s*true\s*\}/);
  assert.match(routes, /\.\.\.donorEligibilityFilter\(ninetyDaysAgo\)/);
  assert.match(eligibility, /bookingStatus:\s*\{\s*\$in:\s*\[\.\.\.DONOR_BOOKING_STATUSES\]\s*\}/);
  assert.doesNotMatch(routes, /const\s*\{[^}]*donorUid[^}]*\}\s*=\s*req\.body/s);
  assert.doesNotMatch(routes, /const\s*\{[^}]*donorId[^}]*\}\s*=\s*req\.body/s);
  assert.match(api, /required String donorRef/);
  assert.doesNotMatch(api, /'donorUid'\s*:|'donorId'\s*:/);
  assert.match(contactPage, /publicRef/);
  assert.doesNotMatch(contactPage, /donor\['_id'\]|donor\['uid'\]/);
});

test('donor public reference is server-created, immutable, and excluded from profile input fields', () => {
  const model = source('src/models/Donor.js');
  const routes = source('src/routes/donors.js');
  assert.match(model, /publicRef:\s*\{\s*type:\s*String,\s*unique:\s*true,\s*sparse:\s*true,\s*immutable:\s*true,\s*select:\s*false\s*\}/);
  assert.match(routes, /\$setOnInsert:\s*\{[\s\S]*publicRef:\s*randomUUID\(\),[\s\S]*lastDonationDate:\s*null,[\s\S]*lastDonationUnits:\s*null,[\s\S]*coolingEndsAt:\s*null,[\s\S]*hospitalBookingActive:\s*false,[\s\S]*bookingStatus:\s*'ready_to_donate'/);
  assert.doesNotMatch(routes, /const\s*\{[^}]*\bpublicRef\b[^}]*\}\s*=\s*req\.body/s);
  assert.doesNotMatch(routes, /'publicRef'/);
});

test('donor-facing request routes serialize responses and do not enrich volunteer phone numbers', () => {
  const routes = source('src/routes/bloodRequests.js');
  const bankRoutes = source('src/routes/bloodBankAccounts.js');
  const adminRoutes = source('src/routes/admin.js');
  const trackPage = fs.readFileSync(path.resolve(backendRoot, '..', 'lib/track_request_page.dart'), 'utf8');
  const emergencyPage = fs.readFileSync(path.resolve(backendRoot, '..', 'lib/emergency_response_page.dart'), 'utf8');
  assert.match(routes, /serializeBloodRequest\(request, req\.uid\)/);
  assert.match(routes, /enriched\.map\(\(request\) => serializeBloodRequest/);
  assert.doesNotMatch(routes, /responderPhone:\s*donor\?\.phone/);
  assert.doesNotMatch(trackPage, /responderPhone|Clipboard\.setData\(ClipboardData\(text: phone\)\)/);
  assert.match(emergencyPage, /myUnitsCommitted/);
  assert.doesNotMatch(emergencyPage, /contactPhone|_phone|Clipboard/);
  assert.match(bankRoutes, /donations\.map\(serializeFacilityDonation\)/);
  assert.match(bankRoutes, /serializeFacilityDonation\(booking\)/);
  assert.match(adminRoutes, /donations\.map\(serializeAdminDonation\)/);
  assert.match(adminRoutes, /serializeAdminDonation\(booking\)/);
  assert.doesNotMatch(adminRoutes, /uid:\s*u\.uid/);
});
