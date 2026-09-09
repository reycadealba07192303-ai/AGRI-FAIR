import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/seller.dart';
import '../services/api_client.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'conversation_screen.dart';
import 'product_detail_screen.dart';

/// Two ways through the same shelf.
enum _ShopTab {
  popular('Popular'),
  all('All Products');

  const _ShopTab(this.label);

  final String label;
}

/// A seller's shop: one card about them, then the rice.
///
/// An earlier version stacked an avatar, a centred name, a row of three large
/// statistics and two full-width buttons before any listing appeared. It
/// pushed the goods most of a screen down, and looked emptiest exactly when a
/// shop was new - three big zeroes under three headings. One card says the
/// same things in a third of the height and reads the same whether a seller
/// has one listing or two hundred.
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
  static const double _bannerHeight = 132;

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

    if (_tab == _ShopTab.popular) {
      list.sort((a, b) {
        // Sales first, since that is what popular means. Rating settles ties
        // so a shop with nothing sold yet is not ordered at random.
        final bySold = b.soldCount.compareTo(a.soldCount);
        return bySold != 0 ? bySold : b.averageRating.compareTo(a.averageRating);
      });
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
  /// than in the way of the rice.
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
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _shopTabs()),
                  _grid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
    );
  }

  /// Banner behind, card in front, both in one box.
  ///
  /// A sliver clips whatever leaves its bounds, so the card that overlaps the
  /// banner has to share a Stack with it rather than being nudged up out of
  /// the sliver below.
  Widget _header() {
    return Stack(
      children: [
        SizedBox(
          height: _bannerHeight + 58,
          width: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: _bannerHeight, child: _banner()),
          ),
        ),
        Positioned(left: 18, right: 18, bottom: 0, child: _shopCard()),
        _floatingBar(),
      ],
    );
  }

  Widget _banner() {
    final profile = _profile;
    final farmPhoto = profile != null && profile.farmPhotoUrls.isNotEmpty
        ? profile.farmPhotoUrls.first
        : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (farmPhoto.isEmpty)
          // Sellers rarely upload a farm photo, and a blank band reads as a
          // loading bug. A field stands in for one.
          Image.asset(
            'assets/banners/ricefarm2.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.primaryDark),
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
              colors: [Color(0x59101A14), Color(0x14101A14)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shopCard() {
    final profile = _profile;

    return ClayCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile?.displayName ?? widget.initialName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (profile?.isVerified ?? false) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primaryMedium,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(profile),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _statLine(profile),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _MiniAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  filled: true,
                  // Straight into a thread with this seller, whether or not
                  // the two have ever spoken - the server creates it on the
                  // first message.
                  onTap: profile == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                otherUserId: profile.id,
                                otherName: profile.displayName,
                                otherAvatarUrl: profile.avatarUrl,
                              ),
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniAction(
                  icon: Icons.info_outline_rounded,
                  label: 'Shop info',
                  onTap: profile == null ? null : _showShopInfo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(SellerProfile? profile) {
    if (profile == null) return '';

    return [
      profile.sellerTypeLabel,
      if (profile.farmLocation.isNotEmpty) profile.farmLocation,
    ].join('  ·  ');
  }

  /// Rating, listings and sales on one line.
  ///
  /// A new shop reads as "New shop" and a listing count, rather than three
  /// zeroes under three headings - which is how the old block of statistics
  /// looked for every seller who had not sold anything yet.
  Widget _statLine(SellerProfile? profile) {
    if (profile == null) return const ClaySkeleton(height: 13, width: 150);

    return Row(
      children: [
        if (profile.averageRating > 0) ...[
          const Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 3),
          Text(
            '${profile.averageRating}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Text(
            ' (${profile.reviewCount})',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ] else
          const Text(
            'New shop',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryMedium,
            ),
          ),
        const _Dot(),
        Flexible(
          child: Text(
            _plural(profile.productCount, 'listing'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        if (profile.totalSold > 0) ...[
          const _Dot(),
          Text(
            '${profile.totalSold} sold',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _avatar() {
    final profile = _profile;
    const size = 52.0;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const ClaySkeleton(height: size, width: size)
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
            size: 38,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  Widget _shopTabs() {
    if (_loading || _products.isEmpty) return const SizedBox(height: 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
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
        padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: ClayCard(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: const Center(
              child: Text(
                'This shop has nothing listed right now.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryMedium,
          ),
        ),
      ),
    );
  }

  static String _plural(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        '·',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

/// A short action inside the shop card. Small enough that two fit on one row,
/// where two full-width buttons cost a whole row each.
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background =
        filled ? AppColors.primaryMedium : AppColors.surfaceSunken;
    final foreground = filled ? Colors.white : AppColors.textDark;

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            const Row(
              children: [
                Icon(Icons.qr_code_rounded, size: 15, color: AppColors.accent),
                SizedBox(width: 9),
                Text(
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
