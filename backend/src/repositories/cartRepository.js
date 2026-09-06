import Cart from '../models/Cart.js';

export const getOrCreate = async (buyerUserId) => {
  const found = await Cart.findOne({ buyerUserId });
  if (found) return found;
  return Cart.create({ buyerUserId, items: [] });
};

export const save = async (cart) => cart.save();

/**
 * Upserts, because clearing a cart that was never created returned null and
 * the caller then read `.items` off it. Emptying nothing should answer with an
 * empty cart, not a crash.
 */
export const clear = async (buyerUserId) =>
  Cart.findOneAndUpdate(
    { buyerUserId },
    { items: [] },
    { returnDocument: 'after', upsert: true, setDefaultsOnInsert: true },
  );
