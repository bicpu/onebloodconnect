const { admin } = require('../config/firebase');

/**
 * Express middleware that validates a Firebase ID token sent in the
 * Authorization header as "Bearer <token>".
 *
 * On success it attaches `req.uid` (the Firebase user UID) and
 * `req.firebaseUser` (the full decoded token) so route handlers can
 * use them without repeating the verification logic.
 */
async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }

  const idToken = authHeader.split('Bearer ')[1];

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.uid          = decoded.uid;
    req.firebaseUser = decoded;
    next();
  } catch (err) {
    console.error('[Auth] Token verification failed:', err.message);
    return res.status(401).json({ error: 'Invalid or expired Firebase token' });
  }
}

module.exports = authenticate;
