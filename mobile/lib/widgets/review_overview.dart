import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/review.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// What buyers said, summarised: the score, how the stars are spread, and the
/// first couple of reviews in full.
///
/// The point is to answer "is this rice any good" without leaving the page.
/// A number alone does not - 4.7 from three people and 4.7 from three hundred
/// are different claims - so the count and the spread sit beside it.
class ReviewOverview extends StatelessWidget {
  const ReviewOverview({
    super.key,
    required this.summary,
    this.onSeeAll,
    this.maxPreview = 2,
  });

  final ReviewSummary summary;
  final VoidCallback? onSeeAll;
  final int maxPreview;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return _empty();

    final preview = summary.highlights.take(maxPreview).toList();

    return ClayCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reviews (${summary.count})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Row(
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryMedium,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primaryMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _score(),
          const SizedBox(height: 16),
          for (final review in preview) ...[
            const Divider(height: 1),
            const SizedBox(height: 14),
            _ReviewRow(review: review),
            const SizedBox(height: 14),
          ],
          if (onSeeAll != null && summary.count > preview.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: onSeeAll,
                child: Center(
                  child: Text(
                    'See all ${summary.count} reviews',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryMedium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _score() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  summary.average.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  ' /5',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 3),
            StarRow(rating: summary.average, size: 15),
          ],
        ),
        const SizedBox(width: 20),
        // The spread says whether a good average is agreed on or argued over.
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var stars = 5; stars >= 1; stars--)
                _BreakdownBar(
                  stars: stars,
                  count: summary.countFor(stars),
                  total: summary.count,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return ClayCard(
      child: Row(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 20,
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No reviews yet',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Be the first to say how this rice was.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Five stars filled to a fractional rating, so 4.5 shows as four and a half
/// rather than rounding to a score nobody gave.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: AppColors.accent,
          ),
      ],
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text(
              '$stars',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.star_rounded, size: 10, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: AppColors.surfaceSunken,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  review.maskedName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                review.maskedName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ),
            if (review.createdAt != null)
              Text(
                _ago(review.createdAt!),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        StarRow(rating: review.rating.toDouble(), size: 14),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            review.comment,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textBody,
              height: 1.45,
            ),
          ),
        ],
        if (review.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: CachedNetworkImage(
                  imageUrl: review.imageUrls[i],
                  height: 68,
                  width: 68,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    height: 68,
                    width: 68,
                    color: AppColors.surfaceSunken,
                  ),
                  placeholder: (_, _) =>
                      const ClaySkeleton(height: 68, width: 68),
                ),
              ),
            ),
          ),
        ],
        if (review.hasReply) ...[
          const SizedBox(height: 10),
          ClaySunken(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 13,
                      color: AppColors.primaryMedium,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Seller replied',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  review.sellerReply,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _ago(DateTime date) {
    final days = DateTime.now().difference(date).inDays;

    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '${days}d ago';
    if (days < 365) return '${(days / 30).floor()}mo ago';
    return '${(days / 365).floor()}y ago';
  }
}
