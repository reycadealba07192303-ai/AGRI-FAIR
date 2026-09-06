import '../services/api_config.dart';

class Review {
  const Review({
    required this.id,
    required this.buyerName,
    required this.rating,
    required this.comment,
    required this.images,
    this.sellerReply = '',
    this.createdAt,
  });

  final String id;
  final String buyerName;
  final int rating;
  final String comment;
  final List<String> images;
  final String sellerReply;
  final DateTime? createdAt;

  List<String> get imageUrls => images.map(ApiConfig.mediaUrl).toList();
  bool get hasReply => sellerReply.trim().isNotEmpty;

  /// Shown as "a**i" rather than the full name.
  ///
  /// A review is a public record of what someone bought, and the shops here
  /// are small enough that a full name plus a purchase is more than a buyer
  /// signed up to reveal.
  String get maskedName {
    final name = buyerName.trim();
    if (name.isEmpty) return 'a**a';
    if (name.length <= 2) return '${name[0]}**';

    return '${name[0]}**${name[name.length - 1]}';
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      buyerName: (json['buyerName'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: (json['comment'] ?? '').toString(),
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      sellerReply: (json['sellerReply'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

/// Reviews plus the numbers that summarise them, as one response.
class ReviewSummary {
  const ReviewSummary({
    required this.average,
    required this.count,
    required this.breakdown,
    required this.reviews,
  });

  final double average;
  final int count;

  /// How many gave each star, keyed 1 to 5.
  final Map<int, int> breakdown;
  final List<Review> reviews;

  bool get isEmpty => count == 0;

  /// Reviews with a photo first: a picture of the actual sack answers more
  /// than a sentence about it.
  List<Review> get highlights {
    final withImages = reviews.where((r) => r.images.isNotEmpty).toList();
    final rest = reviews.where((r) => r.images.isEmpty).toList();

    return [...withImages, ...rest];
  }

  int countFor(int stars) => breakdown[stars] ?? 0;

  static const empty = ReviewSummary(
    average: 0,
    count: 0,
    breakdown: {},
    reviews: [],
  );

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['breakdown'];
    final breakdown = <int, int>{};

    if (rawBreakdown is Map) {
      rawBreakdown.forEach((key, value) {
        final stars = int.tryParse(key.toString());
        if (stars != null) breakdown[stars] = (value as num?)?.toInt() ?? 0;
      });
    }

    return ReviewSummary(
      average: (json['average'] as num?)?.toDouble() ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
      breakdown: breakdown,
      reviews: (json['reviews'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(Review.fromJson)
              .toList() ??
          const [],
    );
  }
}
