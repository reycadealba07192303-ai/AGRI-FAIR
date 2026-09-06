import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Anything the backend refuses, in one shape the screens can show directly.
///
/// The backend already writes messages meant for a person ("Not enough stock
/// to confirm this order."), so they are passed through rather than replaced
/// with a generic failure string.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Set only when the server marks a failure as one the app should act on,
  /// such as `EMAIL_NOT_VERIFIED`. Reading this beats matching the sentence,
  /// which changes whenever the wording is improved.
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isEmailNotVerified => code == 'EMAIL_NOT_VERIFIED';

  @override
  String toString() => message;
}

/// One HTTP client for the whole app: attaches the token, unwraps the
/// backend's `{ success, message, data }` envelope, and turns every failure
/// into an [ApiException].
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'agrifair_token';
  static const _timeout = Duration(seconds: 20);

  /// Called when the server rejects the stored token, so the app can send the
  /// user back to sign-in instead of showing an error on every screen.
  void Function()? onUnauthorized;

  String? _cachedToken;

  Future<String?> readToken() async {
    if (_cachedToken != null) return _cachedToken;

    // Secure storage needs a platform channel, which does not exist in a plain
    // Dart test run. "No token" is the safe reading of that — it means signed
    // out, never signed in as someone else.
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }

    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    // The session is live from here whatever the keystore does.
    _cachedToken = token;

    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (err) {
      // A locked or unavailable keystore must not undo a successful sign-in.
      // The person stays signed in for this run; only "stay signed in after a
      // restart" is lost, which is far better than failing the login itself.
      debugPrint('[api] could not persist the session token: $err');
    }
  }

  Future<void> clearToken() async {
    // Drop the in-memory copy first: even if the delete below fails, the rest
    // of this app run must stop sending a token the server has refused.
    _cachedToken = null;

    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Storage unavailable (a plain test run, or a locked keystore). Nothing
      // useful to do here, and throwing would turn a 401 into a crash.
    }
  }

  Future<bool> get hasToken async => (await readToken())?.isNotEmpty ?? false;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await readToken();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Lets the backend tell mobile traffic apart in its login history.
      'x-client': 'mobile',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path : '/$path';
    final params = query?.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .map((e) => MapEntry(e.key, '${e.value}'));

    return Uri.parse('${ApiConfig.baseUrl}$clean').replace(
      queryParameters: params == null || params.isEmpty
          ? null
          : Map.fromEntries(params),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() async => http.get(_uri(path, query), headers: await _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.post(
            _uri(path),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          ));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.put(
            _uri(path),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          ));

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.delete(
            _uri(path),
            headers: await _headers(),
            body: jsonEncode(body ?? {}),
          ));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    late http.Response response;

    try {
      response = await request().timeout(_timeout);
    } on SocketException {
      throw ApiException(
        'Cannot reach the server. Check that the backend is running and that '
        'the address in api_config.dart matches this device.',
      );
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Try again.');
    }

    return _parse(response);
  }

  dynamic _parse(http.Response response) {
    final status = response.statusCode;

    // A 401 means the stored token is gone or expired. Dropping it here keeps
    // the app from retrying with a credential the server has already refused.
    if (status == 401) {
      unawaited(clearToken());
      onUnauthorized?.call();
    }

    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        if (status >= 400) {
          throw ApiException('Unexpected server response.', statusCode: status);
        }
        return response.body;
      }
    }

    if (status >= 400) {
      final message = body is Map
          ? (body['message'] ?? body['error'] ?? body['msg'])
          : null;
      throw ApiException(
        message?.toString() ?? 'Request failed ($status).',
        statusCode: status,
        code: body is Map ? body['code']?.toString() : null,
      );
    }

    // Routes are inconsistent about wrapping: products come back as
    // `{ success, data }`, while `/user/me` returns the object itself.
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }
}
