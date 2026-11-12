const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

/**
 * Initialises the Firebase Admin SDK once.
 * Reads the service account from JSON in the environment or a local file.
 */
function initFirebase() {
  if (admin.apps.length > 0) return; // already initialised

  let serviceAccount;
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (serviceAccountJson) {
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (err) {
      console.error('[Firebase] FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON:', err.message);
      process.exit(1);
    }
  } else {
    const keyPath = path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '');
    if (!process.env.FIREBASE_SERVICE_ACCOUNT_PATH || !fs.existsSync(keyPath)) {
      console.error(
        `[Firebase] Service account file not found at "${keyPath}". ` +
        'Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON.'
      );
      process.exit(1);
    }
    serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log('[Firebase] Admin SDK initialised');
}

module.exports = { admin, initFirebase };
