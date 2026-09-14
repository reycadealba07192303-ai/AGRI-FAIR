import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/forgot_password_screen.dart';
import 'package:mobile_app/screens/sign_in_screen.dart';
import 'package:mobile_app/screens/sign_up_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';

/// The account screens, laid out on a real phone size.
void main() {
  const sizes = <String, Size>{
    'a normal phone': Size(1080, 2340),
    'a small phone': Size(720, 1440),
  };

  Future<void> pump(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: screen),
    );
    await tester.pump();
  }

  for (final entry in sizes.entries) {
    group('on ${entry.key}', () {
      testWidgets('sign in lays out', (tester) async {
        await pump(tester, const SignInScreen(), entry.value);

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        // Riders sign in on this same form; setting up happens from the
        // emailed link, so there is no separate door for them here.
        expect(find.text('Signing in as a delivery rider?'), findsNothing);
        expect(find.text('Still signed in'), findsNothing);
      });

      testWidgets('sign up lays out', (tester) async {
        await pump(tester, const SignUpScreen(), entry.value);

        expect(find.text('Join AgriFair.'), findsOneWidget);
      });

      testWidgets('forgot password lays out', (tester) async {
        await pump(tester, const ForgotPasswordScreen(), entry.value);

        expect(find.text('Forgot password?'), findsOneWidget);
      });
    });
  }
}
