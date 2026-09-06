// src/controllers/productController.js
import { productService } from '../services/productService.js';

export const getAllProducts = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const filters = {
      // `variety` is the schema's own word; `category` stays accepted so the
      // mobile app's wording keeps working.
      variety: req.query.variety || req.query.category,
      status: req.query.status,
      search: req.query.search
    };

    const result = await productService.getAllProducts(page, limit, filters);

    res.json({
      success: true,
      message: 'Products retrieved successfully',
      data: result.products,
      pagination: result.pagination
    });
  } catch (err) {
    next(err);
  }
};

export const getProductById = async (req, res, next) => {
  try {
    const product = await productService.getProductById(req.params.id);

    res.json({
      success: true,
      message: 'Product retrieved successfully',
      data: product
    });
  } catch (err) {
    next(err);
  }
};

export const createProduct = async (req, res, next) => {
  try {
    const product = await productService.createProduct(req.body);

    res.status(201).json({
      success: true,
      message: 'Product created successfully',
      data: product
    });
  } catch (err) {
    next(err);
  }
};

export const updateProduct = async (req, res, next) => {
  try {
    const product = await productService.updateProduct(req.params.id, req.body);

    res.json({
      success: true,
      message: 'Product updated successfully',
      data: product
    });
  } catch (err) {
    next(err);
  }
};

export const deleteProduct = async (req, res, next) => {
  try {
    const product = await productService.deleteProduct(req.params.id);

    res.json({
      success: true,
      message: 'Product deleted successfully',
      data: product
    });
  } catch (err) {
    next(err);
  }
};

export const getProductsByCategory = async (req, res, next) => {
  try {
    const { category } = req.params;
    const products = await productService.getProductsByCategory(category);

    res.json({
      success: true,
      message: `Products in ${category} retrieved successfully`,
      data: products
    });
  } catch (err) {
    next(err);
  }
};

export const getLowStockProducts = async (req, res, next) => {
  try {
    const threshold = parseInt(req.query.threshold) || 50;
    const products = await productService.getLowStockProducts(threshold);

    res.json({
      success: true,
      message: 'Low stock products retrieved successfully',
      data: products
    });
  } catch (err) {
    next(err);
  }
};

export const getOutOfStockProducts = async (req, res, next) => {
  try {
    const products = await productService.getOutOfStockProducts();

    res.json({
      success: true,
      message: 'Out of stock products retrieved successfully',
      data: products
    });
  } catch (err) {
    next(err);
  }
};

export const updateStock = async (req, res, next) => {
  try {
    const { quantity } = req.body;

    if (quantity === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Quantity is required'
      });
    }

    const product = await productService.updateStock(req.params.id, quantity);

    res.json({
      success: true,
      message: 'Product stock updated successfully',
      data: product
    });
  } catch (err) {
    next(err);
  }
};

export const searchProducts = async (req, res, next) => {
  try {
    const { q } = req.query;

    if (!q) {
      return res.status(400).json({
        success: false,
        message: 'Search query is required'
      });
    }

    const products = await productService.searchProducts(q);

    res.json({
      success: true,
      message: 'Products found',
      data: products
    });
  } catch (err) {
    next(err);
  }
};
