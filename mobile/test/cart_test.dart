@Tags(['fixture'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/cart_service.dart';
import 'package:mobile_app/services/product_service.dart';

/// The cart against a running backend.
///
/// Needs a verified buyer:
///   curl -X POST http://localhost:8080/api/auth/register \
///     -H "Content-Type: application/json" -H "x-client: mobile" \
///     -d '{"name":"Cart Tester","email":"cart@agrifair.invalid",
///          "password":"cartpass123","role":"buyer"}'
///
///   flutter test --tags fixture --run-skipped -j 1
const _email = 'cart@agrifair.invalid';
const _password = 'cartpass123';

void main() {
  final cart = CartService.instance;
  late String productId;
  late double stock;

  setUpAll(() async {
    await AuthService.instance.signIn(email: _email, password: _password);

    final products = await ProductService.instance.list();
    productId = products.first.id;
    stock = products.first.stock.toDouble();
  });

  setUp(() async => cart.clear());
  tearDownAll(() async {
    await cart.clear();
    await ApiClient.instance.clearToken();
  });

  test('the cart starts empty and adding puts something in it', () async {
    expect((await cart.fetch()).isEmpty, isTrue);

    final after = await cart.add(productId: productId, weightKg: 1, quantity: 2);

    expect(after.items, hasLength(1));
    expect(after.items.first.quantity, 2);
    expect(after.sackCount, 2);
  });

  test('quantity counts sacks, and totalKg says what that weighs', () async {
    final after = await cart.add(productId: productId, weightKg: 5, quantity: 2);

    final line = after.items.first;
    expect(line.quantity, 2, reason: 'two sacks, not ten kilos');
    expect(line.totalKg, 10);
  });

  test('a line total is the sack price times the count', () async {
    final after = await cart.add(productId: productId, weightKg: 5, quantity: 2);
    final line = after.items.first;

    // Priced per sack and multiplied. Pricing 10 kg as one weight would match
    // no tier and quietly drop any bulk discount the seller set.
    expect(line.lineTotal, closeTo(line.unitPrice * line.quantity, 0.01));
  });

  test('the same rice at two weights is two lines', () async {
    await cart.add(productId: productId, weightKg: 1, quantity: 1);
    final after = await cart.add(productId: productId, weightKg: 5, quantity: 1);

    expect(after.items, hasLength(2));
    expect(after.items.map((i) => i.weightKg).toSet(), {1.0, 5.0});
  });

  test('adding the same line again adds to it rather than duplicating', () async {
    await cart.add(productId: productId, weightKg: 1, quantity: 1);
    final after = await cart.add(productId: productId, weightKg: 1, quantity: 2);

    expect(after.items, hasLength(1));
    expect(after.items.first.quantity, 3);
  });

  test('more than the seller has is refused, with the amount left', () async {
    await expectLater(
      cart.add(productId: productId, weightKg: stock + 100, quantity: 1),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('left'))),
    );
  });

  test('the stock check counts what the cart would hold in total', () async {
    // Adding one at a time must not walk past the stock a sack per tap.
    await cart.add(productId: productId, weightKg: stock, quantity: 1);

    await expectLater(
      cart.add(productId: productId, weightKg: stock, quantity: 1),
      throwsA(isA<ApiException>()),
    );
  });

  test('setting a quantity to zero removes the line', () async {
    await cart.add(productId: productId, weightKg: 1, quantity: 2);

    final after = await cart.setQuantity(
      productId: productId,
      weightKg: 1,
      quantity: 0,
    );

    expect(after.isEmpty, isTrue);
  });

  test('removing one weight leaves the other alone', () async {
    await cart.add(productId: productId, weightKg: 1, quantity: 1);
    await cart.add(productId: productId, weightKg: 5, quantity: 1);

    final after = await cart.remove(productId: productId, weightKg: 1);

    expect(after.items, hasLength(1));
    expect(after.items.first.weightKg, 5);
  });

  test('delivery is charged on a cart with something in it, not an empty one',
      () async {
    expect((await cart.clear()).deliveryFee, 0);

    final filled = await cart.add(
      productId: productId,
      weightKg: 1,
      quantity: 1,
    );

    expect(filled.deliveryFee, greaterThan(0));
    expect(filled.total, filled.subtotal + filled.deliveryFee);
  });
}
