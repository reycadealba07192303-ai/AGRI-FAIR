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

/// Two ways through the same shelf.
enum _ShopTab {
  popular('Popular'),
  all('All Products');

  const _ShopTab(this.label);

  final String label;
}

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
  _ShopTab _tab = _ShopTab.popular;
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

  /// The same listings, ordered two ways.
  ///
  /// Popular leads because it answers what a first-time visitor is asking -
  /// what do people actually buy here - and All Products is the full shelf for
  /// someone who already knows what they want.
  List<Product> get _visible {
    final list = List<Product>.from(_products);

    switch (_tab) {
      case _ShopTab.popular:
        list.sort((a, b) {
          // Sales first, since that is what "popular" means. Rating settles
          // ties so a shop with nothing sold yet is not ordered at random.
          final bySold = b.soldCount.compareTo(a.soldCount);
          return bySold != 0 ? bySold : b.averageRating.compareTo(a.averageRating);
        });
      case _ShopTab.all:
        break;
    }

    return list;
  }

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
                  SliverToBoxAdapter(child: _shopTabs()),
                  _grid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
    );
  }

  static const double _bannerHeight = 172;
  static const double _avatarSize = 76;

  /// Banner and avatar in one box.
  ///
  /// The avatar has to overlap the banner's edge, and a sliver clips anything
  /// that leaves its own bounds - so both live in one Stack tall enough to
  /// hold the overlap, rather than the avatar being nudged upward out of the
  /// sliver below and having its top cut off.
  Widget _hero() {
    final profile = _profile;
    final farmPhoto = profile != null && profile.farmPhotoUrls.isNotEmpty
        ? profile.farmPhotoUrls.first
        : '';

    return SizedBox(
      height: _bannerHeight + _avatarSize / 2,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _bannerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (farmPhoto.isEmpty)
                  // Sellers rarely upload a farm photo, and a blank green band
                  // reads as a loading bug. A field stands in for one.
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
                    placeholder: (_, _) =>
                        Container(color: AppColors.surfaceSunken),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66101A14), Color(0x14101A14)],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: _bannerHeight - _avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(child: _avatar()),
          ),

          _floatingBar(),
        ],
      ),
    );
  }

  Widget _avatar() {
    final profile = _profile;

    return Container(
      height: _avatarSize,
      width: _avatarSize,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        // A ring in the page colour separates the avatar from the photograph
        // behind it, whatever that photograph happens to be.
        border: Border.all(color: AppColors.background, width: 4),
        boxShadow: AppShadows.raised,
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const ClaySkeleton(
              height: _avatarSize,
              width: _avatarSize,
              radius: 99,
            )
          : profile!.avatarUrl.isEmpty
              ? _avatarInitial(profile.displayName)
              : CachedNetworkImage(
                  imageUrl: profile.avatarImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _avatarInitial(profile.displayName),
                  placeholder: (_, _) => _avatarInitial(profile.displayName),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    profile.farmLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
    );
  }

  Widget _shopTabs() {
    if (_loading || _products.isEmpty) return const SizedBox(height: 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      child: Row(
        children: [
          for (final tab in _ShopTab.values) ...[
            _TabButton(
              label: tab.label,
              count: tab == _ShopTab.all ? _products.length : null,
              selected: _tab == tab,
              onTap: () => setState(() => _tab = tab),
            ),
            const SizedBox(width: 22),
          ],
        ],
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
              child: const Text(
                'This shop has nothing listed right now.',
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

/// An underlined tab rather than a filled pill.
///
/// These two switch how one list is ordered, not what the screen is. A pill
/// would look like the variety filters elsewhere and promise a different set
/// of rice.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textDark : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: -0.2,
                  color: color,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            width: selected ? 26 : 0,
            decoration: BoxDecoration(
              color: AppColors.primaryMedium,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
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
