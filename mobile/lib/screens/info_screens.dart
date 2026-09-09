import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/clay.dart';

class PolicyPrivacyScreen extends StatelessWidget {
  const PolicyPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Policy & Privacy',
      children: const [
        _InfoBlock(
          heading: 'What AgriFair is for',
          body:
              'AgriFair connects buyers with verified rice sellers. We collect '
              'only what is needed to run your account, deliver orders, and '
              'keep payments clear between you and the shop.',
        ),
        _InfoBlock(
          heading: 'Information we keep',
          body:
              'Your name, email, contact number, delivery addresses, order '
              'history, and payment references (such as GCash receipts) are '
              'stored so sellers can fulfill your purchase and so you can '
              'track it.',
        ),
        _InfoBlock(
          heading: 'How we use it',
          body:
              'We use your details to authenticate you, process orders, show '
              'delivery updates, support chat with sellers, and improve the '
              'marketplace. We do not sell your personal data.',
        ),
        _InfoBlock(
          heading: 'Who can see it',
          body:
              'Sellers see what they need for your order (name, contact, '
              'address, payment proof). Platform admins may review accounts '
              'and disputes. Riders see delivery details for assigned orders.',
        ),
        _InfoBlock(
          heading: 'Your choices',
          body:
              'You can update addresses, sign out, and request password '
              'resets through email. For account deletion or data questions, '
              'contact AgriFair support through the Messages tab or your '
              'registered email.',
        ),
        _InfoBlock(
          heading: 'Security',
          body:
              'Passwords are handled through secure authentication. Reset '
              'codes expire quickly. Keep your email and device secure — '
              'anyone with access to them can request a password change.',
        ),
      ],
    );
  }
}

class AboutSystemScreen extends StatelessWidget {
  const AboutSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'About System',
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.raised,
            ),
            child: Image.asset(
              'assets/brand/agrifair_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'AgriFair',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mobile buyer app · Version 0.1.0',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 22),
        const _InfoBlock(
          heading: 'What this app does',
          body:
              'Browse rice from verified shops, message sellers, place orders, '
              'pay with cash on delivery or GCash, and follow delivery until '
              'your rice arrives.',
        ),
        const _InfoBlock(
          heading: 'Built for',
          body:
              'Buyers who want farm-sourced rice with clear product details, '
              'honest stock, and a simple checkout — without leaving the '
              'Philippine marketplace context AgriFair was designed for.',
        ),
        const _InfoBlock(
          heading: 'Capstone project',
          body:
              'AgriFair is an academic capstone system spanning this mobile '
              'buyer app, a seller/admin web portal, and a shared backend for '
              'orders, chat, and notifications.',
        ),
      ],
    );
  }
}

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: ClayIconButton(
            icon: Icons.arrow_back_rounded,
            size: 38,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        leadingWidth: 62,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: children,
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClayCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        shadows: AppShadows.subtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textBody,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
