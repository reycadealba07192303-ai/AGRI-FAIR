// src/repositories/productRepository.js
import Product from '../models/Product.js';

export const productRepository = {

  // Get all products with pagination and filtering
  async getAllProducts(page = 1, limit = 10, filters = {}) {
    const skip = (page - 1) * limit;
    const query = {};

    // Apply filters
    // The schema field is `variety`; accepting `category` too keeps the mobile
    // app's own wording working without a second name in the database.
    const variety = filters.variety || filters.category;
    if (variety) {
      query.variety = variety;
    }
    if (filters.status) {
      query.status = filters.status;
    }
    if (filters.search) {
      query.name = { $regex: filters.search, $options: 'i' };
    }

    const products = await Product.find(query)
      .skip(skip)
      .limit(limit)
      .sort({ createdAt: -1 });

    const total = await Product.countDocuments(query);

    return {
      products,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit)
      }
    };
  },

  // Get product by ID
  async getProductById(id) {
    return await Product.findById(id);
  },

  // Create new product
  async createProduct(productData) {
    const product = new Product(productData);
    return await product.save();
  },

  // Update product
  async updateProduct(id, updateData) {
    return await Product.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    );
  },

  // Delete product
  async deleteProduct(id) {
    return await Product.findByIdAndDelete(id);
  },

  // Get products by rice variety
  async getProductsByCategory(variety) {
    return await Product.find({ variety }).sort({ createdAt: -1 });
  },

  // Get low stock products
  async getLowStockProducts(threshold = 50) {
    return await Product.find({ stock: { $lt: threshold, $gt: 0 } });
  },

  // Get out of stock products
  async getOutOfStockProducts() {
    return await Product.find({ stock: 0 });
  },

  // Update product stock
  async updateStock(id, quantity) {
    const product = await Product.findById(id);
    if (!product) {
      throw new Error('Product not found');
    }

    product.stock += quantity;
    if (product.stock < 0) {
      throw new Error('Insufficient stock');
    }

    return await product.save();
  },

  // Search products
  async searchProducts(searchTerm) {
    return await Product.find({
      $or: [
        { name: { $regex: searchTerm, $options: 'i' } },
        { description: { $regex: searchTerm, $options: 'i' } }
      ]
    });
  }
};
