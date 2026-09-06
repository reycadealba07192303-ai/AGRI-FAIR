/** Role → default dashboard path */
export function getHomePath(role) {
  if (role === 'superadmin') return '/superadmin';
  if (role === 'seller') return '/client';
  return '/';
}

export function getSessionUser() {
  try {
    return JSON.parse(sessionStorage.getItem('user') || 'null');
  } catch {
    return null;
  }
}

export function clearSession() {
  sessionStorage.removeItem('token');
  sessionStorage.removeItem('user');
  sessionStorage.removeItem('userSession');
  sessionStorage.removeItem('isLoggedIn');
}
