const { admin } = require('../config/firebase');
const createAuthenticate = require('./createAuthenticate');

/**
 * Express middleware that validates a Firebase ID token sent in the
 * Authorization header as "Bearer <token>".
 *
 * On success it attaches `req.uid` (the Firebase user UID) and
 * `req.firebaseUser` (the full decoded token) so route handlers can
 * use them without repeating the verification logic.
 */
const authenticate = createAuthenticate((idToken) =>
  admin.auth().verifyIdToken(idToken, true),
);

module.exports = authenticate;
