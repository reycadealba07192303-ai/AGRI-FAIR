import { sellerService } from '../services/sellerService.js';

function fail(res, err, fallback) {
  const notFound = /not found|invalid seller/i.test(err?.message || '');
  return res.status(notFound ? 404 : 400).json({
    success: false,
    message: err?.message || fallback,
  });
}

export const getSellerProfile = async (req, res) => {
  try {
    const profile = await sellerService.getPublicProfile(Number(req.params.id));
    return res.json({
      success: true,
      message: 'Seller retrieved successfully',
      data: profile,
    });
  } catch (err) {
    return fail(res, err, 'Could not load that seller');
  }
};

export const getSellerProducts = async (req, res) => {
  try {
    const products = await sellerService.getPublicProducts(Number(req.params.id));
    return res.json({
      success: true,
      message: 'Products retrieved successfully',
      data: products,
    });
  } catch (err) {
    return fail(res, err, 'Could not load that seller\'s products');
  }
};
