import 'assistant_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/allie.dart';
import '../../widgets/motion.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_api.dart';
import '../auth/login_screen.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'account/notifications_screen.dart';
import 'account/collections_screens.dart' show WishlistScreen;
import '../../widgets/buyer_web_header.dart';
import '../../widgets/responsive.dart';

/// Bottom-nav shell for buyers, same layout as SellerMainScreen. On a tablet it also has the website's
/// header (BuyerWebHeader: search, messages, notifications, cart, account) and keeps the pages at the website's width.
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
  static const tabWishlist = 2;
  static const tabCart = 3;
  static const tabAccount = 4;

  late int _currentIndex = widget.initialIndex;
  int get currentIndex => _currentIndex;
  bool _redirecting = false;
  int _cartCount = 0;
  // Bumped each time the Cart tab opens so it reloads items added elsewhere.
  int _cartReloadToken = 0;
  // Bumped each time the Wishlist tab opens so hearts tapped elsewhere show up.
  int _wishReloadToken = 0;
  DateTime _cartCountAt = DateTime.fromMillisecondsSinceEpoch(0);

  // No load in initState: the IndexedStack builds the Cart tab right away, and its first load sets the badge.

  /// The cart badge for headers inside the tabs (Home's cart icon).
  final cartNotifier = ValueNotifier<int>(0);

  void _setCartCount(int count) {
    _cartCountAt = DateTime.now();
    cartNotifier.value = count;
    if (mounted && count != _cartCount) setState(() => _cartCount = count);
  }

  /// After something was added to the cart (product cards).
  Future<void> refreshCartCount() async {
    // Badge is best-effort; the cart screen shows real errors.
    final r = await BuyerApi.cart();
    if (!mounted || !r.ok) return;
    _setCartCount((r.body['count'] as num?)?.toInt() ?? 0);
  }

  /// The tab on screen, for screens that react when the user comes back to theirs (Home's category tiles).
  late final tabNotifier = ValueNotifier<int>(widget.initialIndex);

  @override
  void dispose() {
    tabNotifier.dispose();
    cartNotifier.dispose();
    super.dispose();
  }

  void goTo(int index) {
    tabNotifier.value = index;
    setState(() {
      if (index == tabCart) _cartReloadToken++;   // the reloaded cart updates the badge itself
      if (index == tabWishlist) _wishReloadToken++;
      _currentIndex = index;
    });
    // Other tabs: only re-check a badge older than 30 s (catches items added on a product page).
    if (index != tabCart && DateTime.now().difference(_cartCountAt).inSeconds > 30) refreshCartCount();
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

        final wide = Responsive.isWide(context);
        void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        return Scaffold(
          appBar: wide
              ? BuyerWebHeader(
                  currentTab: _currentIndex,
                  cartCount: _cartCount,
                  onTab: goTo,
                  onMessages: () => push(const ChatListScreen()),
                  onNotifications: () => push(const NotificationsScreen()),
                  onWishlist: () => goTo(tabWishlist),
                  onSearch: (q) => push(ShopScreen(initialSearch: q)),
                  accountName: authProvider.user?.name,
                )
              : null,
          body: Stack(children: [
            Positioned.fill(child: (wide ? (Widget w) => WebWidth(child: w) : (Widget w) => w)(TabFade(value: _currentIndex, child: IndexedStack(
            index: _currentIndex,
            children: [
              const BuyerHomeScreen(),
              const ShopScreen(),
              WishlistScreen(key: ValueKey(_wishReloadToken)),
              CartScreen(
                key: ValueKey(_cartReloadToken),
                onBrowse: () => goTo(tabShop),
                onCount: _setCartCount,
              ),
              const ProfileScreen(),
            ],
          )))),
            // ALLIE, on Home and Shop: drag, hide and bring back (kept alive so she stays where she is between tabs).
            Positioned.fill(
              child: Offstage(
                offstage: _currentIndex > 1,
                child: AllieFloating(onOpen: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()))),
              ),
            ),
          ]),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Color(0x142A1A10), blurRadius: 16, offset: Offset(0, -3))],
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: goTo,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
                const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Wishlist'),
                NavigationDestination(
                  icon: PopOnChange(value: _cartCount, child: Badge(isLabelVisible: _cartCount > 0, label: Text(_cartCount > 99 ? '99+' : '$_cartCount'), backgroundColor: const Color(0xFFFA4E1C), child: const Icon(Icons.shopping_cart_outlined))),
                  selectedIcon: PopOnChange(value: _cartCount, child: Badge(isLabelVisible: _cartCount > 0, label: Text(_cartCount > 99 ? '99+' : '$_cartCount'), backgroundColor: const Color(0xFFFA4E1C), child: const Icon(Icons.shopping_cart))),
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
