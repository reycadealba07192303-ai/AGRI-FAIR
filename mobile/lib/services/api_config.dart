import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the backend lives, per device.
///
/// `localhost` on a phone or emulator means the phone itself, not the laptop
/// running the server — the single most common reason the app "cannot reach
/// the server" while the same URL works fine in a browser.
class ApiConfig {
  /// Override at build time without touching the file:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.14:8080/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const int port = 8080;

  /// Set this to the laptop's LAN IP to run on a real phone over Wi-Fi.
  /// Find it with `ipconfig` (Windows) and use the IPv4 address.
  static const String lanHost = '192.168.1.2';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // The Android emulator reaches the host machine through 10.0.2.2; the iOS
    // simulator shares the Mac's own network stack, so localhost is correct.
    if (kIsWeb) return 'http://localhost:$port/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:$port/api';
    if (Platform.isIOS) return 'http://localhost:$port/api';
    return 'http://localhost:$port/api';
  }

  /// Product images arrive as server-relative paths (`/uploads/media/x.jpg`),
  /// so they need the origin — without `/api` — put back in front.
  static String mediaUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final origin = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;

    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }
}
