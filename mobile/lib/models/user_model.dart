import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class OrderItem {
  final String productName;
  final String weight;
  final int quantity;
  final double price;
  final Color tagColor;

  const OrderItem({
    required this.productName,
    required this.weight,
    required this.quantity,
    required this.price,
    required this.tagColor,
  });
}

class OrderRecord {
  final String orderNumber;
  final DateTime date;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String paymentMethod;
  final String address;
  final String customerName;
  final String contactNumber;
  String status;

  OrderRecord({
    required this.orderNumber,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentMethod,
    required this.address,
    required this.customerName,
    required this.contactNumber,
    this.status = 'Pending',
  });

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
}

class UserModel extends ChangeNotifier {
  /// The signed-in account as the backend sees it. Null means signed out, and
  /// every screen that needs a session should read it rather than assume one.
  AuthUser? _account;

  AuthUser? get account => _account;
  bool get isSignedIn => _account != null;
  bool get isEmailVerified => _account?.emailVerified ?? false;

  String email = '';
  String fullName = '';
  String contactNumber = '';
  String deliveryAddress = '';
  String gcashNumber = '';
  String profileImagePath = '';
  final List<OrderRecord> _orders = [];
  final List<void Function(String, String)> _statusListeners = [];

  List<OrderRecord> get orders => List.unmodifiable(_orders);

  String get displayName {
    if (fullName.isNotEmpty) return fullName;
    if (email.isNotEmpty) {
      final n = email.split('@').first;
      return n[0].toUpperCase() + n.substring(1);
    }
    return 'User';
  }

  String get avatarLetter {
    final n = displayName;
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  double get totalSpent => _orders.fold(0.0, (s, o) => s + o.total);

  void initialize({required String email, String fullName = ''}) {
    this.email = email;
    this.fullName = fullName;
    notifyListeners();
  }

  /// Fills the profile from a real account. The screens already read
  /// `fullName` and `contactNumber`, so those are kept in step with it.
  void applyAccount(AuthUser user) {
    _account = user;
    email = user.email;
    fullName = user.name;
    if (user.contact.isNotEmpty) contactNumber = user.contact;
    if (user.avatarUrl.isNotEmpty) profileImagePath = user.avatarUrl;
    notifyListeners();
  }

  /// Forgets who is signed in, on the way out.
  void clearAccount() {
    _account = null;
    email = '';
    fullName = '';
    notifyListeners();
  }

  void updateProfile({
    String? fullName,
    String? contactNumber,
    String? deliveryAddress,
    String? gcashNumber,
    String? profileImagePath,
  }) {
    if (fullName != null) this.fullName = fullName;
    if (contactNumber != null) this.contactNumber = contactNumber;
    if (deliveryAddress != null) this.deliveryAddress = deliveryAddress;
    if (gcashNumber != null) this.gcashNumber = gcashNumber;
    if (profileImagePath != null) this.profileImagePath = profileImagePath;
    notifyListeners();
  }

  void addOrder(OrderRecord order) {
    _orders.insert(0, order);
    notifyListeners();
    _scheduleAutoProgress(order.orderNumber);
  }

  void updateOrderStatus(String orderNumber, String newStatus) {
    final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
    if (idx < 0) return;
    _orders[idx].status = newStatus;
    for (final cb in _statusListeners) {
      cb(orderNumber, newStatus);
    }
    notifyListeners();
  }

  void listenToStatusChanges(void Function(String, String) callback) {
    _statusListeners.add(callback);
  }

  void _scheduleAutoProgress(String orderNumber) {
    Future.delayed(const Duration(seconds: 5), () {
      final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
      if (idx < 0 || _orders[idx].status != 'Pending') return;
      updateOrderStatus(orderNumber, 'Confirmed');
    });
    Future.delayed(const Duration(seconds: 20), () {
      final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
      if (idx < 0 || _orders[idx].status != 'Confirmed') return;
      updateOrderStatus(orderNumber, 'Preparing');
    });
    Future.delayed(const Duration(seconds: 45), () {
      final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
      if (idx < 0 || _orders[idx].status != 'Preparing') return;
      updateOrderStatus(orderNumber, 'Out for Delivery');
    });
    Future.delayed(const Duration(seconds: 90), () {
      final idx = _orders.indexWhere((o) => o.orderNumber == orderNumber);
      if (idx < 0 || _orders[idx].status != 'Out for Delivery') return;
      updateOrderStatus(orderNumber, 'Delivered');
    });
  }

  void reset() {
    _account = null;
    email = '';
    fullName = '';
    contactNumber = '';
    deliveryAddress = '';
    gcashNumber = '';
    profileImagePath = '';
    _orders.clear();
    _statusListeners.clear();
    notifyListeners();
  }

  static UserModel of(BuildContext context) => UserNotifier.of(context);
}

class UserNotifier extends InheritedNotifier<UserModel> {
  const UserNotifier({
    super.key,
    required UserModel model,
    required super.child,
  }) : super(notifier: model);

  static UserModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserNotifier>()!.notifier!;
}
