import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cart.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';
import 'order_success_screen.dart';

class _PaymentOption {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  const _PaymentOption(this.id, this.label, this.subtitle, this.icon);
}

const _paymentOptions = [
  _PaymentOption(
    'cod',
    'Cash on Delivery',
    'Pay when your order arrives',
    Icons.money_rounded,
  ),
  _PaymentOption(
    'gcash',
    'GCash',
    'Pay via GCash mobile wallet',
    Icons.phone_android_rounded,
  ),
  _PaymentOption(
    'bank',
    'Paymongo',
    'Transfer to our bank account',
    Icons.account_balance_rounded,
  ),
];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentId = 'cod';
  bool _placing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _placing = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final cart = CartModel.of(context);
    final user = UserModel.of(context);
    final paymentLabel = _paymentOptions
        .firstWhere((o) => o.id == _paymentId)
        .label;
    final now = DateTime.now();
    final orderNumber =
        'AGF-${(now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';

    final record = OrderRecord(
      orderNumber: orderNumber,
      date: now,
      items: cart.items
          .map(
            (i) => OrderItem(
              productName: i.product.name,
              weight: i.weightOption.label,
              quantity: i.quantity,
              price: i.itemTotal,
              tagColor: i.product.tagColor,
            ),
          )
          .toList(),
      subtotal: cart.subtotal,
      deliveryFee: cart.deliveryFee,
      total: cart.total,
      paymentMethod: paymentLabel,
      customerName: _nameCtrl.text.trim(),
      contactNumber: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );

    user.addOrder(record);
    cart.clear();

    final nm = NotificationModel.of(context);
    nm.add(
      AppNotification(
        id: 'notif_confirmed_$orderNumber',
        title: 'Order Confirmed!',
        body:
            'Your order $orderNumber has been placed successfully. We\'ll start preparing it right away!',
        type: NotificationType.orderConfirmed,
        timestamp: DateTime.now(),
        referenceId: orderNumber,
      ),
    );
    nm.add(
      AppNotification(
        id: 'notif_payment_$orderNumber',
        title: 'Payment Confirmed',
        body:
            '$paymentLabel payment for $orderNumber (₱${record.total.toInt()}) has been confirmed.',
        type: NotificationType.paymentConfirmed,
        timestamp: DateTime.now(),
        referenceId: orderNumber,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderNumber: orderNumber,
          customerName: _nameCtrl.text.trim(),
          total: record.total,
          paymentMethod: paymentLabel,
          address: _addressCtrl.text.trim(),
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartModel.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primaryDark,
            size: 18,
          ),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Delivery info ───────────────────────────────────────
                  _sectionTitle(
                    Icons.local_shipping_outlined,
                    'Delivery Information',
                  ),
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. Juan dela Cruz',
                    icon: Icons.person_outline_rounded,
                    required: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _phoneCtrl,
                    label: 'Contact Number',
                    hint: '09XX XXX XXXX',
                    icon: Icons.phone_outlined,
                    required: true,
                    keyboardType: TextInputType.phone,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your contact number';
                      }
                      if (v.replaceAll(RegExp(r'\s'), '').length < 10) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _addressCtrl,
                    label: 'Complete Address',
                    hint: 'House No., Street, Barangay, City, Province',
                    icon: Icons.location_on_outlined,
                    required: true,
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your complete address'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Payment method ──────────────────────────────────────
                  _sectionTitle(Icons.payment_outlined, 'Mode of Payment'),
                  const SizedBox(height: 14),
                  ..._paymentOptions.map(
                    (opt) => _PaymentTile(
                      opt: opt,
                      selected: _paymentId == opt.id,
                      onTap: () => setState(() => _paymentId = opt.id),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Order notes ─────────────────────────────────────────
                  _sectionTitle(Icons.note_alt_outlined, 'Order Notes'),
                  const SizedBox(height: 14),
                  _field(
                    ctrl: _notesCtrl,
                    label: 'Notes (optional)',
                    hint: 'Special instructions, delivery landmark, etc.',
                    icon: Icons.edit_note_rounded,
                    required: false,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // ── Order summary ───────────────────────────────────────
                  _sectionTitle(Icons.receipt_long_outlined, 'Order Summary'),
                  const SizedBox(height: 14),
                  _OrderSummaryCard(cart: cart),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _BottomBar(cart: cart, placing: _placing, onPlace: _placeOrder),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required bool required,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            children: required
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primaryMedium, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primaryMedium,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final _PaymentOption opt;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentTile({
    required this.opt,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryDark.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : AppColors.background,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                opt.icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    opt.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primaryDark : AppColors.border,
                  width: 2,
                ),
                color: selected ? AppColors.primaryDark : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final CartModel cart;
  const _OrderSummaryCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.product.tagColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.rice_bowl_rounded,
                      color: item.product.tagColor.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.weightOption.label}  ×  ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱${item.itemTotal.toInt()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _summaryRow('Subtotal', '₱${cart.subtotal.toInt()}'),
                const SizedBox(height: 6),
                _summaryRow('Delivery Fee', '₱${cart.deliveryFee.toInt()}'),
                const SizedBox(height: 10),
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                _summaryRow(
                  'Total Amount',
                  '₱${cart.total.toInt()}',
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 17 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? AppColors.primaryDark : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final CartModel cart;
  final bool placing;
  final VoidCallback onPlace;
  const _BottomBar({
    required this.cart,
    required this.placing,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                Text(
                  '₱${cart.total.toInt()}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: placing ? null : onPlace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryDark.withValues(
                    alpha: 0.55,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: placing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
