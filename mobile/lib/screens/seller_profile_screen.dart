import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/seller.dart';
import '../services/api_client.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'product_detail_screen.dart';

/// The shop behind a listing: who they are, what proves it, and everything
/// else they sell.
class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    this.initialName = '',
  });

  final int sellerId;

  /// Shown in the app bar while the profile loads, so the screen is not
  /// nameless for the first moment.
  final String initialName;

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  SellerProfile? _profile;
  List<Product> _products = const [];
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
      // Both come from the same screen, so they are fetched together rather
      // than one after the other.
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

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: ClayIconButton(
            icon: Icons.arrow_back_rounded,
            size: 38,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        leadingWidth: 62,
        title: Text(profile?.displayName ?? widget.initialName),
      ),
      body: _loading
          ? const _LoadingBody()
          : _error != null
              ? ClayEmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'Could not load this seller',
                  message: _error!,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryMedium,
                  child: _body(profile!),
                ),
    );
  }

  Widget _body(SellerProfile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        _header(profile),
        const SizedBox(height: 16),
        _stats(profile),
        const SizedBox(height: 16),
        _trust(profile),
        if (profile.hasFarm) ...[
          const SizedBox(height: 16),
          _farm(profile),
        ],
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('About'),
                const SizedBox(height: 8),
                Text(
                  profile.bio,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            Text(
              'Listings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 8),
            Text(
              '${_products.length}',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_products.isEmpty)
          ClayCard(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: const Center(
              child: Text(
                'This seller has nothing listed right now.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
            ),
          )
        else
          ..._products.map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductRow(
                product: product,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(productId: product.id),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header(SellerProfile profile) {
    return ClayCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 84,
            width: 84,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              shape: BoxShape.circle,
              boxShadow: AppShadows.raised,
            ),
            clipBehavior: Clip.antiAlias,
            child: profile.avatarUrl.isEmpty
                ? _avatarInitial(profile.displayName)
                : CachedNetworkImage(
                    imageUrl: profile.avatarImageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _avatarInitial(profile.displayName),
                    placeholder: (_, _) => _avatarInitial(profile.displayName),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 7),
                const Icon(
                  Icons.verified_rounded,
                  size: 21,
                  color: AppColors.primaryMedium,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ClayBadge(
                label: profile.sellerTypeLabel,
                icon: Icons.agriculture_rounded,
                color: AppColors.primaryDark,
                compact: true,
              ),
              if (profile.isVerified)
                const ClayBadge(
                  label: 'Verified',
                  icon: Icons.shield_rounded,
                  color: AppColors.success,
                  compact: true,
                ),
              if (profile.acceptsGcash)
                const ClayBadge(
                  label: 'GCash ready',
                  icon: Icons.qr_code_rounded,
                  color: AppColors.accent,
                  compact: true,
                ),
            ],
          ),
          if (profile.memberSince != null) ...[
            const SizedBox(height: 12),
            Text(
              'Selling on AgriFair since ${_monthYear(profile.memberSince!)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stats(SellerProfile profile) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: profile.averageRating > 0
                ? profile.averageRating.toString()
                : '—',
            label: profile.reviewCount == 1 ? '1 review' : '${profile.reviewCount} reviews',
            icon: Icons.star_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: '${profile.productCount}',
            label: profile.productCount == 1 ? 'listing' : 'listings',
            icon: Icons.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: _compact(profile.totalSold),
            label: 'sold',
            icon: Icons.local_shipping_rounded,
          ),
        ),
      ],
    );
  }

  /// What actually backs the badge. A buyer who taps through deserves to see
  /// which permits were checked, not just a tick - though never the documents
  /// themselves, which the server does not send.
  Widget _trust(SellerProfile profile) {
    final verified = profile.isVerified;

    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.shield_rounded : Icons.shield_outlined,
                size: 19,
                color: verified ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 9),
              Text(
                verified ? 'Verified by AgriFair' : 'Not yet verified',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: verified ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            verified
                ? 'This seller was approved by an AgriFair admin, and the documents below were checked.'
                : 'This seller has not completed document checks yet. You can still buy from them, but take the usual care.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          if (profile.verifiedCredentials.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...profile.verifiedCredentials.map(
              (code) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        SellerProfile.credentialLabel(code),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _farm(SellerProfile profile) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Farm'),
          const SizedBox(height: 12),
          if (profile.farmName.isNotEmpty)
            _FarmRow(icon: Icons.agriculture_rounded, text: profile.farmName),
          if (profile.farmLocation.isNotEmpty)
            _FarmRow(icon: Icons.place_rounded, text: profile.farmLocation),
          if (profile.farmSize.isNotEmpty)
            _FarmRow(icon: Icons.straighten_rounded, text: profile.farmSize),
          if (profile.farmPhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: profile.farmPhotoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: CachedNetworkImage(
                    imageUrl: profile.farmPhotoUrls[i],
                    width: 130,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 130,
                      color: AppColors.surfaceSunken,
                    ),
                    placeholder: (_, _) => const ClaySkeleton(
                      height: 96,
                      width: 130,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarInitial(String name) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  static String _monthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      shadows: AppShadows.subtle,
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FarmRow extends StatelessWidget {
  const _FarmRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      shadows: AppShadows.subtle,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: 64,
              width: 64,
              child: product.primaryImageUrl.isEmpty
                  ? Container(
                      color: AppColors.surfaceSunken,
                      child: const Icon(
                        Icons.rice_bowl_outlined,
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
                          color: AppColors.primaryLight,
                        ),
                      ),
                      placeholder: (_, _) => const ClaySkeleton(height: 64, width: 64),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.variety,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${product.startingPrice.toStringAsFixed(0)} / kg',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryMedium,
                  ),
                ),
              ],
            ),
          ),
          if (!product.inStock)
            const ClayBadge(
              label: 'Out of stock',
              color: AppColors.textMuted,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: const [
        ClaySkeleton(height: 250, radius: AppRadius.lg),
        SizedBox(height: 16),
        ClaySkeleton(height: 96, radius: AppRadius.lg),
        SizedBox(height: 16),
        ClaySkeleton(height: 150, radius: AppRadius.lg),
        SizedBox(height: 26),
        ClaySkeleton(height: 88, radius: AppRadius.lg),
        SizedBox(height: 12),
        ClaySkeleton(height: 88, radius: AppRadius.lg),
      ],
    );
  }
}
