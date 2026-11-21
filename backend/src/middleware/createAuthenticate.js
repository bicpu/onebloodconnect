/**
 * Builds Firebase-token authentication middleware around a trusted token
 * verifier. Keeping the verifier injectable lets the authentication behavior
 * be tested without Firebase credentials or a live Firebase project.
 */
function createAuthenticate(verifyIdToken) {
  return async function authenticate(req, res, next) {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ') || !authHeader.slice(7).trim()) {
      return res.status(401).json({ error: 'Missing or invalid Authorization header' });
    }

    const idToken = authHeader.slice(7).trim();

    let decoded;
    try {
      decoded = await verifyIdToken(idToken);
    } catch (err) {
      console.error('[Auth] Token verification failed:', err.message);
      return res.status(401).json({ error: 'Invalid or expired Firebase token' });
    }

    req.uid = decoded.uid;
    req.firebaseUser = decoded;
    return next();
  };
}

module.exports = createAuthenticate;
