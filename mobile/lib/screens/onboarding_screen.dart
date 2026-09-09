import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/portal_theme.dart';

/// The three screens the app opens on.
///
/// Full-bleed photography with brand-first English copy. Auto-advances so it
/// is seen rather than waited through; a swipe takes the pacing away from the
/// timer. Skip is always there.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String title;
  final String body;
}

const _slides = <_Slide>[
  _Slide(
    image: 'assets/banners/onboard_verified.png',
    title: 'Know who\nyou buy from',
    body:
        'Every shop here has had its permits reviewed. The verified badge '
        'means somebody looked.',
  ),
  _Slide(
    image: 'assets/banners/onboard_pricing.png',
    title: 'Clear prices\nby the sack',
    body:
        'From one kilo to fifty. See the full sack price before you buy — and '
        'sizes that ran short cannot be tapped.',
  ),
  _Slide(
    image: 'assets/banners/onboard_delivery.png',
    title: 'Follow it\nto your door',
    body:
        'Watch it leave the shop and come to you on the map, then see the '
        'photo the rider takes when it arrives.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  /// Long enough to actually read a slide; the last one waits for Get started.
  static const _hold = Duration(milliseconds: 4800);

  final _pages = PageController();
  late final AnimationController _logoIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  double _offset = 0;
  Timer? _tick;
  bool _manual = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _logoIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(parent: _logoIn, curve: Curves.easeOutBack);
    _logoOpacity = CurvedAnimation(parent: _logoIn, curve: Curves.easeOut);
    _logoIn.forward();

    _pages.addListener(() {
      final page = _pages.hasClients && _pages.position.haveDimensions
          ? _pages.page ?? 0
          : 0.0;
      if (page != _offset) setState(() => _offset = page);
    });
    _schedule();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _logoIn.dispose();
    _pages.dispose();
    super.dispose();
  }

  int get _index => _offset.round().clamp(0, _slides.length - 1);
  bool get _isLast => _index == _slides.length - 1;

  void _schedule() {
    _tick?.cancel();
    if (_manual) return;

    _tick = Timer(_hold, () {
      if (!mounted || _manual) return;
      // Never auto-leave the last slide — Get started / Skip must be tapped.
      if (_isLast) return;
      _advance();
    });
  }

  void _advance() {
    _pages.nextPage(
      duration: const Duration(milliseconds: 640),
      curve: Curves.easeOutCubic,
    );
    _schedule();
  }

  void _takeOver() {
    if (_manual) return;
    _tick?.cancel();
    setState(() => _manual = true);
  }

  void _finish() {
    if (_leaving) return;
    _leaving = true;
    _tick?.cancel();
    widget.onDone();
  }

  void _next() => _isLast ? _finish() : _advance();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PortalColors.green950,
        body: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) _takeOver();
                return false;
              },
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                itemBuilder: (context, i) => _SlidePage(
                  slide: _slides[i],
                  index: i,
                  offset: _offset,
                ),
              ),
            ),
            _TopBar(
              onSkip: _finish,
              logoScale: _logoScale,
              logoOpacity: _logoOpacity,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Footer(
                offset: _offset,
                isLast: _isLast,
                onNext: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({
    required this.slide,
    required this.index,
    required this.offset,
  });

  final _Slide slide;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final delta = (offset - index).clamp(-1.0, 1.0);
    final settled = (1 - delta.abs()).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: Offset(-delta * MediaQuery.sizeOf(context).width * 0.22, 0),
          child: Transform.scale(
            scale: 1.05 + (1 - settled) * 0.04,
            child: Image.asset(
              slide.image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x880F1D10),
                Color(0x220F1D10),
                Color(0xAA0F1D10),
                Color(0xF50F1D10),
              ],
              stops: [0, 0.28, 0.58, 1],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Opacity(
              opacity: settled,
              child: Transform.translate(
                offset: Offset(0, (1 - settled) * 28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 148),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 3,
                        decoration: BoxDecoration(
                          color: PortalColors.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        slide.title,
                        style: portalDisplay(
                          size: 36,
                          height: 1.08,
                          color: PortalColors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        slide.body,
                        style: portalBody(
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onSkip,
    required this.logoScale,
    required this.logoOpacity,
  });

  final VoidCallback onSkip;
  final Animation<double> logoScale;
  final Animation<double> logoOpacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
          child: Row(
            children: [
              FadeTransition(
                opacity: logoOpacity,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.82, end: 1).animate(logoScale),
                  child: Container(
                    height: 52,
                    width: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: PortalColors.cream.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: PortalColors.gold.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/brand/agrifair_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'AgriFair',
                  style: portalDisplay(
                    size: 22,
                    height: 1,
                    color: PortalColors.white,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Skip',
                  style: portalBody(
                    size: 13,
                    weight: FontWeight.w700,
                    color: PortalColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.offset,
    required this.isLast,
    required this.onNext,
  });

  final double offset;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 22),
        child: Row(
          children: [
            for (var i = 0; i < _slides.length; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              _Dot(active: (1 - (offset - i).abs()).clamp(0.0, 1.0)),
            ],
            const Spacer(),
            GestureDetector(
              onTap: onNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                decoration: BoxDecoration(
                  color: PortalColors.gold,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: PortalColors.gold.withValues(alpha: 0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? 'Get started' : 'Next',
                      style: portalBody(
                        size: 14,
                        weight: FontWeight.w700,
                        color: PortalColors.green950,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isLast
                          ? Icons.arrow_forward_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: PortalColors.green950,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final double active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 7,
      width: 7 + active * 18,
      decoration: BoxDecoration(
        color: Color.lerp(
          Colors.white.withValues(alpha: 0.28),
          PortalColors.gold,
          active,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
