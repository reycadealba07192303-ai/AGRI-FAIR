import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Where the backend lives.
///
/// Hosts and secrets are never hardcoded here. Pass them at build/run time:
///
///   flutter run --dart-define-from-file=dart_defines.json
///
/// See `dart_defines.json.example`. Local `dart_defines.json` is gitignored.
class ApiConfig {
  /// Skip probing and use this exact URL:
  ///   --dart-define=API_BASE_URL=https://….up.railway.app/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Optional cloud/production API (must end with `/api`).
  static const String _cloudHost = String.fromEnvironment('API_CLOUD_URL');

  /// Optional LAN IP of the laptop (no scheme), e.g. `192.168.1.14`.
  static const String _lanHost = String.fromEnvironment('LAN_HOST');

  /// Force the USB tunnel (`adb reverse tcp:8080 tcp:8080`):
  ///   flutter run --dart-define=USE_ADB=true
  static const bool _useAdb = bool.fromEnvironment('USE_ADB');

  /// Force LAN only:
  ///   flutter run --dart-define=USE_LAN=true
  static const bool _useLan = bool.fromEnvironment('USE_LAN');

  static const int port = 8080;

  static String _localhost() => 'http://localhost:$port/api';
  static String _emulator() => 'http://10.0.2.2:$port/api';
  static String? _lan() {
    if (_lanHost.isEmpty) return null;
    return 'http://$_lanHost:$port/api';
  }

  static String? get _cloud => _cloudHost.isEmpty ? null : _cloudHost;

  /// Every address worth trying, best first.
  static List<String> get _candidates {
    if (_override.isNotEmpty) return [_override];
    if (_useAdb) return [_localhost()];

    final lan = _lan();
    if (_useLan) {
      if (lan == null) {
        throw StateError(
          'USE_LAN=true needs LAN_HOST in dart_defines.json '
          '(or --dart-define=LAN_HOST=…)',
        );
      }
      return [lan];
    }

    final out = <String>[];
    final cloud = _cloud;
    if (cloud != null) out.add(cloud);

    if (kIsWeb) {
      out.add(_localhost());
      return out.isEmpty ? [_localhost()] : out;
    }

    if (Platform.isAndroid) {
      out.addAll([_localhost(), _emulator()]);
      if (lan != null) out.add(lan);
      return out.isEmpty ? [_localhost(), _emulator()] : out;
    }

    out.add(_localhost());
    if (lan != null) out.add(lan);
    return out.isEmpty ? [_localhost()] : out;
  }

  static String? _resolved;
  static Future<String>? _resolving;

  /// The address in use, once [resolve] has run. Falls back to the first
  /// candidate so nothing that reads it synchronously can be left with null.
  static String get baseUrl => _resolved ?? _candidates.first;

  /// Finds the first address that answers, and remembers it.
  static Future<String> resolve() {
    if (_resolved != null) return Future.value(_resolved);
    return _resolving ??= _probe();
  }

  /// Forgets the answer, so the next call searches again.
  static void forget() {
    _resolved = null;
    _resolving = null;
  }

  static Future<String> _probe() async {
    final candidates = _candidates;

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

    _resolved = candidates.first;
    debugPrint('[agrifair] nothing answered; falling back to ${_resolved!}');
    return _resolved!;
  }

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
