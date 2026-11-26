function toPlainObject(value) {
  return typeof value?.toObject === 'function' ? value.toObject() : value;
}

const PUBLIC_BLOOD_REQUEST_HUB_ZONES = new Set([
  'JIPMER / Gorimedu',
  'PU Central Campus',
  'MGMCRI',
]);

function serializeDonorSearchResult(donor) {
  return {
    publicRef: donor.publicRef,
    fullName: donor.fullName,
    bloodGroup: donor.bloodGroup,
    city: donor.city,
    donationStream: donor.donationStream,
    readyAnyTime: donor.readyAnyTime,
  };
}

function serializeManualDonor(value) {
  const source = toPlainObject(value);
  return {
    _id: source._id,
    fullName: source.fullName,
    bloodGroup: source.bloodGroup,
    phone: source.phone,
    city: source.city,
    donationStream: source.donationStream,
    readyAnyTime: source.readyAnyTime,
    createdAt: source.createdAt,
  };
}

function hasImage(metadata, legacyValue) {
  return Boolean(metadata?.key || (typeof legacyValue === 'string' && legacyValue));
}

function serializeBooking(value) {
  const source = toPlainObject(value);
  const result = { ...source };
  delete result.donationPhotoUrl;
  delete result.doctorSlipUrl;
  delete result.donationPhoto;
  delete result.doctorSlip;
  result.donationPhotoAvailable = hasImage(source.donationPhoto, source.donationPhotoUrl);
  result.doctorSlipAvailable = hasImage(source.doctorSlip, source.doctorSlipUrl);
  return result;
}

function serializeDonorProfile(value) {
  const source = toPlainObject(value);
  const result = { ...source };
  delete result.profilePhoto;
  result.profilePhotoUrl = '';
  result.profilePhotoAvailable = hasImage(source.profilePhoto, source.profilePhotoUrl);
  return result;
}

function serializeDonorRequest(value, viewerUid) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'requesterName', 'donorName', 'donorBloodGroup',
    'patientName', 'patientAge', 'patientGender', 'bloodGroup', 'units',
    'component', 'urgency', 'hospital', 'ward', 'bedNumber', 'attender',
    'contactPhone', 'status', 'confirmedAt', 'donorNote', 'donatedAt',
    'cancelledBy', 'cancelReason', 'createdAt', 'updatedAt',
  ];
  const result = Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));

  // The requester explicitly supplies their contact details for the recipient.
  if (source.donorUid === viewerUid && source.requesterPhone !== undefined) {
    result.requesterPhone = source.requesterPhone;
  }
  // Donation proofs remain accessible only through their authorized image route.
  if (source.donorUid === viewerUid) {
    result.donationPhotoAvailable = hasImage(source.donationPhoto, source.donationPhotoUrl);
    result.doctorSlipAvailable = hasImage(source.doctorSlip, source.doctorSlipUrl);
  }
  return result;
}

function serializeBloodRequest(value, viewerUid) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'bloodGroup', 'units', 'unitsRemaining', 'component', 'urgency',
    'hubZone', 'status', 'createdAt', 'expiresAt', 'hasResponded', 'canDonate',
    'hasActiveCommitment', 'isMyActiveCommitment',
  ];
  const result = Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));
  // The value originates from the client; only emit known coarse area labels.
  if (result.hubZone !== undefined && !PUBLIC_BLOOD_REQUEST_HUB_ZONES.has(result.hubZone)) {
    result.hubZone = '';
  }
  const ownResponse = (source.responses || []).find((response) =>
    response.responderUid === viewerUid);
  result.hasResponded = source.hasResponded === true || !!ownResponse;
  if (ownResponse) result.myUnitsCommitted = ownResponse.unitsCommitted;
  return result;
}

function serializeRequesterBloodRequest(value) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'patientName', 'patientAge', 'patientGender', 'bloodGroup', 'units',
    'unitsRemaining', 'component', 'urgency', 'hospital', 'ward', 'bedNumber',
    'hubZone', 'attender', 'contactPhone', 'emergencyPushEnabled', 'notifyNss',
    'status', 'targetFacilityName', 'targetFacilityAddress', 'targetFacilityPhone',
    'facilityReviewStatus', 'facilityReviewComment', 'facilityReviewedAt',
    'timeline', 'createdAt', 'updatedAt', 'expiresAt',
  ];
  const result = Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));
  if (Array.isArray(source.responses)) {
    result.responses = source.responses.map((response) => ({
      responderName: response.responderName || '',
      unitsCommitted: response.unitsCommitted,
      respondedAt: response.respondedAt,
    }));
  }
  if (Array.isArray(source.timeline)) {
    result.timeline = source.timeline.map((event) => ({
      step: event.step,
      time: event.time,
      note: event.note,
    }));
  }
  return result;
}

function serializeFacilityBloodRequest(value) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'patientName', 'patientAge', 'patientGender', 'bloodGroup', 'units',
    'unitsRemaining', 'component', 'urgency', 'hospital', 'ward', 'bedNumber',
    'hubZone', 'attender', 'contactPhone', 'status', 'facilityReviewStatus',
    'facilityReviewComment', 'facilityReviewedAt', 'createdAt', 'expiresAt',
  ];
  return Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));
}

function serializeFacilityDonation(value) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'donorName', 'bloodGroup', 'component', 'bookingRef', 'status',
    'donatedAt', 'proofStatus', 'createdAt',
  ];
  return Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));
}

function serializeAdminDonation(value) {
  const source = toPlainObject(value);
  const fields = [
    '_id', 'donorName', 'bloodGroup', 'component', 'bookingRef', 'status',
    'units', 'facilityName', 'facilityAddress', 'facilityPhone', 'donatedAt',
    'coolingEndsAt', 'proofStatus',
    'verificationNote', 'verifiedAt', 'certificateNo', 'appealReason',
    'createdAt', 'updatedAt',
  ];
  const result = Object.fromEntries(fields
    .filter((field) => source[field] !== undefined)
    .map((field) => [field, source[field]]));
  result.donationPhotoAvailable = hasImage(source.donationPhoto, source.donationPhotoUrl);
  result.doctorSlipAvailable = hasImage(source.doctorSlip, source.doctorSlipUrl);
  return result;
}

module.exports = {
  serializeDonorSearchResult,
  serializeManualDonor,
  serializeBooking,
  serializeDonorProfile,
  serializeDonorRequest,
  serializeBloodRequest,
  serializeRequesterBloodRequest,
  serializeFacilityBloodRequest,
  serializeFacilityDonation,
  serializeAdminDonation,
};
