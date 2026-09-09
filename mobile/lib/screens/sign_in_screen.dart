import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'forgot_password_screen.dart';
import 'delivery_setup_screen.dart';
import 'main_screen.dart';
import 'otp_verification_screen.dart';
import 'rider_home_screen.dart';
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
      _land(user);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (err.isEmailNotVerified) {
        _goToVerification(_emailController.text.trim(), err.message);
        return;
      }

      if (err.isNotActivated) {
        _notify(err.message);
        _setUpDeliveryAccount();
        return;
      }

      _notify(err.message);
    }
  }

  void _land(AuthUser user) {
    if (user.role == 'rider') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
      );
      return;
    }

    unawaited(CartModel.of(context).refresh());

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  Future<void> _setUpDeliveryAccount() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DeliverySetupScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );

    if (email == null || !mounted) return;
    setState(() => _emailController.text = email);
  }

  void _goToVerification(String email, String message) {
    _notify(message);

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
    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue to AgriFair',
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      footer: AuthFooterLink(
        question: "Don't have an account?",
        action: 'Sign up',
        onTap: _isLoading
            ? () {}
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel('Email'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_isLoading,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                    return 'That does not look like an email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _fieldLabel('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_isLoading,
                onFieldSubmitted: (_) => _handleSignIn(),
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  return null;
                },
              ),
              const SizedBox(height: 6),
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
                    foregroundColor: PortalColors.primaryMedium,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: portalBody(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: PortalColors.primaryMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AuthButton(
                label: 'Sign In',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleSignIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _orRule(),
        const SizedBox(height: 12),
        _delivererRow(),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: portalBody(
          size: 12.5,
          weight: FontWeight.w700,
          color: PortalColors.textDark,
        ),
      ),
    );
  }

  Widget _orRule() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFCBD5C6), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: portalBody(
              size: 11,
              weight: FontWeight.w700,
              color: PortalColors.textMuted,
            ).copyWith(letterSpacing: 1.6),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFCBD5C6), height: 1)),
      ],
    );
  }

  Widget _delivererRow() {
    return AuthClayWell(
      onTap: _isLoading ? null : _setUpDeliveryAccount,
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: PortalColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: PortalClay.soft,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 18,
              color: PortalColors.primaryMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Signing in as a delivery rider?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalBody(
                    size: 13,
                    weight: FontWeight.w800,
                    color: PortalColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Set up with the email your shop used.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: portalBody(
                    size: 11.5,
                    color: PortalColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: PortalColors.primaryMedium,
          ),
        ],
      ),
    );
  }
}
