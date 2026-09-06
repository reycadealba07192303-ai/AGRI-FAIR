import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';

/// An account is not usable until its email is proven.
///
/// Needs the backend running, a fresh unverified buyer, and a planted signup
/// code (the stored one is a hash). See scratchpad/verify_tmp.mjs, then:
///   flutter test test/verification_gate_test.dart
const _email = 'verify-gate@agrifair.invalid';
const _password = 'gatepass123';
const _seededCode = '135790';

void main() {
  final auth = AuthService.instance;
  final api = ApiClient.instance;

  setUp(() async => api.clearToken());

  test('an unverified account cannot sign in, and says why in a way the app can act on', () async {
    try {
      await auth.signIn(email: _email, password: _password);
      fail('an unverified account should not have been let in');
    } on ApiException catch (err) {
      expect(err.statusCode, 401);
      expect(err.isEmailNotVerified, isTrue,
          reason: 'the app routes to the code screen on this flag');
      expect(err.message, contains('verify'));
    }

    expect(await api.hasToken, isFalse, reason: 'no session may be left behind');
  });

  test('the wrong code does not verify the account', () async {
    await expectLater(
      auth.verifyEmailOtp(email: _email, code: '000000'),
      throwsA(isA<ApiException>()),
    );

    await expectLater(
      auth.signIn(email: _email, password: _password),
      throwsA(isA<ApiException>()
          .having((e) => e.isEmailNotVerified, 'isEmailNotVerified', true)),
    );
  });

  test('entering the code verifies the account and opens sign-in', () async {
    final message = await auth.verifyEmailOtp(email: _email, code: _seededCode);
    expect(message, isNotEmpty);

    // The gate reads emailVerified back from Firebase on every sign-in, so
    // this only passes if the flag was written there and not just in Mongo.
    final user = await auth.signIn(email: _email, password: _password);
    expect(user.email, _email);
    expect(user.emailVerified, isTrue);
    expect(await api.hasToken, isTrue);
  });
}
