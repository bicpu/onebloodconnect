async function removeAdminRoleWithRevocation({
  updateClaims,
  revokeRefreshTokens,
  logError = console.error,
  logWarning = console.warn,
}) {
  try {
    await updateClaims();
  } catch (_) {
    logError('Failed to remove the administrator claim; refresh-token revocation was not attempted.');
    throw new Error('Administrator claim removal failed.');
  }

  try {
    await revokeRefreshTokens();
  } catch (_) {
    logError('The administrator claim was removed, but Firebase refresh-token revocation failed.');
    logWarning(
      'WARNING: Previously issued ID tokens may remain valid until expiry. Retry this revoke command and verify the user role and token status. The admin claim was not restored.',
    );
    throw new Error('Administrator revocation is incomplete.');
  }
}

function usage() {
  console.error('Usage: node scripts/manage-admin-role.js <grant|revoke> <FIREBASE_UID>');
  process.exitCode = 1;
}

async function main() {
  require('dotenv').config();
  const { admin, initFirebase } = require('../src/config/firebase');
  const updateAdminRoleClaims = require('../src/auth/adminClaims');

  const [, , action, uid] = process.argv;
  if (!['grant', 'revoke'].includes(action) || !uid || !uid.trim()) {
    usage();
    return;
  }

  initFirebase();
  const auth = admin.auth();
  const user = await auth.getUser(uid.trim());
  const claims = user.customClaims || {};
  let nextClaims;
  try {
    nextClaims = updateAdminRoleClaims(claims, action);
  } catch (err) {
    throw new Error(`User ${uid}: ${err.message}; review claims before changing them.`);
  }

  if (action === 'revoke') {
    // Claims must be removed first; if token revocation then fails, the warning
    // explains the partial state and the process exits unsuccessfully.
    await removeAdminRoleWithRevocation({
      updateClaims: () => auth.setCustomUserClaims(uid.trim(), nextClaims),
      revokeRefreshTokens: () => auth.revokeRefreshTokens(uid.trim()),
      logError: (message) => console.error(`[Admin role provisioning] ${message}`),
      logWarning: (message) => console.warn(message),
    });
  } else {
    await auth.setCustomUserClaims(uid.trim(), nextClaims);
  }

  console.log(`Administrator role ${action === 'grant' ? 'granted to' : 'revoked from'} ${uid.trim()}.`);
  if (action === 'grant') {
    console.log('The user must refresh their Firebase ID token before admin access is available.');
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('[Admin role provisioning]', err.message);
    process.exitCode = 1;
  });
}

module.exports = { removeAdminRoleWithRevocation };
