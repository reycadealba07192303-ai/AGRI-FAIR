import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/review.dart';
import '../services/api_client.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';

/// Every review left on one product.
///
/// Read from the server, not from a list in memory. This screen used to draw
/// from a local mock, so nothing a buyer actually posted ever appeared here -
/// and the photos, which are the part that makes a review checkable, were
/// never shown at all.
///
/// There is no "write a review" button. A review is written against the order
/// it is about, from the order itself, which is what lets the server accept
/// one only from the person who received the rice.
class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  ReviewSummary _summary = ReviewSummary.empty;
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
      final summary = await ReviewService.instance.forProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: ClayIconButton(
            icon: Icons.arrow_back_rounded,
            size: 38,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        leadingWidth: 62,
        title: const Text('Reviews'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: const [
          ClaySkeleton(height: 150, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 110, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 110, radius: AppRadius.lg),
        ],
      );
    }

    if (_error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load the reviews',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_summary.reviews.isEmpty) {
      return const ClayEmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        message:
            'Nobody has rated this rice yet. Buyers can review it once their '
            'order is completed.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryMedium,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _summary.reviews.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) return _overview();
          return _ReviewCard(review: _summary.reviews[i - 1]);
        },
      ),
    );
  }

  Widget _overview() {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _summary.average.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -1.2,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Stars(rating: _summary.average.round(), size: 15),
                  const SizedBox(height: 4),
                  Text(
                    '${_summary.count} review${_summary.count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      _breakdownRow(star, _summary.breakdown[star] ?? 0),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(int star, int count) {
    final share = _summary.count == 0 ? 0.0 : count / _summary.count;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$star',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
          const Icon(Icons.star_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
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
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.maskedName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      review.maskedName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _Stars(rating: review.rating, size: 12),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Text(
                  _dateLabel(review.createdAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
          ],
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            // The photos are the reason a review can be believed - what
            // actually arrived, rather than what somebody typed.
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openPhoto(context, review.imageUrls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: CachedNetworkImage(
                      imageUrl: review.imageUrls[i],
                      height: 84,
                      width: 84,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        height: 84,
                        width: 84,
                        color: AppColors.surfaceSunken,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 20, color: AppColors.textMuted),
                      ),
                      placeholder: (_, _) =>
                          const ClaySkeleton(height: 84, width: 84),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: 12),
            ClaySunken(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 13, color: AppColors.primaryMedium),
                      SizedBox(width: 6),
                      Text(
                        'Seller replied',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.sellerReply,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Dialog(
          insetPadding: const EdgeInsets.all(14),
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime when) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[when.month - 1]} ${when.day}';
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: star <= rating
                ? AppColors.accent
                : AppColors.textMuted.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
