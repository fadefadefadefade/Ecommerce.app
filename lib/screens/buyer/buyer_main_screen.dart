import 'package:flutter/material.dart';
import '../../theme/buyer_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell for buyers, same layout as SellerMainScreen.
class BuyerMainScreen extends StatefulWidget {
  final int initialIndex;

  const BuyerMainScreen({super.key, this.initialIndex = 0});

  /// Lets nested screens switch tabs (e.g. "Browse Items" in an empty cart).
  static BuyerMainScreenState? of(BuildContext context) =>
      context.findAncestorStateOfType<BuyerMainScreenState>();

  @override
  State<BuyerMainScreen> createState() => BuyerMainScreenState();
}

class BuyerMainScreenState extends State<BuyerMainScreen> {
  static const tabHome = 0;
  static const tabShop = 1;
  static const tabCart = 2;
  static const tabAccount = 3;

  late int _currentIndex = widget.initialIndex;
  bool _redirecting = false;
  int _cartCount = 0;
  // Bumped each time the Cart tab opens so it reloads items added elsewhere.
  int _cartReloadToken = 0;

  @override
  void initState() {
    super.initState();
    refreshCartCount();
  }

  Future<void> refreshCartCount() async {
    try {
      final data = ApiService.unwrap(await ApiService.get('/cart'));
      if (!mounted) return;
      setState(() => _cartCount = (data['count'] as num?)?.toInt() ?? (data['items'] as List?)?.length ?? 0);
    } catch (_) {
      // Badge is best-effort; the cart screen shows real errors.
    }
  }

  void goTo(int index) {
    setState(() {
      if (index == tabCart) _cartReloadToken++;
      _currentIndex = index;
    });
    refreshCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated || authProvider.user?.isBuyer != true) {
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
            children: [
              const BuyerHomeScreen(),
              const ShopScreen(),
              CartScreen(
                key: ValueKey(_cartReloadToken),
                onBrowse: () => goTo(tabShop),
                onChanged: refreshCartCount,
              ),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: context.bc.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                    _buildNavItem(icon: Icons.home, label: 'Home', index: tabHome),
                    _buildNavItem(icon: Icons.storefront, label: 'Shop', index: tabShop),
                    _buildNavItem(
                      icon: Icons.shopping_cart,
                      label: 'Cart',
                      index: tabCart,
                      badge: _cartCount,
                    ),
                    _buildNavItem(icon: Icons.person, label: 'Account', index: tabAccount),
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
    int badge = 0,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFFfa4e1c) : context.bc.muted;

    return GestureDetector(
      onTap: () => goTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFfa4e1c).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              backgroundColor: const Color(0xFFfa4e1c),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
