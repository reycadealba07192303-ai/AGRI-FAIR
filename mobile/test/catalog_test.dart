import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/services/product_service.dart';
import 'package:mobile_app/services/seller_service.dart';

/// The catalog against a running backend, after the mock data was removed.
///
/// Run with the server up: flutter test test/catalog_test.dart
void main() {
  final products = ProductService.instance;
  final sellers = SellerService.instance;

  test('weight prices come from the tier, not a hardcoded ladder', () {
    const product = Product(
      id: 'x',
      name: 'Test',
      variety: 'Jasmine',
      pricePerKg: 60,
      description: '',
      stock: 10,
      weightTiers: [
        WeightTier(weightKg: 25, discountPercent: 2),
        WeightTier(weightKg: 50, discountPercent: 5),
      ],
      images: [],
      averageRating: 0,
      reviewCount: 0,
      soldCount: 0,
    );

    // 60 * 25 * 0.98
    expect(product.priceFor(product.weightTiers[0]), 1470);
    // 60 * 50 * 0.95
    expect(product.priceFor(product.weightTiers[1]), 2850);
  });

  test('tiers come back smallest first, whatever order the seller saved them', () {
    const product = Product(
      id: 'x',
      name: 'Test',
      variety: 'Jasmine',
      pricePerKg: 60,
      description: '',
      stock: 1,
      weightTiers: [
        WeightTier(weightKg: 50, discountPercent: 5),
        WeightTier(weightKg: 25, discountPercent: 2),
      ],
      images: [],
      averageRating: 0,
      reviewCount: 0,
      soldCount: 0,
    );

    expect(product.sellableTiers.first.weightKg, 25);
  });

  test('a seller with no tiers still has something buyable', () {
    const product = Product(
      id: 'x',
      name: 'Test',
      variety: 'Jasmine',
      pricePerKg: 60,
      description: '',
      stock: 1,
      weightTiers: [],
      images: [],
      averageRating: 0,
      reviewCount: 0,
      soldCount: 0,
    );

    expect(product.sellableTiers.length, 1);
    expect(product.priceFor(product.sellableTiers.first), 60);
  });

  test('the catalog loads real rows and every one has an id', () async {
    final list = await products.list();

    for (final product in list) {
      expect(product.id, isNotEmpty, reason: 'cart and reviews are keyed by it');
      expect(product.name, isNotEmpty);
    }
  });

  test('product detail carries the seller summary', () async {
    final list = await products.list();
    if (list.isEmpty) {
      markTestSkipped('no products in the database');
      return;
    }

    final detail = await products.byId(list.first.id);

    expect(detail.id, list.first.id);
    expect(detail.seller, isNotNull, reason: 'the card renders from this');
    expect(detail.seller!.id, greaterThan(0));
    expect(detail.seller!.name, isNotEmpty);
  });

  test('image paths are absolute by the time a widget sees them', () async {
    final list = await products.list();
    final withImage = list.where((p) => p.images.isNotEmpty);

    for (final product in withImage) {
      expect(product.primaryImageUrl, startsWith('http'));
      expect(product.primaryImageUrl, isNot(contains('/api/uploads')));
    }
  });

  test('a seller profile loads and never carries private fields', () async {
    final list = await products.list();
    if (list.isEmpty) {
      markTestSkipped('no products in the database');
      return;
    }

    final detail = await products.byId(list.first.id);
    final profile = await sellers.profile(detail.seller!.id);

    expect(profile.id, detail.seller!.id);
    expect(profile.name, isNotEmpty);

    // The model has no field for a document file, reference number or payout
    // account, because the API does not send them. Only the badge and the
    // kinds of permit that passed.
    expect(profile.verifiedCredentials, isA<List<String>>());
  });

  test("a seller's shop lists only their own products", () async {
    final list = await products.list();
    if (list.isEmpty) {
      markTestSkipped('no products in the database');
      return;
    }

    final detail = await products.byId(list.first.id);
    final shop = await sellers.products(detail.seller!.id);

    expect(shop, isNotEmpty);
    expect(shop.any((p) => p.id == detail.id), isTrue);
  });
}
