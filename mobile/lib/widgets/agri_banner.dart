import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/clay.dart';

/// A short note about how buying here works.
///
/// Three of them, and they are app copy rather than data: there is no
/// promotions system behind this, so a card promising a discount would be
/// invented. These say something true about the platform instead, in as few
/// words as will fit.
class AgriNote {
  const AgriNote({
    required this.title,
    required this.body,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color tint;

  static const notes = [
    AgriNote(
      title: 'Straight from the farm',
      body: 'No middleman between the grower and your kitchen.',
      icon: Icons.agriculture_rounded,
      tint: AppColors.primaryDark,
    ),
    AgriNote(
      title: 'Sellers are checked',
      body: 'A verified badge means real permits were reviewed.',
      icon: Icons.verified_rounded,
      tint: AppColors.primaryMedium,
    ),
    AgriNote(
      title: 'Bigger sacks cost less',
      body: 'Sellers set their own discount per kilo.',
      icon: Icons.inventory_2_rounded,
      tint: AppColors.accent,
    ),
  ];
}

/// The strip across the top of Home: three notes, swipeable, with dots.
class AgriBannerStrip extends StatefulWidget {
  const AgriBannerStrip({super.key});

  @override
  State<AgriBannerStrip> createState() => _AgriBannerStripState();
}

class _AgriBannerStripState extends State<AgriBannerStrip> {
  final _controller = PageController(viewportFraction: 0.9);

  int _page = 0;
  Timer? _autoAdvance;

  @override
  void initState() {
    super.initState();

    // Advances on its own so the second and third are seen at all - most
    // people never swipe a banner. Slow enough to read, and it stops the
    // moment someone takes hold of it.
    _autoAdvance = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;

      _controller.animateToPage(
        (_page + 1) % AgriNote.notes.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _stopAutoAdvance() {
    _autoAdvance?.cancel();
    _autoAdvance = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 108,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) _stopAutoAdvance();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: AgriNote.notes.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _NoteCard(note: AgriNote.notes[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AgriNote.notes.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: _page == i ? 18 : 6,
                decoration: BoxDecoration(
                  color: _page == i
                      ? AppColors.primaryMedium
                      : AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final AgriNote note;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      radius: AppRadius.xl,
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: note.tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(note.icon, size: 25, color: note.tint),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
