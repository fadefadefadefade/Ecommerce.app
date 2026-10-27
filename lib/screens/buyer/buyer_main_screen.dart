import 'assistant_screen.dart';
import 'package:flutter/material.dart';
import '../../theme/buyer_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_api.dart';
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
  int get currentIndex => _currentIndex;
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
    // Badge is best-effort; the cart screen shows real errors.
    final r = await BuyerApi.cart();
    if (!mounted || !r.ok) return;
    setState(() => _cartCount = (r.body['count'] as num?)?.toInt() ?? 0);
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
        if (!authProvider.isAuthenticated ||
            authProvider.user?.isBuyer != true) {
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
          // The website's ALVY Assistant bubble, on Home and Shop.
          floatingActionButton: _currentIndex <= 1
              ? FloatingActionButton(
                  heroTag: 'alvy-assistant',
                  tooltip: 'ALVY Assistant',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                  child: const Icon(Icons.support_agent),
                )
              : null,
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
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.bc.border)),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2))],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: goTo,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
                NavigationDestination(
                  icon: Badge(isLabelVisible: _cartCount > 0, label: Text(_cartCount > 99 ? '99+' : '$_cartCount'), backgroundColor: const Color(0xFFFA4E1C), child: const Icon(Icons.shopping_cart_outlined)),
                  selectedIcon: Badge(isLabelVisible: _cartCount > 0, label: Text(_cartCount > 99 ? '99+' : '$_cartCount'), backgroundColor: const Color(0xFFFA4E1C), child: const Icon(Icons.shopping_cart)),
                  label: 'Cart',
                ),
                const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
              ],
            ),
          ),
        );
      },
    );
  }
}
