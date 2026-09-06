import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/api_config.dart';

/// Checks that the app can actually talk to the backend.
///
/// Needs the server running (`npm run dev` in backend/). Run it with:
///   flutter test test/backend_smoke_test.dart
///
/// This is the one test that is allowed to depend on a live server — it exists
/// to answer "is the connection set up right", which a mocked test cannot.
void main() {
  final api = ApiClient.instance;

  test('base URL points at the api prefix', () {
    expect(ApiConfig.baseUrl, endsWith('/api'));
  });

  test('media paths are turned into absolute URLs', () {
    final url = ApiConfig.mediaUrl('/uploads/media/rice.jpg');
    expect(url, endsWith('/uploads/media/rice.jpg'));
    expect(url, isNot(contains('/api/uploads')));
    expect(ApiConfig.mediaUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg');
  });

  test('GET /products returns real rows from the database', () async {
    final products = await api.get('/products');

    expect(products, isA<List>(), reason: 'the data envelope should be unwrapped');

    if ((products as List).isNotEmpty) {
      final first = products.first as Map<String, dynamic>;
      expect(first['_id'], isNotNull, reason: 'every product needs an id');
      expect(first['variety'], isNotNull);
      expect(first['soldCount'], isNotNull, reason: 'added in Phase 1');
      expect(first['averageRating'], isNotNull, reason: 'added in Phase 1');
    }
  });

  test('a protected route without a token fails with a clear message', () async {
    await expectLater(
      api.get('/user/me'),
      throwsA(
        isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', true),
      ),
    );
  });

  test('a bad path reports the server message, not a generic failure', () async {
    await expectLater(
      api.get('/products/not-a-real-id'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', isNotEmpty)),
    );
  });
}
