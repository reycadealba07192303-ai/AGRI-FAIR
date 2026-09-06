import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';
import 'otp_verification_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      UserModel.of(context).applyAccount(user);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // An unverified account is a step the person has not finished, not a
      // dead end. Send them to the six boxes with a fresh code.
      if (err.isEmailNotVerified) {
        _goToVerification(_emailController.text.trim(), err.message);
        return;
      }

      // Everything else the backend writes for a person to read - "Your
      // account has been suspended", "Invalid credentials" - is shown as-is.
      _notify(err.message);
    }
  }

  void _goToVerification(String email, String message) {
    _notify(message);

    // Straight to the boxes. The screen asks for the code itself as it opens,
    // so nothing here waits on the network - holding the person on a spinner
    // while an email is dispatched is what made this feel like a timeout.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: email,
          fullName: '',
          sendOnOpen: true,
        ),
      ),
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                // Keeps the form from stretching into an unreadable strip on a
                // tablet or an unfolded phone.
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _backButton(),
                      const SizedBox(height: 28),
                      _mark(),
                      const SizedBox(height: 26),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: AppColors.textDark,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to keep shopping for rice.',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _emailField(),
                      const SizedBox(height: 14),
                      _passwordField(),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryMedium,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClayButton(
                        label: 'Sign In',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleSignIn,
                      ),
                      const SizedBox(height: 26),
                      _signUpRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClayIconButton(
        icon: Icons.arrow_back_rounded,
        size: 42,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  /// A raised clay disc rather than a flat logo, so the first thing on screen
  /// already shows what the rest of the app is made of.
  Widget _mark() {
    return Center(
      child: Container(
        height: 82,
        width: 82,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppShadows.raised,
        ),
        child: const Icon(
          Icons.rice_bowl_rounded,
          size: 36,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      enabled: !_isLoading,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(
          Icons.mail_outline_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
      ),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return 'Enter your email';
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
          return 'That does not look like an email';
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _handleSignIn(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter your password';
        return null;
      },
    );
  }

  Widget _signUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryMedium,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign up',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
