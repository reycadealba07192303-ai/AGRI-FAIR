@Tags(['fixture'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/address.dart';
import 'package:mobile_app/services/address_service.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';

/// Addresses and seller payment details against a running backend.
///
/// Needs a verified buyer. Create one, then mark it verified:
///   curl -X POST http://localhost:8080/api/auth/register \
///     -H "Content-Type: application/json" -H "x-client: mobile" \
///     -d '{"name":"Checkout Tester","email":"checkout@agrifair.invalid",
///          "password":"checkpass123","role":"buyer"}'
///
///   flutter test --tags fixture --run-skipped -j 1
const _email = 'checkout@agrifair.invalid';
const _password = 'checkpass123';

void main() {
  final addresses = AddressService.instance;

  setUpAll(() async {
    await AuthService.instance.signIn(email: _email, password: _password);
  });

  tearDownAll(() async => ApiClient.instance.clearToken());

  test('the first address saved becomes the default on its own', () async {
    // Start from nothing, so the run does not depend on what a previous one
    // left behind.
    for (final existing in await addresses.list()) {
      await addresses.remove(existing.id);
    }

    final list = await addresses.add(
      const Address(
        id: '',
        label: 'Home',
        fullName: 'Test Buyer',
        contact: '09171234567',
        line: '12 Purok Uno',
        city: 'Cabanatuan',
        province: 'Nueva Ecija',
        isDefault: false,
      ),
    );

    expect(list, hasLength(1));
    // Asked for false, saved as true: a list of one with no default would
    // leave checkout with nothing to preselect.
    expect(list.first.isDefault, isTrue);
  });

  test('a second address does not steal the default', () async {
    final list = await addresses.add(
      const Address(
        id: '',
        label: 'Work',
        fullName: 'Test Buyer',
        contact: '09171234567',
        line: '5F Tower',
        city: 'Manila',
        isDefault: false,
      ),
    );

    expect(list, hasLength(2));
    expect(list.where((a) => a.isDefault), hasLength(1));
    expect(list.firstWhere((a) => a.isDefault).label, 'Home');
  });

  test('switching the default moves it, never duplicates it', () async {
    final work = (await addresses.list()).firstWhere((a) => a.label == 'Work');
    final list = await addresses.makeDefault(work.id);

    expect(list.where((a) => a.isDefault), hasLength(1));
    expect(list.firstWhere((a) => a.isDefault).label, 'Work');
  });

  test('deleting the default promotes another', () async {
    final work = (await addresses.list()).firstWhere((a) => a.label == 'Work');
    final list = await addresses.remove(work.id);

    expect(list, hasLength(1));
    // Without this, checkout opens on no address at all.
    expect(list.first.isDefault, isTrue);
  });

  test('an incomplete address is refused with a readable reason', () async {
    await expectLater(
      addresses.add(
        const Address(
          id: '',
          label: 'Bad',
          fullName: '',
          contact: '',
          line: '',
          city: '',
          isDefault: false,
        ),
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', isNotEmpty)),
    );
  });

  test('the formatted line skips the parts a seller left blank', () {
    const address = Address(
      id: '1',
      label: 'Home',
      fullName: 'Test',
      contact: '09171234567',
      line: '12 Purok Uno',
      city: 'Cabanatuan',
      isDefault: true,
    );

    expect(address.formatted, '12 Purok Uno, Cabanatuan');
    expect(address.formatted, isNot(contains(', ,')));
  });

  test('an unverified payout returns no account number', () async {
    final payment = await addresses.paymentFor(6);

    if (!payment.available) {
      // The point of the flag: an unchecked QR could send money anywhere, so
      // nothing is sent at all and the app offers cash on delivery instead.
      expect(payment.accountNumber, isEmpty);
      expect(payment.qrImage, isEmpty);
      expect(payment.reason, isNotEmpty);
    } else {
      expect(payment.accountNumber, isNotEmpty);
    }
  });
}
