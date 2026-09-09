import API from './authApi';

/**
 * Delivery people.
 *
 * The seller's half adds them and says who carries what; the rider's half is
 * their own queue. A rider sees only orders assigned to them — working for the
 * seller is not enough on its own to open one.
 */

// ---- The seller's side ----
export const fetchRiders = () => API.get('/riders');

/** name + email is the whole form. The rider picks their own password later. */
export const addRider = (data) => API.post('/riders', data);

export const resendRiderCode = (riderUserId) =>
  API.post(`/riders/${riderUserId}/resend-code`);

/** Toggles between active and suspended — never deletes. Their name is on
 *  delivered orders, and removing the account would orphan those. */
export const toggleRiderSuspension = (riderUserId) =>
  API.put(`/riders/${riderUserId}/suspend`);

/** Pass null to take the rider off the order again. */
export const assignRider = (orderId, riderUserId) =>
  API.put(`/riders/assign/${orderId}`, { riderUserId });

// ---- The rider's side ----
export const fetchMyDeliveries = () => API.get('/riders/me/deliveries');

export const pushMyLocation = (orderId, { lat, lng, etaMinutes }) =>
  API.put(`/riders/me/deliveries/${orderId}/location`, { lat, lng, etaMinutes });

export const uploadDeliveryProof = (orderId, file, note) => {
  const fd = new FormData();
  fd.append('proof', file);
  if (note) fd.append('note', note);

  return API.post(`/riders/me/deliveries/${orderId}/proof`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// ---- Finishing an account somebody else created ----

/**
 * Step one: is there a delivery account for this email, and send the code.
 *
 * Answers honestly whether one exists — a rider who mistypes the address their
 * shop gave them should be told, not left waiting for an email that was never
 * coming.
 */
export const startDeliverySetup = (email) =>
  API.post('/auth/delivery/start', { email });

export const activateAccount = ({ email, code, password }) =>
  API.post('/auth/activate', { email, code, password });

export const resendActivationCode = (email) =>
  API.post('/auth/resend-verification', { email });
