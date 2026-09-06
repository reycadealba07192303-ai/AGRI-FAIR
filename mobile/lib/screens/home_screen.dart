import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../models/product.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// The storefront: what is for sale right now, from the database.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  List<Product> _products = const [];
  String _variety = RiceVariety.all.value;
  String? _error;
  bool _loading = true;

  /// Typing sends one request when the person stops, not one per keystroke.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final term = _searchController.text.trim();
      final products = term.isEmpty
          ? await ProductService.instance.list(variety: _variety)
          : await ProductService.instance.search(term);

      if (!mounted) return;
      setState(() {
        _products = products;
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

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _selectVariety(String value) {
    if (_variety == value) return;
    setState(() => _variety = value);
    // A filter and a search term answer different questions; picking a variety
    // clears the box rather than quietly combining the two.
    _searchController.clear();
    _load();
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryMedium,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _searchBar()),
              SliverToBoxAdapter(child: _varietyRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              _grid(),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final user = UserModel.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kumusta, ${user.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Find your rice',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
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
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: 'Search rice',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 21,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
        ),
      ),
    );
  }

  Widget _varietyRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: RiceVariety.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (context, i) {
            final variety = RiceVariety.values[i];
            return ClayChip(
              label: variety.label,
              selected: _variety == variety.value,
              onTap: () => _selectVariety(variety.value),
            );
          },
        ),
      ),
    );
  }

  Widget _grid() {
    if (_loading) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: ClaySkeleton(height: 210, radius: AppRadius.lg)),
                  SizedBox(width: 14),
                  Expanded(child: ClaySkeleton(height: 210, radius: AppRadius.lg)),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: ClaySkeleton(height: 210, radius: AppRadius.lg)),
                  SizedBox(width: 14),
                  Expanded(child: ClaySkeleton(height: 210, radius: AppRadius.lg)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ClayEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Cannot reach the shop',
          message: _error!,
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }

    if (_products.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;

      return SliverFillRemaining(
        hasScrollBody: false,
        child: ClayEmptyState(
          icon: searching ? Icons.search_off_rounded : Icons.storefront_outlined,
          title: searching ? 'No rice matched' : 'Nothing here yet',
          message: searching
              ? 'Try a different word, or clear the search to see everything.'
              : 'No seller has listed rice of this kind yet. Check another variety.',
          actionLabel: searching ? 'Clear search' : null,
          onAction: searching
              ? () {
                  _searchController.clear();
                  _load();
                }
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ProductTile(
            product: _products[i],
            onTap: () => _openProduct(_products[i]),
          ),
          childCount: _products.length,
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      shadows: AppShadows.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: product.primaryImageUrl.isEmpty
                      ? Container(
                          color: AppColors.surfaceSunken,
                          child: const Icon(
                            Icons.rice_bowl_outlined,
                            size: 34,
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
                              size: 34,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          placeholder: (_, _) =>
                              Container(color: AppColors.surfaceSunken),
                        ),
                ),
                if (!product.inStock)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: ClayBadge(
                      label: 'Out of stock',
                      color: AppColors.error,
                      compact: true,
                    ),
                  )
                else if (product.soldCount >= 100)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: ClayBadge(label: 'Best Seller', compact: true),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      product.averageRating > 0
                          ? '${product.averageRating}'
                          : 'New',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.soldCount > 0) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '· ${product.soldCount} sold',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '₱${product.startingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryMedium,
                    letterSpacing: -0.4,
                  ),
                ),
                const Text(
                  'per kilo',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
