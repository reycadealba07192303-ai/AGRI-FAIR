import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/cart.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'checkout_screen.dart';

/// What is in the cart, read from the server every time it is opened.
///
/// It used to trust the single fetch done at sign-in. When that one call failed
/// - a dropped connection, a server still waking up - the cart stayed empty for
/// the rest of the session and the screen said so, which is how a full cart
/// came to read "Your cart is empty" on the way to checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: reading the cart out of the tree needs a context
    // that is mounted, and refresh() notifies listeners as it starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CartModel.of(context).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartModel.of(context);
    final items = cart.items;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.primaryDark, size: 18),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Cart',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            if (items.isNotEmpty)
              Text(
                '${items.length} item${items.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _body(cart, items),
    );
  }

  Widget _body(CartModel cart, List<ServerCartItem> items) {
    // Never loaded and still trying: skeletons, not an empty cart. The two are
    // not the same thing and must not look the same.
    if (!cart.isLoaded && cart.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          ClaySkeleton(height: 104, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 104, radius: AppRadius.lg),
        ],
      );
    }

    // Never loaded and the attempt failed: say what went wrong and offer the
    // retry, rather than claiming the cart is empty on the server's behalf.
    if (!cart.isLoaded && cart.error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Cannot load your cart',
        message: cart.error!,
        actionLabel: 'Try again',
        onAction: () => cart.refresh(),
      );
    }

    if (items.isEmpty) {
      return _EmptyCart(onBrowse: () => Navigator.pop(context));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: cart.refresh,
            color: AppColors.primaryMedium,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CartItemCard(item: items[i]),
            ),
          ),
        ),
        _OrderSummaryBar(cart: cart),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyCart({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined,
                  size: 48,
                  color: AppColors.primaryLight.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add rice products to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onBrowse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              child: const Text('Browse Products',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final ServerCartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = CartModel.of(context);

    return ClayCard(
      padding: const EdgeInsets.all(14),
      shadows: AppShadows.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  height: 64,
                  width: 64,
                  child: item.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.surfaceSunken,
                          child: const Icon(
                            Icons.rice_bowl_outlined,
                            color: AppColors.primaryLight,
                            size: 28,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceSunken,
                            child: const Icon(
                              Icons.rice_bowl_outlined,
                              color: AppColors.primaryLight,
                              size: 28,
                            ),
                          ),
                          placeholder: (_, _) =>
                              Container(color: AppColors.surfaceSunken),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            item.weightLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              '₱${item.unitPrice.toInt()} each',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, cart),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // The line total and the stepper sit on their own row. Sharing one
          // with the name and the weight chip ran past the screen edge as soon
          // as a sack cost four figures.
          Row(
            children: [
              Text(
                '₱${item.lineTotal.toInt()}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              _qtyBtn(Icons.remove_rounded, () => cart.decrement(item)),
              SizedBox(
                width: 40,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _qtyBtn(Icons.add_rounded, () => cart.increment(item)),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, CartModel cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Item',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        content: Text(
          'Remove ${item.name} (${item.weightLabel}) from cart?',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              cart.removeItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
            ),
            child: const Text('Remove',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: Colors.white),
      ),
    );
  }
}

class _OrderSummaryBar extends StatelessWidget {
  final CartModel cart;
  const _OrderSummaryBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _row('Subtotal', '₱${cart.subtotal.toInt()}'),
            const SizedBox(height: 6),
            _row('Delivery Fee', '₱${cart.deliveryFee.toInt()}'),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            _row('Total', '₱${cart.total.toInt()}', bold: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Proceed to Checkout',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 20 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? AppColors.primaryDark : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
