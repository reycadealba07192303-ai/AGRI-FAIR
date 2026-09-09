import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/onboarding_screen.dart';
import 'package:mobile_app/screens/splash_screen.dart';

/// Splash + the three onboarding screens.
void main() {
  Future<int> pumpOnboarding(WidgetTester tester) async {
    var done = 0;

    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done += 1)),
    );
    await tester.pump();

    return done;
  }

  testWidgets('brand splash shows the logo and AgriFair', (tester) async {
    var done = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onDone: () => done += 1)),
    );
    await tester.pump();

    expect(find.text('AgriFair'), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Must wait for tap — nothing auto-advances.
    await tester.pump(const Duration(seconds: 5));
    expect(done, 0);

    await tester.tap(find.text('Tap to continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(done, 1);
  });

  testWidgets('opens on the first screen, with all three built', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Know who\nyou buy from'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Clear prices\nby the sack'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Follow it\nto your door'), findsOneWidget);
  });

  testWidgets('moves on by itself, so it is seen rather than waited through',
      (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Know who\nyou buy from'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 4800));
    await tester.pumpAndSettle();

    expect(find.text('Clear prices\nby the sack'), findsOneWidget);
  });

  testWidgets('the last slide waits for Get started', (tester) async {
    var done = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done += 1)),
    );

    // Two advances to the last slide.
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 4800));
      await tester.pumpAndSettle();
    }

    expect(find.text('Follow it\nto your door'), findsOneWidget);
    expect(done, 0, reason: 'last slide should not auto-finish');

    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('a swipe takes the pacing away from the timer', (tester) async {
    var done = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done += 1)),
    );
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(find.text('Clear prices\nby the sack'), findsOneWidget);
    expect(done, 0, reason: 'the timer marched on over a reader');
  });

  testWidgets('Skip leaves at once, from any screen', (tester) async {
    var done = 0;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done += 1)),
    );
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(done, 1);
  });

  testWidgets('the button says what it does on the last screen',
      (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Next'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
  });
}
