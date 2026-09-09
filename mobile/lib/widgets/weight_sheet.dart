import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// What the buyer settled on: a sack size and how many of them.
class WeightChoice {
  const WeightChoice({required this.tier, required this.quantity});

  final WeightTier tier;
  final int quantity;
}

/// Asks for the sack size and the count, at the moment of buying.
///
/// This used to sit on the product page itself, which meant every visitor had
/// to step past a decision they had not made yet - and the page carried a
/// running total for a purchase nobody had committed to. Now the page is about
/// the rice, and the sheet is about the purchase.
///
/// Returns null when the buyer backs out.
Future<WeightChoice?> showWeightSheet(
  BuildContext context, {
  required Product product,
  required String confirmLabel,
}) {
  return showModalBottomSheet<WeightChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WeightSheet(product: product, confirmLabel: confirmLabel),
  );
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.product, required this.confirmLabel});

  final Product product;
  final String confirmLabel;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final List<WeightOption> _options = widget.product.weightOptions;

  WeightOption? _selected;
  int _quantity = 1;

  /// Why the last tap did nothing. Shown until another size is tapped, the way
  /// a shop app tells you an option is gone rather than leaving a dead tile.
  String? _blocked;

  @override
  void initState() {
    super.initState();
    _selected = widget.product.firstAvailableOption;
  }

  /// How many sacks of the chosen size the seller can still cover.
  int get _maxQuantity {
    final option = _selected;
    if (option == null) return 1;
    final fits = (widget.product.stock / option.weightKg).floor();
    return fits < 1 ? 1 : fits;
  }

  double get _total => (_selected?.price ?? 0) * _quantity;

  void _choose(WeightOption option) {
    if (!option.available) {
      setState(() => _blocked = option.unavailableReason);
      return;
    }

    setState(() {
      _selected = option;
      _blocked = null;
      // A count that fit the last size may not fit this one - two 50 kg sacks
      // out of 60 kg of stock is not an order the seller can fill.
      if (_quantity > _maxQuantity) _quantity = _maxQuantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canBuy = _selected != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grip(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summary(),
                      const SizedBox(height: 20),
                      _weights(),
                      const SizedBox(height: 18),
                      _quantityRow(),
                    ],
                  ),
                ),
              ),
              _confirmBar(canBuy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grip() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      height: 4,
      width: 42,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }

  /// The picture, the live price and what is left - the three things that
  /// change what the buyer picks.
  Widget _summary() {
    final product = widget.product;
    final selected = _selected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClaySunken(
          padding: EdgeInsets.zero,
          radius: AppRadius.md,
          child: SizedBox(
            height: 84,
            width: 84,
            child: product.primaryImageUrl.isEmpty
                ? const Icon(Icons.rice_bowl_rounded,
                    color: AppColors.primaryLight, size: 30)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CachedNetworkImage(
                      imageUrl: product.primaryImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(
                          Icons.rice_bowl_rounded,
                          color: AppColors.primaryLight),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected == null
                    ? 'Sold out'
                    : '₱${selected.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                selected == null
                    ? product.name
                    : 'per ${selected.label} sack',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.stock > 0
                    ? '${product.stock} kg left in stock'
                    : 'No stock left',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: product.stock > 0
                      ? AppColors.textBody
                      : AppColors.error,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Icon(Icons.close_rounded,
                color: AppColors.textMuted, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _weights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select weight',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in _options)
              _WeightTile(
                option: option,
                selected: identical(option, _selected),
                onTap: () => _choose(option),
              ),
          ],
        ),
        if (_blocked != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_blocked. Select another option.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _quantityRow() {
    final atMax = _quantity >= _maxQuantity;

    return Row(
      children: [
        const Text(
          'Quantity',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        if (_selected != null && atMax) ...[
          const SizedBox(width: 8),
          Text(
            'max $_maxQuantity',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const Spacer(),
        _Stepper(
          icon: Icons.remove_rounded,
          onTap: _quantity > 1 ? () => setState(() => _quantity--) : null,
        ),
        SizedBox(
          width: 46,
          child: Text(
            '$_quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ),
        _Stepper(
          icon: Icons.add_rounded,
          onTap: _selected == null || atMax
              ? null
              : () => setState(() => _quantity++),
        ),
      ],
    );
  }

  Widget _confirmBar(bool canBuy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canBuy)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    '₱${_total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ClayButton(
            label: canBuy ? widget.confirmLabel : 'Nothing available to buy',
            onPressed: canBuy
                ? () => Navigator.of(context).pop(
                      WeightChoice(tier: _selected!.tier, quantity: _quantity),
                    )
                : null,
          ),
        ],
      ),
    );
  }
}

/// One size. Unavailable ones stay on the list and stay flat: seeing that 50 kg
/// exists but cannot be had today is information, and hiding it is not.
class _WeightTile extends StatelessWidget {
  const _WeightTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final WeightOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = option.available;
    final discount = option.tier.discountPercent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: !available
              ? AppColors.background
              : selected
                  ? AppColors.primaryMedium
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: !available
                ? AppColors.border
                : selected
                    ? AppColors.primaryMedium
                    : AppColors.border,
          ),
          // No shadow when it cannot be tapped: a flat tile reads as off
          // before anybody tries it.
          boxShadow: available && !selected ? AppShadows.subtle : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: !available
                    ? AppColors.textMuted
                    : selected
                        ? Colors.white
                        : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              available ? '₱${option.price.toStringAsFixed(0)}' : 'Unavailable',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: !available
                    ? AppColors.textMuted
                    : selected
                        ? Colors.white70
                        : AppColors.primaryMedium,
              ),
            ),
            if (available && discount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '-${discount.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
          boxShadow: enabled ? AppShadows.subtle : null,
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? AppColors.primaryDark : AppColors.textMuted,
        ),
      ),
    );
  }
}
