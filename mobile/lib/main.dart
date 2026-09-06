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
  // Printed once at startup so a log always says which address this build is
  // calling. Without it, "cannot reach the server" and "took too long" look
  // identical whether the backend is down, the laptop moved networks, or the
  // build simply aimed at the emulator address while running on a phone.
  debugPrint('[agrifair] talking to ${ApiConfig.baseUrl}');

  final user = UserModel();

  // Any route can be the one that finds the session gone. Handling it once
  // here means no screen has to check for an expired token itself.
  ApiClient.instance.onUnauthorized = () {
    user.reset();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  };

  runApp(
    CartNotifier(
      model: CartModel(),
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
      UserModel.of(context).applyAccount(account);
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
