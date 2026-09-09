import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/product.dart';

/// Which sack sizes a buyer is offered, and which of them can be bought.
///
/// The screenshot that started this: 10 kg of stock, with 25 kg and 50 kg both
/// tappable. Both were dead ends - the seller could not fill either - and the
/// buyer only found out after adding to the cart.
void main() {
  Product product({
    required int stock,
    List<WeightTier> tiers = const [],
    double pricePerKg = 60,
  }) {
    return Product(
      id: 'p1',
      name: 'Premium Jasmine Rice',
      variety: 'Jasmine',
      pricePerKg: pricePerKg,
      description: '',
      stock: stock,
      weightTiers: tiers,
      images: const [],
      averageRating: 0,
      reviewCount: 0,
      soldCount: 0,
    );
  }

  WeightOption optionFor(Product p, double kg) =>
      p.weightOptions.firstWhere((o) => o.weightKg == kg);

  group('every standard size is shown', () {
    test('all six, in ascending order, whatever the seller set', () {
      final p = product(
        stock: 500,
        tiers: const [WeightTier(weightKg: 50, discountPercent: 5)],
      );

      expect(
        p.weightOptions.map((o) => o.weightKg).toList(),
        [1, 2, 5, 10, 25, 50],
      );
    });

    test("a seller's own odd size joins the list rather than replacing it", () {
      final p = product(
        stock: 500,
        tiers: const [WeightTier(weightKg: 20, discountPercent: 0)],
      );

      expect(
        p.weightOptions.map((o) => o.weightKg).toList(),
        [1, 2, 5, 10, 20, 25, 50],
      );
    });
  });

  group('what can actually be bought', () {
    test('a size the seller does not sell is offered but not available', () {
      final p = product(
        stock: 500,
        tiers: const [WeightTier(weightKg: 25, discountPercent: 0)],
      );

      final five = optionFor(p, 5);
      expect(five.offered, isFalse);
      expect(five.available, isFalse);
      expect(five.unavailableReason, 'This seller does not sell this size');

      expect(optionFor(p, 25).available, isTrue);
    });

    test('the bug from the screenshot: 10 kg of stock closes 25 and 50', () {
      final p = product(
        stock: 10,
        tiers: const [
          WeightTier(weightKg: 25, discountPercent: 2),
          WeightTier(weightKg: 50, discountPercent: 5),
        ],
      );

      expect(optionFor(p, 25).available, isFalse);
      expect(optionFor(p, 50).available, isFalse);
      expect(
        optionFor(p, 25).unavailableReason,
        'Not enough stock left for this size',
      );
    });

    test('a size that exactly uses up the stock is still buyable', () {
      final p = product(
        stock: 25,
        tiers: const [WeightTier(weightKg: 25, discountPercent: 0)],
      );

      expect(optionFor(p, 25).available, isTrue);
    });

    test('no stock at all closes everything', () {
      final p = product(
        stock: 0,
        tiers: const [WeightTier(weightKg: 25, discountPercent: 0)],
      );

      expect(p.weightOptions.every((o) => !o.available), isTrue);
      expect(p.firstAvailableOption, isNull);
    });
  });

  group('what a size costs', () {
    test("the seller's discount applies to the size they set", () {
      final p = product(
        stock: 500,
        tiers: const [WeightTier(weightKg: 50, discountPercent: 5)],
      );

      // 60 * 50 * 0.95
      expect(optionFor(p, 50).price, 2850);
    });

    test('a size they did not set is priced straight off the per-kilo rate', () {
      final p = product(
        stock: 500,
        tiers: const [WeightTier(weightKg: 50, discountPercent: 5)],
      );

      expect(optionFor(p, 5).price, 300);
    });
  });

  group('the cheapest thing that can be bought', () {
    test('skips past sizes the seller does not sell', () {
      final p = product(
        stock: 500,
        tiers: const [
          WeightTier(weightKg: 25, discountPercent: 0),
          WeightTier(weightKg: 50, discountPercent: 0),
        ],
      );

      expect(p.firstAvailableOption!.weightKg, 25);
    });

    test('skips past sizes there is no stock for', () {
      final p = product(
        stock: 30,
        tiers: const [
          WeightTier(weightKg: 25, discountPercent: 0),
          WeightTier(weightKg: 50, discountPercent: 0),
        ],
      );

      expect(p.firstAvailableOption!.weightKg, 25);
    });

    test('a seller with no tiers at all still sells by the kilo', () {
      final p = product(stock: 5);

      expect(p.firstAvailableOption!.weightKg, 1);
      expect(optionFor(p, 1).offered, isTrue);
      expect(optionFor(p, 2).offered, isFalse);
    });
  });
}
