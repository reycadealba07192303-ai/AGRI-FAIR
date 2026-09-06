import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _breatheCtrl;
  late final AnimationController _exitCtrl;
  final _random = Random();
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _breatheCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    _breatheCtrl.stop();
    await _exitCtrl.forward();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(_randomRoute());
  }

  Route _randomRoute() {
    const builders = [_fadeIn, _scaleFade, _slideUpFade, _slideSideFade];
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => const SignInScreen(),
      transitionsBuilder: builders[_random.nextInt(builders.length)],
    );
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
    parent: _introCtrl,
    curve: Interval(begin, end, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = min(
      size.width * 0.46,
      size.height * 0.26,
    ).clamp(96.0, 200.0);
    final titleSize = (size.width * 0.115).clamp(34.0, 46.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _continue,
          child: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: AnimatedBuilder(
                  animation: _exitCtrl,
                  builder: (context, child) {
                    final t = Curves.easeIn.transform(_exitCtrl.value);
                    return Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(scale: 1 + t * 0.05, child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        _buildLogo(logoSize),
                        const SizedBox(height: 28),
                        _buildWordmark(titleSize),
                        const SizedBox(height: 14),
                        _buildTagline(),
                        const SizedBox(height: 22),
                        _buildMessage(),
                        const Spacer(flex: 4),
                        _buildTapHint(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark,
            Color.lerp(AppColors.primaryDark, AppColors.primaryMedium, 0.45)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: _glow(300, AppColors.primaryLight.withValues(alpha: 0.14)),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _glow(340, AppColors.accent.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double diameter, Color color) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }

  Widget _buildLogo(double logoSize) {
    final reveal = _step(0.0, 0.55);
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, _breatheCtrl]),
      builder: (context, child) {
        final float = Curves.easeInOut.transform(_breatheCtrl.value);
        return Opacity(
          opacity: reveal.value,
          child: Transform.translate(
            offset: Offset(0, -6 + float * 12),
            child: Transform.scale(
              scale: 0.82 + reveal.value * 0.18,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: logoSize,
        height: logoSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _glow(logoSize, AppColors.primaryLight.withValues(alpha: 0.22)),
            Image.asset(
              'assets/products/AI, 3rd Draft(1).png',
              width: logoSize * 0.88,
              height: logoSize * 0.88,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordmark(double titleSize) {
    return _reveal(
      _step(0.25, 0.75),
      Text(
        'AgriFair',
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w800,
          color: AppColors.background,
          letterSpacing: -1,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return _reveal(
      _step(0.35, 0.85),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _rule(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'fresh harvest, fair prices',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _rule(),
        ],
      ),
    );
  }

  Widget _rule() {
    return Container(
      width: 26,
      height: 1,
      color: AppColors.accent.withValues(alpha: 0.55),
    );
  }

  Widget _buildMessage() {
    return _reveal(
      _step(0.45, 0.95),
      Text(
        'Welcome to the marketplace where every\ngrain comes straight from the farm.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppColors.background.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _buildTapHint() {
    final reveal = _step(0.65, 1.0);
    return AnimatedBuilder(
      animation: Listenable.merge([reveal, _breatheCtrl]),
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_breatheCtrl.value);
        return Opacity(
          opacity: reveal.value * (0.55 + pulse * 0.45),
          child: Transform.translate(
            offset: Offset(0, -pulse * 4),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Icon(
            Icons.keyboard_arrow_up_rounded,
            color: AppColors.background.withValues(alpha: 0.8),
            size: 26,
          ),
          const SizedBox(height: 2),
          Text(
            'Tap anywhere to continue',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.background.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 22),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

Widget _fadeIn(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

Widget _scaleFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
      child: child,
    ),
  );
}

Widget _slideUpFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.14),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

Widget _slideSideFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.18, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}
