import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'ongoing_orders_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  bool _listenerRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerRegistered) {
      _listenerRegistered = true;
      final userModel = UserModel.of(context);
      final notifModel = NotificationModel.of(context);
      userModel.listenToStatusChanges((orderNumber, newStatus) {
        _onOrderStatusChanged(notifModel, orderNumber, newStatus);
      });
    }
  }

  void _onOrderStatusChanged(
    NotificationModel nm,
    String orderNumber,
    String newStatus,
  ) {
    String title;
    String body;
    NotificationType type;

    switch (newStatus) {
      case 'Confirmed':
        title = 'Order Confirmed!';
        body =
            'Your order $orderNumber has been confirmed by our team and is being prepared.';
        type = NotificationType.orderConfirmed;
      case 'Preparing':
        title = 'Order Being Prepared';
        body =
            'Good news! Your order $orderNumber is being carefully packed and prepared for delivery.';
        type = NotificationType.orderPacked;
      case 'Out for Delivery':
        title = 'Out for Delivery!';
        body =
            'Your order $orderNumber is on its way! The courier is heading to your location.';
        type = NotificationType.outForDelivery;
      case 'Delivered':
        title = 'Order Delivered!';
        body =
            'Your order $orderNumber has arrived. We hope you enjoy your premium rice!';
        type = NotificationType.delivered;
      case 'Cancelled':
        title = 'Order Cancelled';
        body =
            'Your order $orderNumber has been cancelled. Please contact support if you need assistance.';
        type = NotificationType.orderCancelled;
      default:
        return;
    }

    nm.add(AppNotification(
      id: 'status_${orderNumber}_$newStatus',
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      referenceId: orderNumber,
    ));
  }

  void _onTabTap(int i) {
    if (i == 1) ChatModel.of(context).markAllRead();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final unreadChat = ChatModel.of(context).unreadCount;
    final user = UserModel.of(context);
    final activeOrders = user.orders
        .where((o) => o.status != 'Delivered' && o.status != 'Cancelled')
        .length;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          ChatScreen(),
          OngoingOrdersScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: _onTabTap,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.home_rounded, size: 24),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 24),
                    if (unreadChat > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            borderRadius:
                                BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Text(
                            unreadChat > 9 ? '9+' : '$unreadChat',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.chat_bubble_rounded, size: 24),
              ),
              label: 'Message',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 24),
                    if (activeOrders > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryMedium,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Text(
                            activeOrders > 9 ? '9+' : '$activeOrders',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.receipt_long_rounded, size: 24),
              ),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.person_outline_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.person_rounded, size: 24),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
