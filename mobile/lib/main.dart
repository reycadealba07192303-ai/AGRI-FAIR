import 'dart:async';

import 'package:flutter/material.dart';
import 'models/cart.dart';
import 'models/user_model.dart';
import 'models/chat_model.dart';
import 'models/review_model.dart';
import 'models/notification_model.dart';
import 'services/api_client.dart';
import 'services/api_config.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_screen.dart';
import 'screens/sign_in_screen.dart';

/// Lets the 401 handler navigate from outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  final cart = CartModel();
  // Starts the search for a reachable backend while the first screen builds,
  // so the address is usually settled before anything asks for it. ApiConfig
  // logs which one won; every failure afterwards names the address it tried.
  unawaited(ApiConfig.resolve());

  final user = UserModel();

  // Any route can be the one that finds the session gone. Handling it once
  // here means no screen has to check for an expired token itself.
  ApiClient.instance.onUnauthorized = () {
    user.reset();
    // The cart belongs to the account that just expired, not to whoever signs
    // in next.
    cart.forget();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  };

  runApp(
    CartNotifier(
      model: cart,
      child: UserNotifier(
        model: user,
        child: ChatNotifier(
          model: ChatModel(),
          child: ReviewNotifier(
            model: ReviewModel(),
            child: NotificationNotifier(
              model: NotificationModel(),
              child: const AgriFairApp(),
            ),
          ),
        ),
      ),
    ),
  );
}

class AgriFairApp extends StatelessWidget {
  const AgriFairApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriFair',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: const _SessionGate(),
    );
  }
}

/// Decides the first screen: straight into the app if the stored token still
/// works, otherwise the welcome flow. The token lives in secure storage, so it
/// survives a restart and the person is not asked to sign in every launch.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  bool _checking = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (!await ApiClient.instance.hasToken) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    try {
      final account = await AuthService.instance.me();
      if (!mounted) return;
      if (!mounted) return;
      UserModel.of(context).applyAccount(account);

      // The cart lives on the server now, so a restored session gets whatever
      // was left in it - including from another device.
      unawaited(CartModel.of(context).refresh());

      setState(() {
        _signedIn = true;
        _checking = false;
      });
    } catch (_) {
      // Expired, revoked, or the server is unreachable. Starting at the
      // welcome screen is the honest answer in all three cases.
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return _signedIn ? const MainScreen() : const WelcomeScreen();
  }
}
