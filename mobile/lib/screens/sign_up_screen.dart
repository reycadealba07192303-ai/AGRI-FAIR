import 'package:flutter/material.dart';

import '../theme/portal_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _usernameController,
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  bool get _passwordsMatch =>
      _passwordController.text == _confirmController.text;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty &&
      _passwordsMatch;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.instance.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!result.emailSent) {
        _showMessage(result.message);
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: _emailController.text.trim(),
            fullName: _nameController.text.trim(),
          ),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(err.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: PortalColors.green900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final showMismatch =
        _confirmController.text.isNotEmpty && !_passwordsMatch;

    return AuthScaffold(
      label: 'Create Account',
      title: 'Join AgriFair.',
      subtitle: 'A few details, then you can buy rice from verified shops.',
      scrollable: true,
      onBack: () => Navigator.of(context).maybePop(),
      footer: AuthFooterLink(
        question: 'Already have an account?',
        action: 'Sign in',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Full name'),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: const InputDecoration(hintText: 'Your full name'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _label('Username'),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: const InputDecoration(hintText: 'Choose a username'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please create a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _label('Email'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: const InputDecoration(
                  hintText: 'you@email.com',
                  prefixIcon: AuthFieldPrefix('ID'),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _label('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Create a password',
                  prefixIcon: const AuthFieldPrefix('PW'),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: PortalColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a password';
                  if (v.length < 8) return 'At least 8 characters required';
                  if (!RegExp(r'\d').hasMatch(v)) return 'Include a number';
                  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
                    return 'Include a symbol';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'At least 8 characters, with a number and a symbol.',
                  style: portalBody(
                    size: 12,
                    color: PortalColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label('Confirm password'),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                enabled: !_isLoading,
                onFieldSubmitted: (_) => _canSubmit ? _handleSignUp() : null,
                style: portalBody(size: 15, color: PortalColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Re-enter your password',
                  prefixIcon: const AuthFieldPrefix('PW'),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: PortalColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              if (showMismatch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Passwords do not match',
                    style: portalBody(size: 12.5, color: PortalColors.error),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthButton(
          label: 'Create account',
          isLoading: _isLoading,
          onPressed: _canSubmit && !_isLoading ? _handleSignUp : null,
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
}
