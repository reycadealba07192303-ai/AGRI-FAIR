import 'package:flutter/material.dart';

class ProductReview {
  final String id;
  final String productName;
  final String reviewerName;
  final String reviewerEmail;
  final int rating;
  final String comment;
  final DateTime timestamp;

  const ProductReview({
    required this.id,
    required this.productName,
    required this.reviewerName,
    required this.reviewerEmail,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });
}

class ReviewModel extends ChangeNotifier {
  final List<ProductReview> _reviews;

  ReviewModel() : _reviews = _seed();

  static List<ProductReview> _seed() => [
        ProductReview(
          id: 's1',
          productName: 'Premium Jasmine Rice',
          reviewerName: 'Maria Santos',
          reviewerEmail: 'maria.s@example.com',
          rating: 5,
          comment:
              'Amazing fragrance and it cooks perfectly every time. This is now my go-to rice for daily meals. '
              'Highly recommend to anyone looking for quality jasmine rice.',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
        ),
        ProductReview(
          id: 's2',
          productName: 'Premium Jasmine Rice',
          reviewerName: 'Jose Reyes',
          reviewerEmail: 'jose.r@example.com',
          rating: 4,
          comment:
              'Very good quality. The aroma fills the kitchen while cooking. Will definitely buy again!',
          timestamp: DateTime.now().subtract(const Duration(days: 11)),
        ),
        ProductReview(
          id: 's3',
          productName: 'Premium Jasmine Rice',
          reviewerName: 'Liza Cruz',
          reviewerEmail: 'liza.c@example.com',
          rating: 5,
          comment: 'Best jasmine rice I have tried. Worth every peso!',
          timestamp: DateTime.now().subtract(const Duration(days: 19)),
        ),
        ProductReview(
          id: 's4',
          productName: 'Sinandomeng Rice',
          reviewerName: 'Pedro Dela Cruz',
          reviewerEmail: 'pedro.d@example.com',
          rating: 5,
          comment:
              'Classic Filipino rice done right. Soft, tasty, and goes well with any viand. '
              'My whole family loves it and we order every month.',
          timestamp: DateTime.now().subtract(const Duration(days: 6)),
        ),
        ProductReview(
          id: 's5',
          productName: 'Sinandomeng Rice',
          reviewerName: 'Ana Gonzales',
          reviewerEmail: 'ana.g@example.com',
          rating: 4,
          comment: 'Good rice, consistent quality every bag. Fast delivery too!',
          timestamp: DateTime.now().subtract(const Duration(days: 22)),
        ),
        ProductReview(
          id: 's6',
          productName: 'Organic Brown Rice',
          reviewerName: 'Carlo Mendoza',
          reviewerEmail: 'carlo.m@example.com',
          rating: 5,
          comment:
              'Switched to organic brown rice for health reasons and this product exceeded my '
              'expectations. Nutty flavor, very filling, and excellent quality.',
          timestamp: DateTime.now().subtract(const Duration(days: 14)),
        ),
        ProductReview(
          id: 's7',
          productName: 'Organic Brown Rice',
          reviewerName: 'Rosa Bautista',
          reviewerEmail: 'rosa.b@example.com',
          rating: 4,
          comment: 'Healthy and tasty. Takes a bit longer to cook but worth it.',
          timestamp: DateTime.now().subtract(const Duration(days: 26)),
        ),
        ProductReview(
          id: 's8',
          productName: 'Dinorado Rice',
          reviewerName: 'Mark Villanueva',
          reviewerEmail: 'mark.v@example.com',
          rating: 5,
          comment:
              'Hands down the best rice I have ever bought online. '
              'Sweet fragrance and perfect sticky texture. Worth every premium centavo!',
          timestamp: DateTime.now().subtract(const Duration(days: 4)),
        ),
        ProductReview(
          id: 's9',
          productName: 'Dinorado Rice',
          reviewerName: 'Claire Torres',
          reviewerEmail: 'claire.t@example.com',
          rating: 5,
          comment:
              'Absolutely delicious. We use this for special occasions and guests always ask where we get it.',
          timestamp: DateTime.now().subtract(const Duration(days: 17)),
        ),
        ProductReview(
          id: 's10',
          productName: 'Dinorado Rice',
          reviewerName: 'Ben Aquino',
          reviewerEmail: 'ben.a@example.com',
          rating: 4,
          comment: 'Great aromatic variety. Cooks beautifully and smells wonderful.',
          timestamp: DateTime.now().subtract(const Duration(days: 30)),
        ),
        ProductReview(
          id: 's11',
          productName: 'Black Rice',
          reviewerName: 'Ivan Ramos',
          reviewerEmail: 'ivan.r@example.com',
          rating: 4,
          comment:
              'Interesting taste and beautiful deep purple color when cooked. '
              'Very nutritious and a unique experience for the whole family.',
          timestamp: DateTime.now().subtract(const Duration(days: 9)),
        ),
        ProductReview(
          id: 's12',
          productName: 'Black Rice',
          reviewerName: 'Cathy Uy',
          reviewerEmail: 'cathy.u@example.com',
          rating: 5,
          comment: 'Love the health benefits and the bold color. Great for salads too!',
          timestamp: DateTime.now().subtract(const Duration(days: 20)),
        ),
        ProductReview(
          id: 's13',
          productName: 'Basmati Rice',
          reviewerName: 'Nadia Fernandez',
          reviewerEmail: 'nadia.f@example.com',
          rating: 5,
          comment:
              'Perfect for biryani! The long grains stay separate and the aroma is incredible. '
              'Best basmati available in this price range.',
          timestamp: DateTime.now().subtract(const Duration(days: 8)),
        ),
        ProductReview(
          id: 's14',
          productName: 'Glutinous Malagkit',
          reviewerName: 'Linda Ocampo',
          reviewerEmail: 'linda.o@example.com',
          rating: 5,
          comment:
              'Perfect for suman and biko! Extremely sticky and sweet. My lola approved!',
          timestamp: DateTime.now().subtract(const Duration(days: 12)),
        ),
        ProductReview(
          id: 's15',
          productName: 'Red Cargo Rice',
          reviewerName: 'Tito Reyes',
          reviewerEmail: 'tito.r@example.com',
          rating: 4,
          comment:
              'Earthy and hearty flavor. I love that it keeps me full longer. '
              'Great for anyone watching their diet.',
          timestamp: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];

  List<ProductReview> reviewsFor(String productName) => _reviews
      .where((r) => r.productName == productName)
      .toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  double averageRating(String productName) {
    final list = reviewsFor(productName);
    if (list.isEmpty) return 0;
    return list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
  }

  Map<int, int> ratingBreakdown(String productName) {
    final list = reviewsFor(productName);
    final map = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in list) {
      map[r.rating] = (map[r.rating] ?? 0) + 1;
    }
    return map;
  }

  bool hasReviewed(String productName, String email) => _reviews
      .any((r) => r.productName == productName && r.reviewerEmail == email);

  void addReview(ProductReview review) {
    _reviews.add(review);
    notifyListeners();
  }

  static ReviewModel of(BuildContext context) => ReviewNotifier.of(context);
}

class ReviewNotifier extends InheritedNotifier<ReviewModel> {
  const ReviewNotifier({
    super.key,
    required ReviewModel model,
    required super.child,
  }) : super(notifier: model);

  static ReviewModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReviewNotifier>()!.notifier!;
}
