import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'dashboard/seller_dashboard_screen.dart';
import 'products/seller_products_screen.dart';
import 'orders/seller_orders_screen.dart';
import 'reports/seller_reports_screen.dart';
import 'profile/seller_profile_screen.dart';
import '../auth/login_screen.dart';
import '../../widgets/staff_shell.dart';

class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key});

  @override
  State<SellerMainScreen> createState() => SellerMainScreenState();

  /// Lets nested screens (e.g. Profile shortcuts) switch tabs.
  static SellerMainScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<SellerMainScreenState>();
}

class SellerMainScreenState extends State<SellerMainScreen> {
  static const tabDashboard = 0;
  static const tabProducts = 1;
  static const tabOrders = 2;
  static const tabReports = 3;
  static const tabProfile = 4;

  int _currentIndex = 0;

  // Opening a tab loads it fresh, like opening the page on the website.
  final Map<int, int> _opened = {};

  void goTo(int index) {
    setState(() {
      if (index != _currentIndex) _opened[index] = (_opened[index] ?? 0) + 1;
      _currentIndex = index;
    });
  }

  bool _redirecting = false;

  static const List<Widget> _screens = [
    SellerDashboardScreen(),
    SellerProductsScreen(),
    SellerOrdersScreen(),
    SellerReportsScreen(),
    SellerProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Check if user is still authenticated and has seller role
        if (!authProvider.isAuthenticated || 
            authProvider.user?.isSeller != true ||
            !authProvider.user!.isApprovedSeller) {
          if (!_redirecting) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            });
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authProvider.user!;
        return StaffShell(
          brand: 'SELLER',
          place: 'Seller Center',
          userName: user.name,
          userRole: 'Seller',
          index: _currentIndex,
          onSelect: goTo,
          tabs: [
            for (var i = 0; i < _screens.length; i++) (_navIcons[i], _navLabels[i], _screens[i]),
          ],
          body: IndexedStack(
            index: _currentIndex,
            children: [
              for (var i = 0; i < _screens.length; i++) KeyedSubtree(key: ValueKey('tab-$i-${_opened[i] ?? 0}'), child: _screens[i]),
            ],
          ),
        );
      },
    );
  }

  static const _navIcons = [Icons.dashboard, Icons.inventory_2, Icons.shopping_cart, Icons.analytics, Icons.person];
  static const _navLabels = ['Home', 'Products', 'Orders', 'Reports', 'More'];
}
