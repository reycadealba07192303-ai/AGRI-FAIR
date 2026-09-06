import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgriFairLogo extends StatelessWidget {
  final double size;

  const AgriFairLogo({super.key, this.size = 1.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/products/AI, 3rd Draft(1).png',
          width: 40 * size,
          height: 40 * size,
          fit: BoxFit.contain,
        ),
        SizedBox(width: 10 * size),
        Text(
          'AgriFair',
          style: TextStyle(
            fontSize: 24 * size,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
