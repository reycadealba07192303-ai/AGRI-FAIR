import 'package:flutter/material.dart';
import 'rice_product.dart';

class CartItem {
  final RiceProduct product;
  final RiceWeightOption weightOption;
  int quantity;

  CartItem({
    required this.product,
    required this.weightOption,
    this.quantity = 1,
  });

  String get id => '${product.name}__${weightOption.label}';
  double get itemTotal => weightOption.price * quantity;
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  static CartModel of(BuildContext context) => CartNotifier.of(context);

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalCount => _items.fold(0, (s, i) => s + i.quantity);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.itemTotal);
  double get deliveryFee => _items.isEmpty ? 0 : 80;
  double get total => subtotal + deliveryFee;

  void addItem(RiceProduct product, RiceWeightOption option, int quantity) {
    final idx = _items.indexWhere(
      (i) => i.product.name == product.name && i.weightOption.label == option.label,
    );
    if (idx >= 0) {
      _items[idx].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, weightOption: option, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void increment(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _items[idx].quantity++;
      notifyListeners();
    }
  }

  void decrement(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity--;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
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
