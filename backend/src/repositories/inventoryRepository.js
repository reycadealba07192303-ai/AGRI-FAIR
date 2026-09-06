import StockMovement from '../models/StockMovement.js';
import Product from '../models/Product.js';

export const logMovement = async ({ sellerId, productId, productName, type, quantity, resultingStock, note }) => {
  return await StockMovement.create({ sellerId, productId, productName, type, quantity, resultingStock, note });
};

export const findMovementsByProduct = async (productId, sellerId) => {
  return await StockMovement.find({ productId, sellerId }).sort({ createdAt: -1 });
};

export const getInventorySummary = async (sellerId) => {
  const products = await Product.find({ createdBy: sellerId }).sort({ name: 1 });

  const lastRestocks = await StockMovement.aggregate([
    { $match: { sellerId, type: 'RESTOCK' } },
    { $group: { _id: '$productId', lastRestockedAt: { $max: '$createdAt' } } },
  ]);
  const lastRestockByProduct = new Map(lastRestocks.map((r) => [r._id.toString(), r.lastRestockedAt]));

  let totalStock = 0;
  let stockValue = 0;
  let lowStockCount = 0;
  let outOfStockCount = 0;

  const productRows = products.map((p) => {
    totalStock += p.stock;
    stockValue += p.stock * p.price;
    if (p.stock <= 0) outOfStockCount += 1;
    else if (p.stock <= p.lowStockThreshold) lowStockCount += 1;

    return {
      _id: p._id,
      name: p.name,
      stock: p.stock,
      lowStockThreshold: p.lowStockThreshold,
      price: p.price,
      status: p.status,
      lastRestockedAt: lastRestockByProduct.get(p._id.toString()) || null,
    };
  });

  return {
    totalStock,
    stockValue,
    lowStockCount,
    outOfStockCount,
    productCount: products.length,
    products: productRows,
  };
};
