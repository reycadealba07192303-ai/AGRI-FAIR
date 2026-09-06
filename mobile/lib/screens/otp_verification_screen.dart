import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/agrifair_logo.dart';
import '../widgets/primary_button.dart';
import 'new_password_screen.dart';
import 'sign_in_screen.dart';

/// The same six boxes serve both codes the backend sends. Only the wording and
/// what happens after a correct code differ, so one screen covers both rather
/// than a near-duplicate for each.
enum OtpPurpose { signup, passwordReset }

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final OtpPurpose purpose;

  /// Ask for a code as the screen opens.
  ///
  /// Set when arriving from a blocked sign-in, where no code was requested
  /// yet. Sign-up does not need it - registering already sent one - and asking
  /// again there would spend a slot from the resend allowance for nothing.
  final bool sendOnOpen;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.fullName,
    this.purpose = OtpPurpose.signup,
    this.sendOnOpen = false,
  });

  bool get isReset => purpose == OtpPurpose.passwordReset;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 30;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isVerifying = false;
  bool _hasError = false;
  int _secondsLeft = _resendSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
    _startResendTimer();

    if (widget.sendOnOpen) {
      // Not awaited: the boxes are usable immediately and the code is valid
      // the moment the server stores it, so there is nothing to wait for.
      _requestCode();
    }
  }

  Future<void> _requestCode() async {
    try {
      final message = widget.isReset
          ? await AuthService.instance.forgotPassword(widget.email)
          : await AuthService.instance.resendVerification(widget.email);

      if (!mounted) return;
      _notify(message);
    } on ApiException catch (err) {
      if (!mounted) return;
      // Resend is right there, so this is worth saying but not worth blocking.
      _notify(err.message);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _canSubmit => _code.length == _codeLength;

  void _startResendTimer() {
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _onDigitChanged(int index, String value) {
    if (_hasError) setState(() => _hasError = false);

    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _codeLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length >= _codeLength
          ? _codeLength - 1
          : digits.length;
      _focusNodes[next].requestFocus();
      return;
    }

    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    try {
      if (widget.isReset) {
        // A correct reset code buys a short-lived token, not a session. The new
        // password is set on the next screen, so the code never travels with it.
        final resetToken = await AuthService.instance.verifyResetOtp(
          email: widget.email,
          code: _code,
        );

        if (!mounted) return;
        setState(() => _isVerifying = false);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(
              email: widget.email,
              resetToken: resetToken,
            ),
          ),
        );
        return;
      }

      final message = await AuthService.instance.verifyEmailOtp(
        email: widget.email,
        code: _code,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);
      _notify(message);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on ApiException catch (err) {
      // The server counts the tries and says how many are left, so its message
      // is more useful here than a plain "wrong code".
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _hasError = true;
      });
      _clearDigits();
      _notify(err.message);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0) return;

    _clearDigits();
    setState(() => _hasError = false);
    _startResendTimer();

    try {
      final message = widget.isReset
          ? await AuthService.instance.forgotPassword(widget.email)
          : await AuthService.instance.resendVerification(widget.email);
      if (!mounted) return;
      _notify(message);
    } on ApiException catch (err) {
      if (!mounted) return;
      _notify(err.message);
    }
  }

  void _clearDigits() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String _maskedEmail() {
    final email = widget.email;
    final atIndex = email.indexOf('@');
    if (atIndex <= 1) return email;
    final name = email.substring(0, atIndex);
    final domain = email.substring(atIndex);
    final visible = name.length <= 2 ? name[0] : name.substring(0, 2);
    return '$visible${'*' * (name.length - visible.length)}$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Center(child: AgriFairLogo()),
              const SizedBox(height: 36),
              _buildHeroText(),
              const SizedBox(height: 16),
              _buildSubtitle(),
              const SizedBox(height: 36),
              _buildCodeRow(),
              if (_hasError) ...[
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Invalid code. Please try again.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Verify',
                trailingIcon: Icons.check,
                onPressed: _canSubmit ? _handleVerify : null,
                isLoading: _isVerifying,
              ),
              const SizedBox(height: 20),
              _buildResendRow(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify\nyour email',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.4,
          ),
          children: [
            const TextSpan(text: 'We sent a 6-digit code to '),
            TextSpan(
              text: _maskedEmail(),
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: '. Enter it below to continue.'),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_codeLength, (i) => _buildDigitBox(i)),
    );
  }

  Widget _buildDigitBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: index == 0 ? _codeLength : 1,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: filled ? AppColors.surface : AppColors.inputFill,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _hasError
                  ? AppColors.error
                  : (filled ? AppColors.primaryMedium : AppColors.border),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: _hasError ? AppColors.error : AppColors.primaryMedium,
              width: 2,
            ),
          ),
        ),
        onChanged: (v) => _onDigitChanged(index, v),
      ),
    );
  }

  Widget _buildResendRow() {
    final canResend = _secondsLeft == 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't get the code? ",
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        GestureDetector(
          onTap: canResend ? _handleResend : null,
          child: Text(
            canResend ? 'Resend' : 'Resend in ${_secondsLeft}s',
            style: TextStyle(
              color: canResend ? AppColors.primaryMedium : AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
