import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// A horizontal row of rice, for recommendations at the foot of a product
/// page. Wide cards with the photo carrying them, the name and price laid over
/// a scrim so they stay readable on any image.
class ProductCarousel extends StatelessWidget {
  const ProductCarousel({
    super.key,
    required this.title,
    required this.products,
    required this.onTap,
    this.subtitle,
    this.loading = false,
  });

  final String title;
  final String? subtitle;
  final List<Product> products;
  final void Function(Product) onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading && products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.textDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: loading
              ? ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: const [
                    ClaySkeleton(height: 170, width: 258, radius: AppRadius.xl),
                    SizedBox(width: 14),
                    ClaySkeleton(height: 170, width: 258, radius: AppRadius.xl),
                  ],
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => ProductShowcaseCard(
                    product: products[i],
                    onTap: () => onTap(products[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class ProductShowcaseCard extends StatelessWidget {
  const ProductShowcaseCard({
    super.key,
    required this.product,
    required this.onTap,
    this.width = 258,
  });

  final Product product;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      width: width,
      padding: EdgeInsets.zero,
      radius: AppRadius.xl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (product.primaryImageUrl.isEmpty)
            Container(
              color: AppColors.surfaceSunken,
              child: const Icon(
                Icons.rice_bowl_outlined,
                size: 44,
                color: AppColors.primaryLight,
              ),
            )
          else
            CachedNetworkImage(
              imageUrl: product.primaryImageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                color: AppColors.surfaceSunken,
                child: const Icon(
                  Icons.rice_bowl_outlined,
                  size: 44,
                  color: AppColors.primaryLight,
                ),
              ),
              placeholder: (_, _) => Container(color: AppColors.surfaceSunken),
            ),

          // Dark only at the foot, where the text sits, and short of opaque:
          // enough to carry white text without turning a good photo into a
          // silhouette.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.15),
                end: Alignment.bottomCenter,
                colors: [Color(0x00101A14), Color(0xC2101A14)],
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 12,
            child: ClayBadge(
              label: product.variety,
              color: AppColors.primaryDark,
              compact: true,
            ),
          ),

          Positioned(
            left: 14,
            right: 14,
            bottom: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '₱${product.startingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Text(
                      ' /kg',
                      style: TextStyle(fontSize: 11.5, color: Color(0xCCFFFFFF)),
                    ),
                    const Spacer(),
                    if (product.averageRating > 0) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${product.averageRating}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ] else if (product.soldCount > 0)
                      Text(
                        '${product.soldCount} sold',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
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
