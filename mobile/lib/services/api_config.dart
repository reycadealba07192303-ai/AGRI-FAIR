import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the backend lives, per device.
///
/// `localhost` on a phone or emulator means the phone itself, not the laptop
/// running the server — the single most common reason the app "cannot reach
/// the server" while the same URL works fine in a browser.
class ApiConfig {
  /// Override the whole URL at build time without touching the file:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.14:8080/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Run against [lanHost] instead of the emulator address:
  ///   flutter run --dart-define=USE_LAN=true
  ///
  /// This is what a real phone needs. Without it an Android build always aims
  /// at 10.0.2.2, which only exists inside the emulator, and the app fails to
  /// reach the server with no obvious reason why.
  static const bool _useLan = bool.fromEnvironment('USE_LAN');

  static const int port = 8080;

  /// The laptop's LAN IP, used when the app runs on a real phone over Wi-Fi.
  ///
  /// This is the machine serving the backend, not the phone: the phone dials
  /// the laptop. It comes from DHCP, so it can change after a reconnect - when
  /// the app suddenly cannot reach the server, check this first with
  /// `ipconfig` and look at the Wi-Fi adapter's IPv4 address.
  static const String lanHost = '192.168.254.114';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // A real device has to dial the laptop by its address on the network.
    if (_useLan) return 'http://$lanHost:$port/api';

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
