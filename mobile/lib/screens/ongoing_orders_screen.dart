import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'order_detail_screen.dart';

class OngoingOrdersScreen extends StatelessWidget {
  const OngoingOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = UserModel.of(context)
        .orders
        .where((o) => o.status != 'Delivered' && o.status != 'Cancelled')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ongoing Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            if (orders.isNotEmpty)
              Text(
                '${orders.length} active order${orders.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: orders.isEmpty
          ? const _EmptyOngoing()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _OngoingOrderCard(order: orders[i]),
            ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _OngoingOrderCard extends StatelessWidget {
  final OrderRecord order;
  const _OngoingOrderCard({required this.order});

  static const _statusSteps = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    final stepIndex = _statusSteps.indexOf(order.status).clamp(0, 4);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Colored status accent bar ──────────────────────────────
              Container(height: 4, color: color),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: order number + date + status badge ──────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 11,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(order.date),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(status: order.status, color: color),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Products section ───────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < order.items.take(3).length;
                              i++) ...[
                            _ProductRow(item: order.items[i]),
                            if (i < order.items.take(3).length - 1 ||
                                order.items.length > 3)
                              const Divider(
                                  height: 1, color: AppColors.border),
                          ],
                          if (order.items.length > 3)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${order.items.length - 3} more item${order.items.length - 3 > 1 ? 's' : ''} — tap to view all',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Status stepper ─────────────────────────────────
                    _StatusStepper(currentStep: stepIndex),
                    const SizedBox(height: 12),

                    // ── ETA row ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              size: 15, color: color),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _etaText(order.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Footer: payment + total + view ─────────────────
                    Row(
                      children: [
                        // Payment method pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primaryDark
                                    .withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _paymentIcon(order.paymentMethod),
                                size: 13,
                                color: AppColors.primaryMedium,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                order.paymentMethod,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                            Text(
                              '₱${order.total.toInt()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 11, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'Pending' => const Color(0xFF64748B),
        'Confirmed' => const Color(0xFF2563EB),
        'Preparing' => const Color(0xFFD97706),
        'Out for Delivery' => const Color(0xFF7C3AED),
        'Delivered' => const Color(0xFF16A34A),
        _ => AppColors.error,
      };

  String _etaText(String status) => switch (status) {
        'Pending' => 'Waiting for store confirmation...',
        'Confirmed' => 'Estimated delivery: 45 – 60 minutes',
        'Preparing' => 'Estimated delivery: 20 – 40 minutes',
        'Out for Delivery' => 'Your order is arriving soon!',
        'Delivered' => 'Delivered successfully',
        _ => 'Checking delivery status...',
      };

  IconData _paymentIcon(String method) {
    if (method.toLowerCase().contains('gcash')) {
      return Icons.phone_android_rounded;
    }
    if (method.toLowerCase().contains('bank')) {
      return Icons.account_balance_rounded;
    }
    return Icons.money_rounded;
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $h:$m $p';
  }
}

// ── Product row (inside card) ─────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  final OrderItem item;
  const _ProductRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.rice_bowl_rounded,
              size: 22,
              color: item.tagColor.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _chip(item.weight, Icons.monitor_weight_outlined),
                    const SizedBox(width: 6),
                    _chip('×${item.quantity}', Icons.shopping_bag_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₱${item.price.toInt()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primaryMedium),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status stepper ────────────────────────────────────────────────────────────

class _StatusStepper extends StatelessWidget {
  final int currentStep;
  const _StatusStepper({required this.currentStep});

  static const _labels = [
    'Pending',
    'Confirmed',
    'Preparing',
    'Delivery',
    'Delivered',
  ];

  static const _icons = [
    Icons.hourglass_top_rounded,
    Icons.check_circle_outline_rounded,
    Icons.inventory_2_outlined,
    Icons.local_shipping_outlined,
    Icons.home_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 11),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.primaryDark
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        }

        final stepIdx = i ~/ 2;
        final done = stepIdx < currentStep;
        final isActive = stepIdx == currentStep;

        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primaryDark
                    : isActive
                        ? AppColors.primaryDark.withValues(alpha: 0.12)
                        : AppColors.border.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                        color: AppColors.primaryDark,
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : Icon(
                        _icons[stepIdx],
                        size: 12,
                        color: isActive
                            ? AppColors.primaryDark
                            : AppColors.textMuted,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[stepIdx],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight:
                    (done || isActive) ? FontWeight.w700 : FontWeight.w500,
                color: (done || isActive)
                    ? AppColors.textDark
                    : AppColors.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyOngoing extends StatelessWidget {
  const _EmptyOngoing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 56,
                color: AppColors.primaryLight.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Ongoing Orders',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your active orders will appear here\nright after you place an order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primaryDark.withValues(alpha: 0.08)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.primaryMedium),
                  SizedBox(width: 8),
                  Text(
                    'Place an order to start tracking it here',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
