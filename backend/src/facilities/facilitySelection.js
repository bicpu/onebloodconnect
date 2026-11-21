const OBJECT_ID_PATTERN = /^[a-f\d]{24}$/i;
const FACILITY_REF_PATTERN = /^[a-f\d]{8}-[a-f\d]{4}-4[a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/i;

function isObjectId(value) {
  return OBJECT_ID_PATTERN.test(String(value || ''));
}

class FacilitySelectionError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

function createFacilityResolver({ findAccountByRef, findDirectoryById }) {
  return async function resolveFacilitySelection({ facilityRef, directoryId }) {
    const hasAccountRef = typeof facilityRef === 'string' && facilityRef.trim() !== '';
    const hasDirectoryId = typeof directoryId === 'string' && directoryId.trim() !== '';
    if (hasAccountRef === hasDirectoryId) {
      throw new FacilitySelectionError(400, 'one_facility_reference_required');
    }

    if (hasAccountRef) {
      const ref = facilityRef.trim();
      if (!FACILITY_REF_PATTERN.test(ref)) {
        throw new FacilitySelectionError(400, 'invalid_facility_reference');
      }
      const matches = await findAccountByRef(ref);
      const accounts = Array.isArray(matches) ? matches : (matches ? [matches] : []);
      if (accounts.length > 1) {
        throw new FacilitySelectionError(409, 'facility_reference_ambiguous');
      }
      const account = accounts[0];
      if (!account || account.isVerified !== true || account.isActive !== true) {
        throw new FacilitySelectionError(404, 'facility_unavailable');
      }
      if (!isObjectId(account._id)) {
        throw new FacilitySelectionError(403, 'facility_ownership_unavailable');
      }
      return {
        facilityAccountId: account._id,
        facilityDirectoryId: undefined,
        facilityName: account.name,
        facilityAddress: account.address || '',
        facilityCity: account.city || '',
        facilityPhone: account.phone || '',
      };
    }

    const id = directoryId.trim();
    if (!isObjectId(id)) {
      throw new FacilitySelectionError(400, 'invalid_facility_reference');
    }
    const directory = await findDirectoryById(id);
    if (!directory || directory.isVerified !== true || !isObjectId(directory._id)) {
      throw new FacilitySelectionError(404, 'facility_unavailable');
    }
    return {
      facilityAccountId: undefined,
      facilityDirectoryId: directory._id,
      facilityName: directory.name,
      facilityAddress: directory.address || '',
      facilityCity: directory.city || '',
      facilityPhone: directory.phone || '',
    };
  };
}

function facilityOwnershipFilter(field, account) {
  const id = String(account?._id || '');
  if (!isObjectId(id)) return null;
  return { [field]: account._id };
}

function hasFacilityOwnership(record, field, account) {
  const filter = facilityOwnershipFilter(field, account);
  return !!filter && String(record?.[field] || '') === String(filter[field]);
}

module.exports = {
  FacilitySelectionError,
  createFacilityResolver,
  facilityOwnershipFilter,
  hasFacilityOwnership,
  isObjectId,
};
