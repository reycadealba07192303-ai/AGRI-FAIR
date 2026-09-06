import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// Who you are buying from, on the product screen.
///
/// It sits between the price and the reviews on purpose: by then the buyer
/// knows what the rice costs and is deciding whether to trust the person
/// selling it, which is exactly the question this answers.
class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.seller, this.onTap});

  final ProductSeller seller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Avatar(url: seller.avatarImageUrl, name: seller.displayName),
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
                        seller.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (seller.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 17,
                        color: AppColors.primaryMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
        ],
      ),
    );
  }

  /// An unverified seller is not called out as suspect - the absent badge is
  /// the signal. Saying "Not verified" would read as an accusation against
  /// someone who may simply be new.
  String _subtitle() {
    final parts = <String>[
      if (seller.isVerified) 'Verified seller' else 'Seller',
      if (seller.averageRating > 0) '★ ${seller.averageRating}',
      if (seller.productCount > 0)
        '${seller.productCount} ${seller.productCount == 1 ? 'listing' : 'listings'}',
    ];

    return parts.join('  ·  ');
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        shape: BoxShape.circle,
        boxShadow: AppShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _initial()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // A missing avatar is not worth an error icon; the initial says
              // who this is just as well.
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
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }
}
