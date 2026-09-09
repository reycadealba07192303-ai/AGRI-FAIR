import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// Picks one of a shop's listings to drop into a conversation.
///
/// A buyer asking "meron pa po ba nito?" and a seller answering "ito po ang
/// meron" are describing something neither can see. Sending the listing itself
/// ends the guessing: the same picture, the same price, the same stock.
Future<Product?> showProductPicker(
  BuildContext context, {
  required int sellerUserId,
  required String shopName,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductPicker(
      sellerUserId: sellerUserId,
      shopName: shopName,
    ),
  );
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.sellerUserId, required this.shopName});

  final int sellerUserId;
  final String shopName;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  List<Product> _products = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final products = await SellerService.instance.products(widget.sellerUserId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              height: 4,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Send a product',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: const [
          ClaySkeleton(height: 76, radius: AppRadius.md),
          SizedBox(height: 10),
          ClaySkeleton(height: 76, radius: AppRadius.md),
          SizedBox(height: 10),
          ClaySkeleton(height: 76, radius: AppRadius.md),
        ],
      );
    }

    if (_error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load the listings',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_products.isEmpty) {
      return const ClayEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nothing to send',
        message: 'This shop has no listings in stock right now.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      itemCount: _products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final product = _products[i];

        return ClayCard(
          padding: const EdgeInsets.all(10),
          radius: AppRadius.md,
          onTap: () => Navigator.of(context).pop(product),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  height: 54,
                  width: 54,
                  child: product.primaryImageUrl.isEmpty
                      ? Container(
                          color: AppColors.surfaceSunken,
                          child: const Icon(Icons.rice_bowl_rounded,
                              color: AppColors.primaryLight, size: 22),
                        )
                      : CachedNetworkImage(
                          imageUrl: product.primaryImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceSunken,
                            child: const Icon(Icons.rice_bowl_rounded,
                                color: AppColors.primaryLight, size: 22),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₱${product.startingPrice.toStringAsFixed(0)} per kg  ·  '
                      '${product.stock} kg left',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.send_rounded,
                  size: 17, color: AppColors.primaryMedium),
            ],
          ),
        );
      },
    );
  }
}
