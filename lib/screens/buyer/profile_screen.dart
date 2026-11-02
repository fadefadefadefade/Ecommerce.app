import 'package:flutter/material.dart';
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
        (icon: Icons.shopping_bag_outlined, label: 'My Orders', color: const Color(0xFF2563EB), page: const MyOrdersScreen()),
        (icon: Icons.favorite_border, label: 'Wishlist', color: const Color(0xFFE11D48), page: const WishlistScreen()),
        (icon: Icons.confirmation_number_outlined, label: 'My Vouchers', color: const Color(0xFFfa4e1c), page: const VouchersScreen()),
        (icon: Icons.storefront_outlined, label: 'Following', color: const Color(0xFF0EA5E9), page: const FollowingScreen()),
        (icon: Icons.chat_bubble_outline, label: 'Messages', color: const Color(0xFF059669), page: const ChatListScreen()),
        (icon: Icons.notifications_outlined, label: 'Notifications', color: const Color(0xFFF59E0B), page: const NotificationsScreen()),
        (icon: Icons.location_on_outlined, label: 'Addresses', color: const Color(0xFF8B5CF6), page: const AddressesScreen()),
        (icon: Icons.lock_outline, label: 'Security', color: const Color(0xFFDC2626), page: const SecurityScreen()),
        (icon: Icons.settings_outlined, label: 'Settings', color: context.bc.muted, page: const SettingsScreen()),
        (icon: Icons.policy_outlined, label: 'Policies', color: const Color(0xFF4A7A94), page: const PoliciesScreen()),
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

    return ProfileScaffold(
      title: 'My Account',
      children: [
        ..._overview(context, open: (page) => _push(context, page)),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          for (final i in items) ProfileAction(icon: i.icon, label: i.label, color: i.color, onTap: () => _push(context, i.page)),
          ProfileAction.logout(context),
        ]),
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
                  selectedTileColor: const Color(0xFFFFF1EE),
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
                    selectedTileColor: const Color(0xFFFFF1EE),
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
