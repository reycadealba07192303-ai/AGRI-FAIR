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
}
