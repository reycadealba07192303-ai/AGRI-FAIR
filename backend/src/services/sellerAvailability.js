import User from '../models/User.js';

/**
 * Whose listings a buyer must not be offered.
 *
 * A seller a Super Admin suspended keeps their products in the database - they
 * come back as they were when the account is reinstated - but nothing of theirs
 * may be browsed, found, added to a cart or ordered in the meantime. Hiding them
 * at read time rather than flipping every product's status means reinstating
 * cannot accidentally relist something the seller had taken down themselves.
 */
export async function suspendedSellerIds() {
  return User.distinct('userId', { role: 'seller', status: 'suspended' });
}

/** A Mongo condition on `createdBy` that leaves suspended sellers out. */
export async function excludeSuspendedSellers() {
  const ids = await suspendedSellerIds();
  return ids.length ? { createdBy: { $nin: ids } } : {};
}

export async function isSellerSuspended(userId) {
  if (userId == null) return false;
  return Boolean(await User.exists({ userId, role: 'seller', status: 'suspended' }));
}
