import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Claiming the account a shop created for a delivery rider.
class DeliverySetupScreen extends StatefulWidget {
  const DeliverySetupScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<DeliverySetupScreen> createState() => _DeliverySetupScreenState();
}

enum _Step { email, password, verify }

class _DeliverySetupScreenState extends State<DeliverySetupScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  _Step _step = _Step.email;
  String _name = '';
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _findAccount() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _notify('Type the email your shop used.');
      return;
    }

    setState(() => _busy = true);

    try {
      final name = await AuthService.instance.startDeliverySetup(email);
      if (!mounted) return;
      setState(() {
        _name = name;
        _busy = false;
        _step = _Step.password;
      });
      _notify('We sent a 6-digit code to $email.');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(err.message);
    }
  }

  void _choosePassword() {
    if (_password.text.length < 6) {
      _notify('Choose a password of at least 6 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      _notify('The two passwords do not match.');
      return;
    }

    setState(() => _step = _Step.verify);
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 6) {
      _notify('Enter the 6 digits from your email.');
      return;
    }

    setState(() => _busy = true);

    try {
      final message = await AuthService.instance.activateAccount(
        email: _email.text.trim(),
        code: _code.text,
        password: _password.text,
      );

      if (!mounted) return;
      _notify(message);
      Navigator.of(context).pop(_email.text.trim());
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(err.message);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService.instance.resendVerification(_email.text.trim());
      if (!mounted) return;
      _notify('A new code is on its way.');
    } on ApiException catch (err) {
      if (!mounted) return;
      _notify(err.message);
    }
  }

  void _back() {
    setState(() {
      _step = _step == _Step.verify ? _Step.password : _Step.email;
    });
  }

  static const _titles = [
    'Your email.',
    'Choose a password.',
    'Verify it is you.',
  ];
  static const _blurbs = [
    'Your shop added you with an email. Type it and we will send a code.',
    'Choose a password only you know — not even your shop.',
    'Enter the 6 digits we emailed you to finish setup.',
  ];

  @override
  Widget build(BuildContext context) {
    final step = _Step.values.indexOf(_step);

    return AuthScaffold(
      label: 'Delivery Setup',
      title: _name.isEmpty ? _titles[step] : 'Hello, $_name.',
      subtitle: _blurbs[step],
      onBack: () => Navigator.of(context).maybePop(),
      scrollable: true,
      children: [
        _steps(),
        const SizedBox(height: 22),
        switch (_step) {
          _Step.email => _emailStep(),
          _Step.password => _passwordStep(),
          _Step.verify => _verifyStep(),
        },
      ],
    );
  }

  Widget _steps() {
    const labels = ['Email', 'Password', 'Verify'];
    final index = _Step.values.indexOf(_step);

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= index
                        ? PortalColors.gold
                        : PortalColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[i],
                  style: portalBody(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: i <= index
                        ? PortalColors.primaryMedium
                        : PortalColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Email',
          style: portalBody(
            size: 12.5,
            weight: FontWeight.w700,
            color: PortalColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          enabled: !_busy,
          onSubmitted: (_) {
            if (!_busy) _findAccount();
          },
          style: portalBody(size: 15, color: PortalColors.textDark),
          decoration: const InputDecoration(
            hintText: 'the address your shop used',
            prefixIcon: AuthFieldPrefix('ID'),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 20),
        AuthButton(
          label: 'Continue',
          isLoading: _busy,
          onPressed: _busy ? null : _findAccount,
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'New password',
          style: portalBody(
            size: 12.5,
            weight: FontWeight.w700,
            color: PortalColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: _obscurePassword,
          style: portalBody(size: 15, color: PortalColors.textDark),
          decoration: InputDecoration(
            hintText: 'at least 6 characters',
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
        ),
        const SizedBox(height: 14),
        Text(
          'Type it again',
          style: portalBody(
            size: 12.5,
            weight: FontWeight.w700,
            color: PortalColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirm,
          obscureText: _obscureConfirm,
          style: portalBody(size: 15, color: PortalColors.textDark),
          decoration: InputDecoration(
            hintText: 'Confirm password',
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
        ),
        const SizedBox(height: 20),
        AuthButton(label: 'Continue', onPressed: _choosePassword),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _back,
            child: Text(
              'Change the email',
              style: portalBody(
                size: 13.5,
                weight: FontWeight.w700,
                color: PortalColors.primaryMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _verifyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: portalDisplay(size: 28).copyWith(letterSpacing: 12),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        AuthButton(
          label: 'Verify and finish',
          isLoading: _busy,
          onPressed: _busy ? null : _verify,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _back,
              child: Text(
                'Back',
                style: portalBody(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: PortalColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: _resend,
              child: Text(
                'Resend code',
                style: portalBody(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: PortalColors.primaryMedium,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
