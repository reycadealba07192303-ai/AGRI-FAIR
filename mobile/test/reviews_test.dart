import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/review.dart';
import 'package:mobile_app/services/product_service.dart';
import 'package:mobile_app/services/review_service.dart';

void main() {
  test('a name is masked before it is shown', () {
    const review = Review(
      id: '1',
      buyerName: 'Reyca',
      rating: 5,
      comment: '',
      images: [],
    );

    // A review is a public record of a purchase, and these shops are small
    // enough that a full name beside one says more than a buyer agreed to.
    expect(review.maskedName, 'R**a');
    expect(review.maskedName, isNot(contains('eyc')));
  });

  test('a very short name still gets masked', () {
    const review = Review(
      id: '1',
      buyerName: 'Jo',
      rating: 4,
      comment: '',
      images: [],
    );

    expect(review.maskedName, 'J**');
  });

  test('a missing name does not crash the row', () {
    const review = Review(
      id: '1',
      buyerName: '   ',
      rating: 4,
      comment: '',
      images: [],
    );

    expect(review.maskedName, isNotEmpty);
  });

  test('reviews with photos come first', () {
    final summary = ReviewSummary.fromJson({
      'average': 4.5,
      'count': 3,
      'breakdown': {'4': 1, '5': 2},
      'reviews': [
        {'_id': 'a', 'buyerName': 'Ann', 'rating': 5, 'comment': 'no photo'},
        {
          '_id': 'b',
          'buyerName': 'Ben',
          'rating': 4,
          'comment': 'has photo',
          'images': ['/uploads/media/x.jpg'],
        },
        {'_id': 'c', 'buyerName': 'Cy', 'rating': 5, 'comment': 'no photo'},
      ],
    });

    // A picture of the actual sack answers more than a sentence about it.
    expect(summary.highlights.first.id, 'b');
    expect(summary.highlights, hasLength(3));
  });

  test('the breakdown is read back per star', () {
    final summary = ReviewSummary.fromJson({
      'average': 4.7,
      'count': 10,
      'breakdown': {'1': 0, '2': 0, '3': 1, '4': 1, '5': 8},
      'reviews': [],
    });

    expect(summary.countFor(5), 8);
    expect(summary.countFor(1), 0);
    expect(summary.countFor(3), 1);
  });

  test('an empty response is empty, not broken', () {
    final summary = ReviewSummary.fromJson({});

    expect(summary.isEmpty, isTrue);
    expect(summary.average, 0);
    expect(summary.reviews, isEmpty);
  });

  test('a real product returns a usable summary', () async {
    final products = await ProductService.instance.list();
    if (products.isEmpty) {
      markTestSkipped('no products in the database');
      return;
    }

    final summary = await ReviewService.instance.forProduct(products.first.id);

    expect(summary.count, greaterThanOrEqualTo(0));
    expect(summary.average, greaterThanOrEqualTo(0));
    expect(summary.reviews.length, lessThanOrEqualTo(summary.count));
  });
}
