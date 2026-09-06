@Tags(['fixture'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/auth_service.dart';

/// Drives the real sign-in path against a running backend.
///
/// Needs the server up and the account below to exist. Create it with:
///   curl -X POST http://localhost:8080/api/auth/register \
///     -H "Content-Type: application/json" -H "x-client: mobile" \
///     -d '{"name":"Phase Three Check","email":"phase3-check@agrifair.invalid",
///          "password":"testpass123","role":"buyer"}'
///
/// Run with: flutter test test/auth_flow_test.dart
const _email = 'phase3-check@agrifair.invalid';
const _password = 'testpass123';

void main() {
  final auth = AuthService.instance;
  final api = ApiClient.instance;

  setUp(() async => api.clearToken());

  test('a wrong password is refused with the server\'s own wording', () async {
    await expectLater(
      auth.signIn(email: _email, password: 'definitely-not-it'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', isNotEmpty)),
    );
  });

  test('signing in returns the account and stores a token', () async {
    final user = await auth.signIn(email: _email, password: _password);

    expect(user.email, _email);
    expect(user.role, 'buyer', reason: 'mobile signups must not become sellers');
    expect(user.name, isNotEmpty);
    expect(user.id, isNotEmpty);

    expect(await api.hasToken, isTrue, reason: 'the JWT should be kept');
  });

  test('the stored token unlocks a protected route', () async {
    await auth.signIn(email: _email, password: _password);

    final me = await auth.me();
    expect(me.email, _email);
    expect(me.role, 'buyer');
  });

  test('signing out drops the token and locks the route again', () async {
    await auth.signIn(email: _email, password: _password);
    expect(await api.hasToken, isTrue);

    await auth.signOut();
    expect(await api.hasToken, isFalse);

    await expectLater(
      auth.me(),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', true)),
    );
  });

  test('a 401 fires the handler the app uses to return to sign-in', () async {
    var fired = false;
    api.onUnauthorized = () => fired = true;

    await expectLater(auth.me(), throwsA(isA<ApiException>()));
    expect(fired, isTrue);

    api.onUnauthorized = null;
  });
}
