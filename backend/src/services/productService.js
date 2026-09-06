// src/services/productService.js
import { productRepository } from '../repositories/productRepository.js';
import { getRatingMapForProducts } from '../repositories/reviewRepository.js';
import { sellerService } from './sellerService.js';

const NO_RATING = { averageRating: 0, reviewCount: 0 };

/**
 * Ratings live in the Review collection, but every client wants them on the
 * product itself. Merging here means the mobile app and the web read the same
 * shape and neither has to make a second call per product.
 */
async function withRatings(products) {
  const list = Array.isArray(products) ? products : [products];
  const ratings = await getRatingMapForProducts(list.map((p) => p._id));

  const merged = list.map((product) => ({
    ...(product.toObject ? product.toObject() : product),
    ...(ratings.get(String(product._id)) || NO_RATING),
  }));

  return Array.isArray(products) ? merged : merged[0];
}

export const productService = {

  // Get all products
  async getAllProducts(page = 1, limit = 10, filters = {}) {
    if (page < 1 || limit < 1) {
      throw new Error('Page and limit must be positive numbers');
    }

    const result = await productRepository.getAllProducts(page, limit, filters);
    return { ...result, products: await withRatings(result.products) };
  },

  // Get product by ID
  async getProductById(id) {
    if (!id) {
      throw new Error('Product ID is required');
    }

    const product = await productRepository.getProductById(id);
    if (!product) {
      throw new Error('Product not found');
    }

    const withRating = await withRatings(product);

    // The detail screen shows a seller card straight away, so a small summary
    // rides along rather than costing a second round trip. Tapping it fetches
    // the full profile from /sellers/:id.
    try {
      const seller = await sellerService.getPublicProfile(product.createdBy);
      withRating.seller = {
        id: seller.id,
        name: seller.name,
        avatarUrl: seller.avatarUrl,
        businessName: seller.businessName,
        isVerified: seller.isVerified,
        averageRating: seller.averageRating,
        productCount: seller.productCount,
      };
    } catch {
      // A product whose seller was removed is still a product worth showing.
      withRating.seller = null;
    }

    return withRating;
  },

  // Create new product
  async createProduct(productData) {
    const { name, variety, category, price, stock } = productData;
    const riceVariety = variety || category;

    if (!name || !riceVariety || price === undefined || stock === undefined) {
      throw new Error('Name, variety, price, and stock are required');
    }

    if (price < 0) {
      throw new Error('Price cannot be negative');
    }

    if (stock < 0) {
      throw new Error('Stock cannot be negative');
    }

    return await productRepository.createProduct({ ...productData, variety: riceVariety });
  },

  // Update product
  async updateProduct(id, updateData) {
    if (!id) {
      throw new Error('Product ID is required');
    }

    // Validate price if provided
    if (updateData.price !== undefined && updateData.price < 0) {
      throw new Error('Price cannot be negative');
    }

    // Validate stock if provided
    if (updateData.stock !== undefined && updateData.stock < 0) {
      throw new Error('Stock cannot be negative');
    }

    const product = await productRepository.updateProduct(id, updateData);
    if (!product) {
      throw new Error('Product not found');
    }

    return product;
  },

  // Delete product
  async deleteProduct(id) {
    if (!id) {
      throw new Error('Product ID is required');
    }

    const product = await productRepository.deleteProduct(id);
    if (!product) {
      throw new Error('Product not found');
    }

    return product;
  },

  // Get products by category
  async getProductsByCategory(category) {
    if (!category) {
      throw new Error('Category is required');
    }

    return await withRatings(await productRepository.getProductsByCategory(category));
  },

  // Get low stock products
  async getLowStockProducts(threshold = 50) {
    return await productRepository.getLowStockProducts(threshold);
  },

  // Get out of stock products
  async getOutOfStockProducts() {
    return await productRepository.getOutOfStockProducts();
  },

  // Update product stock
  async updateStock(id, quantity) {
    if (!id) {
      throw new Error('Product ID is required');
    }

    if (typeof quantity !== 'number') {
      throw new Error('Quantity must be a number');
    }

    return await productRepository.updateStock(id, quantity);
  },

  // Search products
  async searchProducts(searchTerm) {
    if (!searchTerm || searchTerm.trim() === '') {
      throw new Error('Search term is required');
    }

    return await withRatings(await productRepository.searchProducts(searchTerm));
  }
};
