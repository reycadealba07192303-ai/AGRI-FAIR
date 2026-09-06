import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/seller.dart';
import '../services/api_client.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'seller_profile_screen.dart';

/// The shop directory: who is selling, before what they sell.
///
/// Home answers "what rice is there"; this answers "who do I buy from". A
/// buyer who liked a sack wants that farm again, and hunting the whole catalog
/// for it is the long way round.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchController = TextEditingController();

  List<ShopSummary> _shops = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shops = await SellerService.instance.shops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
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

  /// Filtered here rather than on the server: the directory is small, and a
  /// round trip per keystroke would cost more than the list is long.
  List<ShopSummary> get _visible {
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return _shops;

    return _shops.where((shop) {
      return shop.displayName.toLowerCase().contains(term) ||
          shop.farmLocation.toLowerCase().contains(term) ||
          shop.varieties.any((v) => v.toLowerCase().contains(term));
    }).toList();
  }

  void _openShop(ShopSummary shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerId: shop.id,
          initialName: shop.displayName,
        ),
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
              const SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(child: _searchBar()),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              _list(),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search shops, places, varieties',
          prefixIcon: const Icon(
            Icons.storefront_outlined,
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
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              ClaySkeleton(height: 108, radius: AppRadius.lg),
              SizedBox(height: 12),
              ClaySkeleton(height: 108, radius: AppRadius.lg),
              SizedBox(height: 12),
              ClaySkeleton(height: 108, radius: AppRadius.lg),
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
          title: 'Cannot load the shops',
          message: _error!,
          actionLabel: 'Try again',
          onAction: _load,
        ),
      );
    }

    final shops = _visible;

    if (shops.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;

      return SliverFillRemaining(
        hasScrollBody: false,
        child: ClayEmptyState(
          icon: searching ? Icons.search_off_rounded : Icons.storefront_outlined,
          title: searching ? 'No shop matched' : 'No shops yet',
          message: searching
              ? 'Try the name of a farm, a place, or a kind of rice.'
              : 'Once a seller lists their rice, their shop appears here.',
          actionLabel: searching ? 'Clear search' : null,
          onAction: searching
              ? () {
                  _searchController.clear();
                  setState(() {});
                }
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShopCard(shop: shops[i], onTap: () => _openShop(shops[i])),
          ),
          childCount: shops.length,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shops',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Browse by the farms and traders selling rice',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, required this.onTap});

  final ShopSummary shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: shop.avatarImageUrl, name: shop.displayName),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shop.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (shop.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.primaryMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  shop.varietyLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (shop.farmLocation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          shop.farmLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    _Stat(
                      icon: Icons.star_rounded,
                      label: shop.averageRating > 0
                          ? '${shop.averageRating}'
                          : 'New',
                      tint: AppColors.accent,
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      icon: Icons.inventory_2_rounded,
                      label: '${shop.productCount}',
                    ),
                    if (shop.totalSold > 0) ...[
                      const SizedBox(width: 12),
                      _Stat(
                        icon: Icons.local_shipping_rounded,
                        label: '${shop.totalSold} sold',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'from',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              Text(
                '₱${shop.fromPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const Text(
                '/ kg',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tint ?? AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 58.0;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _initial()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initial(),
              placeholder: (_, _) => _initial(),
            ),
    );
  }

  Widget _initial() {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }
}
