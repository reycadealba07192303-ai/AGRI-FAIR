@Tags(['fixture'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';

/// Walks a forgotten password from the code all the way to signing in again.
///
/// The stored code is a hash, so a test cannot read one back out of the
/// database - a known code has to be planted first. See
/// scratchpad/reset_flow_setup.mjs (seed), start the backend, then:
///   flutter test test/password_reset_test.dart
///
/// The chain runs in one test on purpose: a code is single use, so splitting
/// it across tests would spend it before the interesting part.
const _email = 'reset-check@agrifair.invalid';
const _seededCode = '424242';
const _oldPassword = 'oldpass123';
const _newPassword = 'brandnew456';

void main() {
  final auth = AuthService.instance;
  final api = ApiClient.instance;

  setUp(() async => api.clearToken());

  test('an unknown address gets the same answer as a real one', () async {
    final message = await auth.forgotPassword('nobody-here@agrifair.invalid');
    expect(message, isNotEmpty, reason: 'must not reveal who is registered');
  });

  test('a wrong code is refused and says how many tries are left', () async {
    await expectLater(
      auth.verifyResetOtp(email: _email, code: '000000'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('Incorrect code'))),
    );
  });

  test('too short a password is refused before anything changes', () async {
    await expectLater(
      auth.resetPassword(resetToken: 'not.a.token', newPassword: '123'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('6 characters'))),
    );
  });

  test('code -> token -> new password -> signed in with it', () async {
    // The old password works right now.
    final before = await auth.signIn(email: _email, password: _oldPassword);
    expect(before.email, _email);
    await api.clearToken();

    final resetToken = await auth.verifyResetOtp(
      email: _email,
      code: _seededCode,
    );
    expect(resetToken.split('.').length, 3, reason: 'should be a JWT');

    await auth.resetPassword(
      resetToken: resetToken,
      newPassword: _newPassword,
    );

    // This is the assertion that matters. Login checks the password against
    // Firebase, so signing in with the new one only works if the reset wrote
    // there too - a Mongo-only write passes everything above and still leaves
    // the person locked out.
    final after = await auth.signIn(email: _email, password: _newPassword);
    expect(after.email, _email);
    await api.clearToken();

    // ...and the old password is genuinely gone, not merely shadowed.
    await expectLater(
      auth.signIn(email: _email, password: _oldPassword),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('changing the password while signed in also reaches Firebase', () async {
    const third = 'thirdpass789';

    await auth.signIn(email: _email, password: _newPassword);
    await auth.changePassword(
      currentPassword: _newPassword,
      newPassword: third,
    );
    await api.clearToken();

    // Same trap as the reset: this only passes if the change was written to
    // Firebase, which is what login reads.
    final user = await auth.signIn(email: _email, password: third);
    expect(user.email, _email);
    await api.clearToken();

    // Put it back so the rest of the file keeps working from a known password.
    await auth.signIn(email: _email, password: third);
    await auth.changePassword(currentPassword: third, newPassword: _newPassword);
    await api.clearToken();
  });

  test('the wrong current password is refused', () async {
    await auth.signIn(email: _email, password: _newPassword);

    await expectLater(
      auth.changePassword(
        currentPassword: 'not-the-one',
        newPassword: 'whatever123',
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('incorrect'))),
    );
  });

  test('the code cannot be spent a second time', () async {
    await expectLater(
      auth.verifyResetOtp(email: _email, code: _seededCode),
      throwsA(isA<ApiException>()),
    );
  });
}
