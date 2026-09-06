import Cart from '../models/Cart.js';

export const getOrCreate = async (buyerUserId) => {
  const found = await Cart.findOne({ buyerUserId });
  if (found) return found;
  return Cart.create({ buyerUserId, items: [] });
};

export const save = async (cart) => cart.save();

export const clear = async (buyerUserId) =>
  Cart.findOneAndUpdate({ buyerUserId }, { items: [] }, { returnDocument: 'after' });
