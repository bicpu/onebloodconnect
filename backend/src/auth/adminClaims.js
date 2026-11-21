const KNOWN_ROLES = new Set(['donor', 'blood_bank', 'admin']);

function updateAdminRoleClaims(claims, action) {
  if (!['grant', 'revoke'].includes(action)) {
    throw new Error('Action must be grant or revoke');
  }

  const currentRoles = claims.roles === undefined ? [] : claims.roles;
  if (
    !Array.isArray(currentRoles) ||
    currentRoles.some((role) => typeof role !== 'string' || !KNOWN_ROLES.has(role))
  ) {
    throw new Error('Existing roles are malformed or unknown');
  }

  const roles = new Set(currentRoles);
  if (action === 'grant') roles.add('admin');
  else roles.delete('admin');

  const nextClaims = { ...claims };
  if (roles.size > 0) nextClaims.roles = [...roles];
  else delete nextClaims.roles;
  return nextClaims;
}

module.exports = updateAdminRoleClaims;
