const KNOWN_ROLES = new Set(['donor', 'blood_bank', 'admin']);

/**
 * Requires at least one role from the verified Firebase ID token's `roles`
 * custom claim. Role data from request parameters, headers, or body is ignored.
 */
function authorizeRoles(...requiredRoles) {
  if (
    requiredRoles.length === 0 ||
    requiredRoles.some((role) => !KNOWN_ROLES.has(role))
  ) {
    throw new Error('authorizeRoles requires one or more known roles');
  }

  return function checkRoles(req, res, next) {
    const roles = req.firebaseUser?.roles;
    if (
      !Array.isArray(roles) ||
      roles.length === 0 ||
      roles.some((role) => typeof role !== 'string' || !KNOWN_ROLES.has(role))
    ) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!requiredRoles.some((role) => roles.includes(role))) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    return next();
  };
}

module.exports = authorizeRoles;
