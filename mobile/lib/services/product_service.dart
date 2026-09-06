import '../models/product.dart';
import 'api_client.dart';

class ProductService {
  ProductService._();

  static final ProductService instance = ProductService._();

  final _api = ApiClient.instance;

  List<Product> _parseList(dynamic body) {
    if (body is! List) return const [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(Product.fromJson)
        // A row with no id cannot be added to a cart or reviewed, so it is
        // dropped rather than shown as a dead end.
        .where((product) => product.id.isNotEmpty)
        .toList();
  }

  /// `variety` empty means every kind - the "All" chip.
  Future<List<Product>> list({String variety = '', int limit = 50}) async {
    final body = await _api.get('/products', query: {
      'limit': limit,
      if (variety.isNotEmpty) 'variety': variety,
      'status': 'active',
    });

    return _parseList(body);
  }

  Future<List<Product>> search(String term) async {
    if (term.trim().isEmpty) return list();
    return _parseList(await _api.get('/products/search', query: {'q': term.trim()}));
  }

  /// Carries the seller summary; the list rows do not.
  Future<Product> byId(String id) async {
    final body = await _api.get('/products/$id');
    return Product.fromJson(body as Map<String, dynamic>);
  }
}
