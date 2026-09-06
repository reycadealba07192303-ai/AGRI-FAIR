import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import '../widgets/review_overview.dart';
import '../widgets/seller_card.dart';
import 'cart_screen.dart';
import 'product_reviews_screen.dart';
import 'seller_profile_screen.dart';

/// One listing, loaded by id.
///
/// Taking an id rather than a Product means every route in - the home grid, a
/// seller's shop, a notification - lands on the same fresh copy, with stock
/// and price as they are now instead of whatever the last screen cached.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  ReviewSummary _reviews = ReviewSummary.empty;
  String? _error;
  bool _loading = true;

  int _tierIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // The reviews are part of deciding whether to buy, so they arrive with
      // the product rather than after a second wait further down the page.
      final results = await Future.wait([
        ProductService.instance.byId(widget.productId),
        ReviewService.instance
            .forProduct(widget.productId)
            // A product still reads fine without its reviews; losing the whole
            // page because they failed would be the worse trade.
            .catchError((_) => ReviewSummary.empty),
      ]);

      final product = results[0] as Product;
      if (!mounted) return;

      setState(() {
        _reviews = results[1] as ReviewSummary;
        _product = product;
        // Start on the second tier where there is one: the smallest bag is
        // rarely what someone buying a sack of rice actually wants.
        _tierIndex = product.sellableTiers.length > 1 ? 1 : 0;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  WeightTier get _tier => _product!.sellableTiers[_tierIndex];
  double get _lineTotal => _product!.priceFor(_tier) * _quantity;

  void _addToCart({required bool thenOpenCart}) {
    final product = _product!;
    CartModel.of(context).addItem(product, _tier, _quantity);

    if (thenOpenCart) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${_tier.label} × $_quantity added to your cart'),
        ),
      );
  }

  void _openSeller() {
    final seller = _product?.seller;
    if (seller == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerId: seller.id,
          initialName: seller.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const _LoadingBody()
          : _error != null
              ? SafeArea(
                  child: Column(
                    children: [
                      _floatingBar(),
                      Expanded(
                        child: ClayEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Could not load this product',
                          message: _error!,
                          actionLabel: 'Try again',
                          onAction: _load,
                        ),
                      ),
                    ],
                  ),
                )
              : _body(),
      bottomNavigationBar: _product == null ? null : _buyBar(),
    );
  }

  Widget _body() {
    final product = _product!;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryMedium,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero(product)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleRow(product),
                  const SizedBox(height: 20),
                  _weightPicker(product),
                  const SizedBox(height: 16),
                  _quantityRow(),

                  // The seller sits between the price and the reviews: by here
                  // the buyer knows the cost and is deciding whether to trust
                  // whoever is selling it.
                  if (product.seller != null) ...[
                    const SizedBox(height: 22),
                    const _SectionHeading('Sold by'),
                    const SizedBox(height: 10),
                    SellerCard(seller: product.seller!, onTap: _openSeller),
                  ],

                  const SizedBox(height: 22),
                  const _SectionHeading('What buyers said'),
                  const SizedBox(height: 10),
                  ReviewOverview(
                    summary: _reviews,
                    onSeeAll: _reviews.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductReviewsScreen(
                                  productName: product.name,
                                ),
                              ),
                            ),
                  ),

                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const _SectionHeading('About this rice'),
                    const SizedBox(height: 10),
                    ClayCard(
                      child: Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textBody,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(Product product) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: product.primaryImageUrl.isEmpty
              ? Container(
                  color: AppColors.surfaceSunken,
                  child: const Icon(
                    Icons.rice_bowl_outlined,
                    size: 64,
                    color: AppColors.primaryLight,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: product.primaryImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surfaceSunken,
                    child: const Icon(
                      Icons.rice_bowl_outlined,
                      size: 64,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  placeholder: (_, _) => Container(color: AppColors.surfaceSunken),
                ),
        ),
        // The page curves up over the photo, the way a clay surface would be
        // pressed onto it.
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          child: Container(
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
          ),
        ),
        _floatingBar(),
        if (!product.inStock)
          const Positioned(
            left: 20,
            bottom: 44,
            child: ClayBadge(
              label: 'Out of stock',
              icon: Icons.remove_shopping_cart_rounded,
              color: AppColors.error,
            ),
          )
        else if (product.soldCount >= 100)
          Positioned(
            left: 20,
            bottom: 44,
            child: ClayBadge(
              label: 'Best Seller',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.primaryMedium,
            ),
          ),
      ],
    );
  }

  Widget _floatingBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ClayIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AnimatedBuilder(
              animation: CartModel.of(context),
              builder: (context, _) => ClayIconButton(
                icon: Icons.shopping_cart_rounded,
                badge: CartModel.of(context).totalCount,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleRow(Product product) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: AppColors.textDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.variety,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 19, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  product.averageRating > 0
                      ? product.averageRating.toString()
                      : 'New',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              product.soldCount > 0 ? '${product.soldCount} sold' : 'No sales yet',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _weightPicker(Product product) {
    final tiers = product.sellableTiers;
    final hasDiscount = tiers.any((t) => t.discountPercent > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Select weight'),
        if (hasDiscount) ...[
          const SizedBox(height: 4),
          const Text(
            'Larger bags include a bulk discount',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tiers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => ClayChip(
              label: tiers[i].label,
              sublabel: '₱${product.priceFor(tiers[i]).toStringAsFixed(0)}',
              selected: i == _tierIndex,
              onTap: () => setState(() => _tierIndex = i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quantityRow() {
    return Row(
      children: [
        const Text(
          'Quantity',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        _StepperButton(
          icon: Icons.remove_rounded,
          onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
        ),
        SizedBox(
          width: 46,
          child: Text(
            '$_quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          onTap: () => setState(() => _quantity++),
        ),
      ],
    );
  }

  Widget _buyBar() {
    final product = _product!;
    final canBuy = product.inStock;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F667A6C),
            offset: Offset(0, -6),
            blurRadius: 18,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      '₱${_lineTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_tier.label} × $_quantity',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClayButton(
                    label: 'Add to Cart',
                    filled: false,
                    onPressed: canBuy ? () => _addToCart(thenOpenCart: false) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClayButton(
                    label: 'Buy Now',
                    onPressed: canBuy ? () => _addToCart(thenOpenCart: true) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.textDark,
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: ClayCard(
        onTap: onTap,
        radius: AppRadius.pill,
        padding: EdgeInsets.zero,
        shadows: AppShadows.subtle,
        child: SizedBox(
          height: 38,
          width: 38,
          child: Icon(icon, size: 18, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        ClaySkeleton(height: 300, radius: 0),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 22, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClaySkeleton(height: 28, width: 220),
              SizedBox(height: 10),
              ClaySkeleton(height: 16, width: 120),
              SizedBox(height: 26),
              ClaySkeleton(height: 68, radius: AppRadius.md),
              SizedBox(height: 22),
              ClaySkeleton(height: 74, radius: AppRadius.lg),
              SizedBox(height: 16),
              ClaySkeleton(height: 74, radius: AppRadius.lg),
            ],
          ),
        ),
      ],
    );
  }
}
