const { facilityOwnershipFilter } = require('../facilities/facilitySelection');

function createRequireVerifiedBloodBank(findAccount) {
  const loadAccount = findAccount || ((uid) => {
    const BloodBankAccount = require('../models/BloodBankAccount');
    return BloodBankAccount.findOne({ uid }).lean();
  });
  return async function requireVerifiedBloodBank(req, res, next) {
    try {
      const account = await loadAccount(req.uid);
      if (!account) {
        return res.status(403).json({ error: 'bank_account_not_found' });
      }
      if (account.isVerified !== true) {
        return res.status(403).json({ error: 'bank_not_verified' });
      }
      if (account.isActive !== true) {
        return res.status(403).json({ error: 'bank_inactive' });
      }
      if (!facilityOwnershipFilter('facilityAccountId', account)) {
        return res.status(403).json({ error: 'bank_ownership_unavailable' });
      }

      req.bankAccount = account;
      return next();
    } catch (err) {
      console.error('[BloodBank authorization] Account status lookup failed:', err.message);
      return res.status(500).json({ error: 'bank_status_unavailable' });
    }
  };
}

module.exports = createRequireVerifiedBloodBank();
module.exports.createRequireVerifiedBloodBank = createRequireVerifiedBloodBank;
