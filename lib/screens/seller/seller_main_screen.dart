import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'dashboard/seller_dashboard_screen.dart';
import 'products/seller_products_screen.dart';
import 'orders/seller_orders_screen.dart';
import 'reports/seller_reports_screen.dart';
import 'profile/seller_profile_screen.dart';
import '../auth/login_screen.dart';

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

  void goTo(int index) => setState(() => _currentIndex = index);
  bool _redirecting = false;
  
  final List<Widget> _screens = [
    const SellerDashboardScreen(),
    const SellerProductsScreen(),
    const SellerOrdersScreen(),
    const SellerReportsScreen(),
    const SellerProfileScreen(),
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

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.dashboard,
                      label: 'Dashboard',
                      index: 0,
                    ),
                    _buildNavItem(
                      icon: Icons.inventory_2,
                      label: 'Products',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.shopping_cart,
                      label: 'Orders',
                      index: 2,
                    ),
                    _buildNavItem(
                      icon: Icons.analytics,
                      label: 'Reports',
                      index: 3,
                    ),
                    _buildNavItem(
                      icon: Icons.person,
                      label: 'Profile',
                      index: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFfa4e1c).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFfa4e1c) : const Color(0xFF8a7a70),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? const Color(0xFFfa4e1c) : const Color(0xFF8a7a70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}