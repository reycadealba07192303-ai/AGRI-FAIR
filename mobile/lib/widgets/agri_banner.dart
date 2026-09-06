import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'clay.dart';

/// A short note about how buying here works, over a photograph of the farm
/// side of it.
///
/// Three of them, and the words are app copy rather than data: there is no
/// promotions system behind this, so a card promising a discount would be
/// invented. These say something true about the platform instead, in as few
/// words as will fit.
class AgriNote {
  const AgriNote({
    required this.title,
    required this.body,
    required this.image,
  });

  final String title;
  final String body;
  final String image;

  static const notes = [
    AgriNote(
      title: 'Straight from the farm',
      body: 'No middleman between the grower and your kitchen.',
      image: 'assets/banners/ricefarm.png',
    ),
    AgriNote(
      title: 'Sellers are checked',
      body: 'A verified badge means real permits were reviewed.',
      image: 'assets/banners/ricefarm2.jpg',
    ),
    AgriNote(
      title: 'Bigger sacks cost less',
      body: 'Sellers set their own discount per kilo.',
      image: 'assets/banners/ricefarm3.png',
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
          height: 158,
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
        const SizedBox(height: 13),
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
      padding: EdgeInsets.zero,
      radius: AppRadius.xl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            note.image,
            fit: BoxFit.cover,
            // A missing asset should leave a plain green panel with readable
            // text on it, not a broken-image glyph in the middle of Home.
            errorBuilder: (_, _, _) => Container(color: AppColors.primaryDark),
          ),

          // The text sits bottom-left, so the scrim runs that way rather than
          // dimming the whole photograph.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x33101A14), Color(0xF0101A14)],
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xE6FFFFFF),
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
