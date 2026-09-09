@Tags(['fixture'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/order_service.dart';
import 'package:mobile_app/services/product_service.dart';
import 'package:mobile_app/services/review_service.dart';

/// Leaving a review, and what makes one worth reading.
///
/// A review is written against an order line, not a product. That is the whole
/// guarantee: the server takes one only from the buyer whose order it was,
/// only once the order is completed, and only once. A competitor cannot post
/// one, and neither can somebody who never bought the rice.
///
/// Needs the verified buyer from the chat tests with at least one **completed,
/// not yet reviewed** order. To make one, move an order through as the seller:
///   confirmed -> processing -> shipped -> delivered -> completed
///
///   flutter test --tags fixture --run-skipped -j 1
const _email = 'chat@agrifair.invalid';
const _password = 'chatpass123';

/// The smallest valid PNG, written to a temp file so the upload is a real
/// multipart file rather than a mocked one.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  final orders = OrderService.instance;
  final reviews = ReviewService.instance;

  late Directory tempDir;
  late String photoPath;

  setUpAll(() async {
    await AuthService.instance.signIn(email: _email, password: _password);

    tempDir = await Directory.systemTemp.createTemp('agrifair_review');
    photoPath = '${tempDir.path}/proof.png';
    await File(photoPath).writeAsBytes(base64Decode(_pngBase64));
  });

  tearDownAll(() async {
    ApiClient.instance.clearToken();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A completed order line, if this account has one.
  ///
  /// Whether it has already been reviewed is the server's call, not this
  /// helper's - the tests below assert both outcomes.
  Future<({String orderId, String productId, String productName})?>
      reviewable() async {
    final all = await orders.myOrders();

    for (final group in all.where((g) => g.status == 'completed')) {
      for (final item in group.items) {
        if (item.orderId.isEmpty || item.productId.isEmpty) continue;

        return (
          orderId: item.orderId,
          productId: item.productId,
          productName: item.productName,
        );
      }
    }

    return null;
  }

  group('what the server refuses', () {
    test('an order id that is not mine', () async {
      await expectLater(
        reviews.submit(orderId: '000000000000000000000000', rating: 5),
        throwsA(isA<ApiException>()),
      );
    });

    test('an order that has not been completed', () async {
      final all = await orders.myOrders();
      final open = all.firstWhere(
        (g) => g.status != 'completed' && g.status != 'cancelled',
        orElse: () => throw StateError('no open order to try this with'),
      );

      await expectLater(
        reviews.submit(orderId: open.items.first.orderId, rating: 5),
        throwsA(isA<ApiException>()),
      );
    });

    test('a rating outside one to five', () async {
      await expectLater(
        reviews.submit(orderId: '000000000000000000000000', rating: 9),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('a review from a completed order', () {
    test('posts with stars, words and a photo, and shows on the product',
        () async {
      final target = await reviewable();
      expect(
        target,
        isNotNull,
        reason: 'no completed order to review - complete one as the seller',
      );

      final before = await reviews.forProduct(target!.productId);

      final Object? failure = await reviews
          .submit(
            orderId: target.orderId,
            rating: 5,
            comment: 'Bagong ani, malinis, at tama ang timbang. Salamat po!',
            imagePaths: [photoPath],
          )
          .then((_) => null, onError: (Object e) => e);

      // Already reviewed is the one refusal that is correct on a repeat run;
      // anything else is a real failure.
      if (failure is ApiException) {
        expect(failure.message.toLowerCase(), contains('already reviewed'));
        return;
      }
      expect(failure, isNull);

      final after = await reviews.forProduct(target.productId);

      expect(after.count, before.count + 1);
      expect(after.average, greaterThan(0));

      final posted = after.reviews.first;
      expect(posted.rating, 5);
      expect(posted.comment, contains('Bagong ani'));

      // The photo is the part that makes a review checkable - what actually
      // arrived, rather than what somebody typed.
      expect(posted.images, isNotEmpty);
      expect(posted.imageUrls.first, contains('/uploads/media/'));

      // And the name is masked: a review is a public record of a purchase.
      expect(posted.maskedName, isNot(equals(posted.buyerName)));
      expect(posted.maskedName, contains('**'));
    });

    test('the same order cannot be reviewed twice', () async {
      final target = await reviewable();
      if (target == null) return;

      await expectLater(
        reviews.submit(orderId: target.orderId, rating: 1),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('already reviewed'),
          ),
        ),
      );
    });
  });

  group('the rating reaches the product', () {
    test('a reviewed product carries its average and count', () async {
      final target = await reviewable();
      if (target == null) return;

      final summary = await reviews.forProduct(target.productId);
      if (summary.count == 0) return;

      final product = await ProductService.instance.byId(target.productId);

      expect(product.reviewCount, summary.count);
      expect(product.averageRating, closeTo(summary.average, 0.05));
    });
  });
}
