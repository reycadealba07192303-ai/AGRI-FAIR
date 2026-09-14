import 'package:flutter/material.dart';

class AgriFairLogo extends StatelessWidget {
  final double size;

  const AgriFairLogo({super.key, this.size = 1.0});

  @override
  Widget build(BuildContext context) {
    // This widget is used on the OTP verification screen.
    // Use the official system logo (not any product mock image).
    return Image.asset(
      'assets/brand/agrifair_logo.png',
      width: 86 * size,
      height: 86 * size,
      fit: BoxFit.contain,
    );
  }
}
