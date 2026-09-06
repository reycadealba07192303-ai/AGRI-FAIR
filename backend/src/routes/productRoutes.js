// src/routes/productRoutes.js
import express from 'express';
import { protect, authorizeRoles } from '../middleware/authMiddleware.js';
import {
  getAllProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
  getProductsByCategory,
  getLowStockProducts,
  getOutOfStockProducts,
  updateStock,
  searchProducts
} from '../controllers/productController.js';

const router = express.Router();

// ---- Public: browsing is open, so the buyer app can list before sign-in ----
router.get('/', getAllProducts);                           // GET /api/products
router.get('/search', searchProducts);                     // GET /api/products/search?q=term
router.get('/category/:category', getProductsByCategory); // GET /api/products/category/:category
router.get('/stock/low', getLowStockProducts);             // GET /api/products/stock/low
router.get('/stock/out', getOutOfStockProducts);           // GET /api/products/stock/out
router.get('/:id', getProductById);                        // GET /api/products/:id
// ---- Writes require a signed-in seller or super admin ----
// These were open to the internet: anyone could create or delete any product.
const canWrite = [protect, authorizeRoles('seller', 'superadmin')];

router.post('/', canWrite, createProduct);                 // POST /api/products
router.put('/:id', canWrite, updateProduct);               // PUT /api/products/:id
router.delete('/:id', canWrite, deleteProduct);            // DELETE /api/products/:id
router.patch('/:id/stock', canWrite, updateStock);         // PATCH /api/products/:id/stock

export default router;
