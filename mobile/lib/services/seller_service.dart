import '../models/product.dart';
import '../models/seller.dart';
import 'api_client.dart';

class SellerService {
  SellerService._();

  static final SellerService instance = SellerService._();

  final _api = ApiClient.instance;

  /// The shop directory. Only sellers with something listed come back.
  Future<List<ShopSummary>> shops() async {
    final body = await _api.get('/sellers');
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(ShopSummary.fromJson)
        .where((shop) => shop.id > 0)
        .toList();
  }

  Future<SellerProfile> profile(int sellerId) async {
    final body = await _api.get('/sellers/$sellerId');
    return SellerProfile.fromJson(body as Map<String, dynamic>);
  }

  /// Active listings only - the same shop a buyer would browse.
  Future<List<Product>> products(int sellerId) async {
    final body = await _api.get('/sellers/$sellerId/products');
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        .where((product) => product.id.isNotEmpty)
        .toList();
  }
}
