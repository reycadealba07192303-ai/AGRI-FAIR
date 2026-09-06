import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/seller.dart';
import '../services/api_client.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';

/// A seller's shop: who they are in a few lines, then what they sell.
///
/// The rice starts a single screen down. An earlier version stacked stats,
/// credentials, farm details and a bio above the listings, so a buyer who came
/// to see the goods had to scroll past four cards about the shop first.
/// Everything but the essentials now lives behind "Shop info".
class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    this.initialName = '',
  });

  final int sellerId;

  /// Shown while the profile loads, so the screen is not nameless at first.
  final String initialName;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  SellerProfile? _profile;
  List<Product> _products = const [];
  String _variety = '';
  String? _error;
  bool _loading = true;

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
      final results = await Future.wait([
        SellerService.instance.profile(widget.sellerId),
        SellerService.instance.products(widget.sellerId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as SellerProfile;
        _products = results[1] as List<Product>;
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

  /// Only what this shop stocks. A tab that filters to nothing is a dead end.
  List<String> get _varieties {
    final present = _products.map((p) => p.variety).toSet().toList()..sort();
    return ['', ...present];
  }

  List<Product> get _visible => _variety.isEmpty
      ? _products
      : _products.where((p) => p.variety == _variety).toList();

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  /// Credentials, farm and bio, on request.
  ///
  /// These matter when a buyer is deciding whether to trust the shop, which is
  /// not most of the time they spend here - so they are one tap away rather
  /// than four cards deep.
  void _showShopInfo() {
    final profile = _profile;
    if (profile == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _ShopInfoSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _error != null
          ? SafeArea(
              child: Column(
                children: [
                  _floatingBar(),
                  Expanded(
                    child: ClayEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Could not load this shop',
                      message: _error!,
                      actionLabel: 'Try again',
                      onAction: _load,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primaryMedium,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _hero()),
                  SliverToBoxAdapter(child: _identity()),
                  SliverToBoxAdapter(child: _stats()),
                  SliverToBoxAdapter(child: _actions()),
                  SliverToBoxAdapter(child: _varietyTabs()),
                  _grid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
    );
  }

  Widget _hero() {
    final profile = _profile;
    final farmPhoto =
        profile != null && profile.farmPhotoUrls.isNotEmpty
            ? profile.farmPhotoUrls.first
            : '';

    return SizedBox(
      height: 172,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (farmPhoto.isEmpty)
            // Sellers rarely upload a farm photo, and a blank green band reads
            // as a loading bug. A field stands in for one.
            Image.asset(
              'assets/banners/ricefarm2.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: AppColors.primaryDark),
            )
          else
            CachedNetworkImage(
              imageUrl: farmPhoto,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Image.asset(
                'assets/banners/ricefarm2.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.primaryDark),
              ),
              placeholder: (_, _) => Container(color: AppColors.surfaceSunken),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66101A14), Color(0x1A101A14)],
              ),
            ),
          ),
          _floatingBar(),
        ],
      ),
    );
  }

  Widget _floatingBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: ClayIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  Widget _identity() {
    final profile = _profile;

    return Transform.translate(
      // The avatar straddles the banner edge, which is what ties the two
      // together instead of stacking them as separate blocks.
      offset: const Offset(0, -34),
      child: Column(
        children: [
          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 4),
              boxShadow: AppShadows.raised,
            ),
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const ClaySkeleton(height: 74, width: 74, radius: 99)
                : profile!.avatarUrl.isEmpty
                    ? _avatarInitial(profile.displayName)
                    : CachedNetworkImage(
                        imageUrl: profile.avatarImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            _avatarInitial(profile.displayName),
                        placeholder: (_, _) =>
                            _avatarInitial(profile.displayName),
                      ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    profile?.displayName ?? widget.initialName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
              if (profile?.isVerified ?? false) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  size: 19,
                  color: AppColors.primaryMedium,
                ),
              ],
            ],
          ),
          if (profile != null && profile.farmLocation.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  profile.farmLocation,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stats() {
    final profile = _profile;

    return Transform.translate(
      offset: const Offset(0, -22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClayCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '${profile?.productCount ?? 0}',
                  label: 'Listings',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _Stat(
                  value: _compact(profile?.totalSold ?? 0),
                  label: 'Sold',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _Stat(
                  value: (profile?.averageRating ?? 0) > 0
                      ? '${profile!.averageRating}'
                      : '—',
                  label: (profile?.reviewCount ?? 0) == 1
                      ? '1 review'
                      : '${profile?.reviewCount ?? 0} reviews',
                  icon: Icons.star_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: ClayButton(
                label: 'Chat',
                icon: Icons.chat_bubble_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClayButton(
                label: 'Shop info',
                filled: false,
                icon: Icons.info_outline_rounded,
                onPressed: _profile == null ? null : _showShopInfo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _varietyTabs() {
    if (_loading || _products.isEmpty) return const SizedBox(height: 14);

    final varieties = _varieties;
    if (varieties.length <= 2) return const SizedBox(height: 20);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: varieties.length,
          separatorBuilder: (_, _) => const SizedBox(width: 9),
          itemBuilder: (context, i) {
            final value = varieties[i];
            return ClayChip(
              label: value.isEmpty ? 'All' : value,
              selected: _variety == value,
              onTap: () => setState(() => _variety = value),
            );
          },
        ),
      ),
    );
  }

  Widget _grid() {
    if (_loading) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(child: ClaySkeleton(height: 200, radius: AppRadius.lg)),
              SizedBox(width: 14),
              Expanded(child: ClaySkeleton(height: 200, radius: AppRadius.lg)),
            ],
          ),
        ),
      );
    }

    final products = _visible;

    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: ClayCard(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: Text(
                _products.isEmpty
                    ? 'This shop has nothing listed right now.'
                    : 'No $_variety in this shop.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.74,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _ProductTile(
            product: products[i],
            onTap: () => _openProduct(products[i]),
          ),
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _avatarInitial(String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      color: AppColors.surfaceSunken,
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryMedium,
          ),
        ),
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 3),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFFD7DED4),
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
                            size: 32,
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
                              size: 32,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          placeholder: (_, _) =>
                              Container(color: AppColors.surfaceSunken),
                        ),
                ),
                if (!product.inStock)
                  const Positioned(
                    top: 9,
                    left: 9,
                    child: ClayBadge(
                      label: 'Out of stock',
                      color: AppColors.error,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.variety,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '₱${product.startingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryMedium,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    if (product.averageRating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${product.averageRating}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Credentials, farm and bio - the things that matter once, not on every
/// scroll past.
class _ShopInfoSheet extends StatelessWidget {
  const _ShopInfoSheet({required this.profile});

  final SellerProfile profile;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            profile.displayName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.sellerTypeLabel,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          _trust(),
          if (profile.hasFarm) ...[
            const SizedBox(height: 14),
            _farm(),
          ],
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('About'),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textBody,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (profile.memberSince != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Selling on AgriFair since ${_monthYear(profile.memberSince!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trust() {
    final verified = profile.isVerified;

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.shield_rounded : Icons.shield_outlined,
                size: 18,
                color: verified ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Text(
                verified ? 'Verified by AgriFair' : 'Not yet verified',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: verified ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            verified
                ? 'An AgriFair admin approved this account, and the documents below were checked.'
                : 'This seller has not completed document checks yet. You can still buy from them, but take the usual care.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          if (profile.verifiedCredentials.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...profile.verifiedCredentials.map(
              (code) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        SellerProfile.credentialLabel(code),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (profile.acceptsGcash) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.qr_code_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Accepts GCash',
                  style: TextStyle(fontSize: 13, color: AppColors.textBody),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _farm() {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Farm'),
          const SizedBox(height: 11),
          if (profile.farmName.isNotEmpty)
            _FarmRow(icon: Icons.agriculture_rounded, text: profile.farmName),
          if (profile.farmLocation.isNotEmpty)
            _FarmRow(icon: Icons.place_rounded, text: profile.farmLocation),
          if (profile.farmSize.isNotEmpty)
            _FarmRow(icon: Icons.straighten_rounded, text: profile.farmSize),
          if (profile.farmPhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.farmPhotoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: profile.farmPhotoUrls[i],
                    width: 124,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 124,
                      color: AppColors.surfaceSunken,
                    ),
                    placeholder: (_, _) =>
                        const ClaySkeleton(height: 90, width: 124),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _monthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _FarmRow extends StatelessWidget {
  const _FarmRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.textMuted,
      ),
    );
  }
}
