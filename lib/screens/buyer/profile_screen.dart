import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/profile_kit.dart';
import '../../widgets/responsive.dart';
import 'personal_info_screen.dart';
import 'addresses_screen.dart';
import 'account/my_orders_screen.dart';
import 'account/notifications_screen.dart';
import 'account/security_screen.dart';
import 'account/settings_screen.dart';
import 'account/policy_screens.dart';
import 'account/collections_screens.dart';
import 'chat_screen.dart';

/// One item of the account menu.
typedef _Item = ({IconData icon, String label, Color color, Widget page});

/// The buyer's account. Phones: the overview with the menu grid (each page opens on top).
/// Tablets: the website's account page, the menu on the left and the chosen page on the right.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Tablet: the right side has its own navigator, so a page's Back / Save returns to the overview there.
  final _pane = GlobalKey<NavigatorState>();
  String? _selected;

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  List<_Item> _items(BuildContext context) => [
        (icon: Icons.shopping_bag_outlined, label: 'My Orders', color: Alvy.slate, page: const MyOrdersScreen()),
        (icon: Icons.favorite_border, label: 'Wishlist', color: const Color(0xFFFA4E1C), page: const WishlistScreen()),
        (icon: Icons.confirmation_number_outlined, label: 'My Vouchers', color: const Color(0xFFFA4E1C), page: const VouchersScreen()),
        (icon: Icons.storefront_outlined, label: 'Following', color: Alvy.slate, page: const FollowingScreen()),
        (icon: Icons.chat_bubble_outline, label: 'Messages', color: Alvy.slate, page: const ChatListScreen()),
        (icon: Icons.notifications_outlined, label: 'Notifications', color: const Color(0xFFFA4E1C), page: const NotificationsScreen()),
        (icon: Icons.location_on_outlined, label: 'Addresses', color: Alvy.slate, page: const AddressesScreen()),
        (icon: Icons.lock_outline, label: 'Security', color: const Color(0xFFFA4E1C), page: const SecurityScreen()),
        (icon: Icons.settings_outlined, label: 'Settings', color: context.bc.muted, page: const SettingsScreen()),
        (icon: Icons.policy_outlined, label: 'Policies', color: Alvy.slate, page: const PoliciesScreen()),
      ];

  /// The overview: who is signed in and their details (the phone's page, the tablet's right side at first).
  List<Widget> _overview(BuildContext context, {required void Function(Widget) open}) {
    final user = context.watch<AuthProvider>().user;
    return [
      ProfileHeaderCard(
        name: user?.name ?? '',
        email: user?.email ?? '',
        roleLabel: user?.role ?? 'buyer',
        roleIcon: Icons.shopping_bag,
      ),
      const SizedBox(height: 24),
      ProfileInfoCard(
        title: 'Personal Information',
        items: [
          ('Full Name', user?.name ?? ''),
          ('Email Address', user?.email ?? ''),
          ('Phone Number', user?.phone ?? ''),
          ('Member Since', memberSince(user?.createdAt)),
        ],
        onEdit: () => open(const PersonalInfoScreen()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    if (Responsive.isWide(context)) return _tablet(context, items);

    // Phones: the design's account hub — who is signed in, order shortcuts, then menu cards.
    final user = context.watch<AuthProvider>().user;
    void go(Widget page) => _push(context, page);
    return ProfileScaffold(
      title: 'My Account',
      children: [
        ProfileHeaderCard(
          name: user?.name ?? '',
          email: user?.email ?? '',
          roleLabel: user?.role ?? 'buyer',
          roleIcon: Icons.verified_outlined,
        ),
        const SizedBox(height: 16),
        ProfileMenuGroup(
          title: 'My Orders',
          trailing: TextButton(
            onPressed: () => go(const MyOrdersScreen()),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Order History'), Icon(Icons.chevron_right, size: 18)]),
          ),
          rows: [
            ProfileShortcutRow(items: [
              (icon: Icons.account_balance_wallet_outlined, label: 'To Pay', onTap: () => go(const MyOrdersScreen(initialTab: 'to_pay'))),
              (icon: Icons.inventory_2_outlined, label: 'To Ship', onTap: () => go(const MyOrdersScreen(initialTab: 'to_ship'))),
              (icon: Icons.local_shipping_outlined, label: 'To Receive', onTap: () => go(const MyOrdersScreen(initialTab: 'to_receive'))),
              (icon: Icons.rate_review_outlined, label: 'Done', onTap: () => go(const MyOrdersScreen(initialTab: 'completed'))),
              (icon: Icons.assignment_return_outlined, label: 'Returns', onTap: () => go(const MyOrdersScreen(initialTab: 'return_refund'))),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        ProfileMenuGroup(title: 'Rewards & Discovery', rows: [
          ProfileMenuRow(icon: Icons.confirmation_number_outlined, color: const Color(0xFFFA4E1C), title: 'My Vouchers', subtitle: 'Vouchers you have claimed', onTap: () => go(const VouchersScreen())),
          ProfileMenuRow(icon: Icons.favorite_border, color: const Color(0xFFFA4E1C), title: 'Wishlist', subtitle: 'Items you saved for later', onTap: () => go(const WishlistScreen())),
          ProfileMenuRow(icon: Icons.storefront_outlined, title: 'Following', subtitle: 'Stores you follow', onTap: () => go(const FollowingScreen())),
          ProfileMenuRow(icon: Icons.chat_bubble_outline, title: 'Messages', subtitle: 'Chats with sellers and ALVY', onTap: () => go(const ChatListScreen())),
        ]),
        const SizedBox(height: 16),
        ProfileMenuGroup(title: 'Account & Preferences', rows: [
          ProfileMenuRow(icon: Icons.person_outline, title: 'Personal Information', subtitle: user?.phone ?? user?.email, onTap: () => go(const PersonalInfoScreen())),
          ProfileMenuRow(icon: Icons.location_on_outlined, title: 'Saved Delivery Addresses', subtitle: 'Where your orders go', onTap: () => go(const AddressesScreen())),
          ProfileMenuRow(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Order updates and promos', onTap: () => go(const NotificationsScreen())),
          ProfileMenuRow(icon: Icons.lock_outline, title: 'Account Security', subtitle: 'Password and login sessions', onTap: () => go(const SecurityScreen())),
          ProfileMenuRow(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Dark mode and app preferences', onTap: () => go(const SettingsScreen())),
          ProfileMenuRow(icon: Icons.policy_outlined, title: 'Policies', subtitle: 'Terms, privacy and returns', onTap: () => go(const PoliciesScreen())),
        ]),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: ProfileAction.logout(context).onTap,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Log Out'),
        ),
        Text('Member since ${memberSince(user?.createdAt)}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _tablet(BuildContext context, List<_Item> items) {
    final c = context.bc;
    void openInPane(String label, Widget page) {
      setState(() => _selected = label);
      _pane.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (r) => r.isFirst);
    }

    return Scaffold(
      backgroundColor: c.background,
      body: WebWidth(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 280,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('My Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                ),
                ListTile(
                  dense: true,
                  selected: _selected == null,
                  selectedTileColor: Alvy.orangeSoft,
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Overview'),
                  onTap: () {
                    setState(() => _selected = null);
                    _pane.currentState?.popUntil((r) => r.isFirst);
                  },
                ),
                for (final i in items)
                  ListTile(
                    dense: true,
                    selected: _selected == i.label,
                    selectedTileColor: Alvy.orangeSoft,
                    leading: Icon(i.icon, color: i.color),
                    title: Text(i.label),
                    onTap: () => openInPane(i.label, i.page),
                  ),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                  title: const Text('Log out', style: TextStyle(color: Color(0xFFDC2626))),
                  onTap: ProfileAction.logout(context).onTap,
                ),
              ]),
            ),
          ),
          Expanded(
            child: ClipRect(
              // The phone's Back button closes the page on the right first (back to the overview).
              child: NavigatorPopHandler(
                onPopWithResult: (_) {
                  _pane.currentState?.maybePop();
                  if (!(_pane.currentState?.canPop() ?? false)) setState(() => _selected = null);
                },
                child: Navigator(
                  key: _pane,
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (ctx) => Scaffold(
                      backgroundColor: c.background,
                      body: ListView(padding: const EdgeInsets.all(12), children: _overview(ctx, open: (page) => openInPane('Personal Information', page))),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
