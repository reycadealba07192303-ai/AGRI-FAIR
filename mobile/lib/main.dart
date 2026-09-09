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
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';

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
      home: const _LaunchGate(),
    );
  }
}

/// Launch order: splash → onboarding → sign in.
///
/// Session restore still runs in the background so the token is warm by the
/// time somebody signs in, but it does not skip past Sign In.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

enum _LaunchStep { splash, onboarding, ready }

class _LaunchGateState extends State<_LaunchGate> {
  _LaunchStep _step = _LaunchStep.splash;

  @override
  void initState() {
    super.initState();
    unawaited(_warmSession());
  }

  /// Keeps a stored token applied if it is still good, without routing home.
  Future<void> _warmSession() async {
    if (!await ApiClient.instance.hasToken) return;

    try {
      final account = await AuthService.instance.me();
      if (!mounted) return;
      UserModel.of(context).applyAccount(account);
      if (account.role != 'rider') {
        unawaited(CartModel.of(context).refresh());
      }
    } catch (_) {
      // Expired or unreachable — Sign In will ask again.
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _LaunchStep.splash => SplashScreen(
          onDone: () => setState(() => _step = _LaunchStep.onboarding),
        ),
      _LaunchStep.onboarding => OnboardingScreen(
          onDone: () => setState(() => _step = _LaunchStep.ready),
        ),
      _LaunchStep.ready => const SignInScreen(),
    };
  }
}
