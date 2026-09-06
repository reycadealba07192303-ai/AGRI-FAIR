import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/cart_service.dart';
import 'product.dart';

/// The cart, held on the server.
///
/// It used to live only here, in memory. That meant checkout - which reads the
/// server's cart - always found it empty, and a cart vanished on reinstall and
/// never followed anyone to another device.
///
/// Every operation replaces the whole cart with what the server returns, which
/// is rebuilt against live products, so a price that moved or an item that
/// sold out shows up without the app having to ask separately.
class CartModel extends ChangeNotifier {
  static CartModel of(BuildContext context) => CartNotifier.of(context);

  ServerCart _cart = ServerCart.empty;
  bool _loading = false;
  String? _error;

  ServerCart get cart => _cart;
  List<ServerCartItem> get items => _cart.items;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Sacks, not kilograms - what the badge on the cart icon counts.
  int get totalCount => _cart.sackCount;
  double get subtotal => _cart.subtotal;
  double get deliveryFee => _cart.deliveryFee;
  double get total => _cart.total;

  bool get hasUnavailable => _cart.hasUnavailable;
  List<String> get unavailable => _cart.unavailable;

  /// Loads the cart for whoever just signed in.
  ///
  /// Failure is quiet: an empty cart on a bad connection is the same thing the
  /// person sees anyway, and the screens that matter refetch.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      _cart = await CartService.instance.fetch();
      _error = null;
    } on ApiException catch (err) {
      _error = err.message;
    }

    _loading = false;
    notifyListeners();
  }

  /// Empties the local copy without touching the server - used on sign-out,
  /// where the cart belongs to the account being left behind.
  void forget() {
    _cart = ServerCart.empty;
    _error = null;
    notifyListeners();
  }

  Future<void> _run(Future<ServerCart> Function() action) async {
    _loading = true;
    notifyListeners();

    try {
      _cart = await action();
      _error = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Adds sacks of one weight. Throws [ApiException] when the seller does not
  /// have the stock, so the screen can show the server's own words.
  Future<void> addItem(Product product, WeightTier tier, int quantity) {
    return _run(() => CartService.instance.add(
          productId: product.id,
          weightKg: tier.weightKg,
          quantity: quantity,
        ));
  }

  Future<void> setQuantity(ServerCartItem item, int quantity) {
    return _run(() => CartService.instance.setQuantity(
          productId: item.productId,
          weightKg: item.weightKg,
          quantity: quantity,
        ));
  }

  Future<void> increment(ServerCartItem item) =>
      setQuantity(item, item.quantity + 1);

  /// Down to zero removes the line, which is what the server does with it.
  Future<void> decrement(ServerCartItem item) =>
      setQuantity(item, item.quantity - 1);

  Future<void> removeItem(ServerCartItem item) {
    return _run(() => CartService.instance.remove(
          productId: item.productId,
          weightKg: item.weightKg,
        ));
  }

  Future<void> clear() => _run(() => CartService.instance.clear());
}

class CartNotifier extends InheritedNotifier<CartModel> {
  const CartNotifier({
    super.key,
    required CartModel model,
    required super.child,
  }) : super(notifier: model);

  static CartModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CartNotifier>()!.notifier!;
}
