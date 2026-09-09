import '../models/review.dart';
import 'api_client.dart';

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  final _api = ApiClient.instance;

  /// Public - anyone browsing can read what buyers said.
  Future<ReviewSummary> forProduct(String productId) async {
    final body = await _api.get('/reviews/product/$productId');
    if (body is! Map<String, dynamic>) return ReviewSummary.empty;

    return ReviewSummary.fromJson(body);
  }

  Future<ReviewSummary> forSeller(int sellerId) async {
    final body = await _api.get('/reviews/seller/$sellerId');
    if (body is! Map<String, dynamic>) return ReviewSummary.empty;

    return ReviewSummary.fromJson(body);
  }

  /// Leaves a review on one delivered order line.
  ///
  /// Sent against the order, not the product. That is what makes a review
  /// worth reading: the server only accepts one from the buyer whose order
  /// this was and only once it is completed, so a rating cannot be posted by
  /// a competitor or by somebody who never bought the rice.
  ///
  /// Up to four photos, which is what turns "maganda po" into something the
  /// next buyer can check for themselves.
  Future<Review> submit({
    required String orderId,
    required int rating,
    String comment = '',
    List<String> imagePaths = const [],
  }) async {
    final body = await _api.postMultipart(
      '/reviews',
      fileField: 'images',
      filePaths: imagePaths.take(4).toList(),
      fields: {
        'orderId': orderId,
        'rating': '$rating',
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );

    if (body is! Map<String, dynamic>) {
      throw ApiException('The review was sent but the server said nothing back.');
    }

    return Review.fromJson(body);
  }
}
