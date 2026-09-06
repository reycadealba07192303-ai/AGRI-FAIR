import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';

/// A failed sign-in must not be mistaken for an expired session.
///
/// Needs the backend running and an unverified buyer:
///   curl -X POST http://localhost:8080/api/auth/register \
///     -H "Content-Type: application/json" -H "x-client: mobile" \
///     -d '{"name":"Gate Check Two","email":"gate2@agrifair.invalid",
///          "password":"gatepass123","role":"buyer"}'
const _email = 'gate2@agrifair.invalid';
const _password = 'gatepass123';

void main() {
  final auth = AuthService.instance;
  final api = ApiClient.instance;

  setUp(() async {
    await api.clearToken();
    api.onUnauthorized = null;
  });

  test('an unverified sign-in does not fire the session-expired handler', () async {
    // The global handler wipes the navigation stack back to sign-in. Firing it
    // on a *login* 401 tore the screen down before it could route to the code
    // boxes, which is what swallowed the verification step entirely.
    var sessionExpiredFired = false;
    api.onUnauthorized = () => sessionExpiredFired = true;

    try {
      await auth.signIn(email: _email, password: _password);
      fail('an unverified account should not have been let in');
    } on ApiException catch (err) {
      expect(err.isEmailNotVerified, isTrue);
      expect(err.message, contains('6-digit'));
    }

    expect(
      sessionExpiredFired,
      isFalse,
      reason: 'no session existed, so nothing expired',
    );
  });

  test('a wrong password also leaves the handler alone', () async {
    var fired = false;
    api.onUnauthorized = () => fired = true;

    await expectLater(
      auth.signIn(email: _email, password: 'not-the-password'),
      throwsA(isA<ApiException>()),
    );

    expect(fired, isFalse);
  });

  test('a 401 on a real session still fires it', () async {
    await api.saveToken('a.stale.token');

    var fired = false;
    api.onUnauthorized = () => fired = true;

    await expectLater(auth.me(), throwsA(isA<ApiException>()));
    expect(fired, isTrue, reason: 'this is what returns the app to sign-in');
  });

  test('the code the app resends actually goes out', () async {
    final message = await auth.resendVerification(_email);
    expect(message, isNotEmpty);
  });

  test('a bad product id is a clean 404, not an HTML crash page', () async {
    try {
      await api.get('/products/not-a-real-id');
      fail('should have been refused');
    } on ApiException catch (err) {
      expect(err.statusCode, 404);
      // The old default handler returned HTML with a stack trace, which
      // reached the app as "Unexpected server response".
      expect(err.message, isNot(contains('Unexpected')));
    }
  });

  test('an unknown route says so in JSON', () async {
    try {
      await api.get('/no-such-route');
      fail('should have been refused');
    } on ApiException catch (err) {
      expect(err.statusCode, 404);
      expect(err.message, contains('No route'));
    }
  });
}
