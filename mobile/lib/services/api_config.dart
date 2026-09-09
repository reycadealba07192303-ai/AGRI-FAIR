import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Where the backend lives.
///
/// `localhost` on a phone means the phone itself, not the laptop running the
/// server - the single most common reason the app "cannot reach the server"
/// while the same URL works fine in a browser. There is no one address that is
/// right for every way of running this, so instead of asking the person to
/// remember a build flag, the app asks each candidate which one answers.
class ApiConfig {
  /// Skip the search entirely and use this exact URL:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.14:8080/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Force the USB tunnel (`adb reverse tcp:8080 tcp:8080`):
  ///   flutter run --dart-define=USE_ADB=true
  static const bool _useAdb = bool.fromEnvironment('USE_ADB');

  /// Force [lanHost], for a phone on the same Wi-Fi as the laptop:
  ///   flutter run --dart-define=USE_LAN=true
  static const bool _useLan = bool.fromEnvironment('USE_LAN');

  static const int port = 8080;

  /// The laptop's address on Wi-Fi. DHCP hands out a new one when the network
  /// changes, so when nothing else works, check this with `ipconfig` and look
  /// at the Wi-Fi adapter's IPv4 address.
  static const String lanHost = '10.88.125.230';

  static String _localhost() => 'http://localhost:$port/api';
  static String _emulator() => 'http://10.0.2.2:$port/api';
  static String _lan() => 'http://$lanHost:$port/api';

  /// Every address worth trying, best first.
  ///
  /// The USB tunnel leads because it is the one that does not care which
  /// network the phone is on; the emulator address follows because it is free
  /// to test and instantly right when running in an emulator; the Wi-Fi
  /// address is last because it is the one that goes stale.
  static List<String> get _candidates {
    if (_override.isNotEmpty) return [_override];
    if (_useAdb) return [_localhost()];
    if (_useLan) return [_lan()];

    if (kIsWeb) return [_localhost()];

    if (Platform.isAndroid) {
      return [_localhost(), _emulator(), _lan()];
    }

    // iOS simulator shares the Mac's network stack, so localhost is right; a
    // real iPhone still needs the LAN address.
    return [_localhost(), _lan()];
  }

  static String? _resolved;
  static Future<String>? _resolving;

  /// The address in use, once [resolve] has run. Falls back to the first
  /// candidate so nothing that reads it synchronously can be left with null.
  static String get baseUrl => _resolved ?? _candidates.first;

  /// Finds the first address that answers, and remembers it.
  ///
  /// Runs at most once per app launch; concurrent callers share the same
  /// attempt rather than each probing on their own.
  static Future<String> resolve() {
    if (_resolved != null) return Future.value(_resolved);
    return _resolving ??= _probe();
  }

  /// Forgets the answer, so the next call searches again. Used when a request
  /// fails outright - the laptop may have moved, or the cable been unplugged.
  static void forget() {
    _resolved = null;
    _resolving = null;
  }

  static Future<String> _probe() async {
    final candidates = _candidates;

    // A single candidate is not worth a round trip to confirm; if it is wrong,
    // the real request will say so with a better message than a probe could.
    if (candidates.length == 1) {
      _resolved = candidates.first;
      debugPrint('[agrifair] using ${_resolved!}');
      return _resolved!;
    }

    for (final candidate in candidates) {
      if (await _answers(candidate)) {
        _resolved = candidate;
        debugPrint('[agrifair] using $candidate');
        return candidate;
      }
      debugPrint('[agrifair] no answer from $candidate');
    }

    // Nothing answered. Settle on the first so the failure the person sees
    // comes from a real request, naming an address, rather than from here.
    _resolved = candidates.first;
    debugPrint('[agrifair] nothing answered; falling back to ${_resolved!}');
    return _resolved!;
  }

  /// The API root is a plain JSON reply that touches no database, so this
  /// costs the server nothing and cannot be slowed down by a cold query.
  static Future<bool> _answers(String base) async {
    try {
      final response = await http
          .get(Uri.parse(base))
          .timeout(const Duration(milliseconds: 1500));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Product images arrive server-relative (`/uploads/media/x.jpg`) and need
  /// the origin - without `/api` - put back in front.
  static String mediaUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final origin = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;

    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
