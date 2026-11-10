import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/profile_kit.dart';
import '../../widgets/staff_shell.dart';
import '../auth/login_screen.dart';
import '../buyer/account/notifications_screen.dart';
import '../buyer/account/policy_screens.dart';
import '../buyer/account/security_screen.dart';
import 'company_screens.dart';
import 'hub_more_screens.dart';
import 'hub_screens.dart';
import 'rider_admin_screens.dart';
import 'staff_screens.dart';
import 'tracking_screens.dart';
import 'trip_screens.dart';

/// The logistics company's portal (the web's sorting-center panel): dashboard, the hub's parcel work, riders, and the company.
class LogisticsMainScreen extends StatefulWidget {
  const LogisticsMainScreen({super.key});

  @override
  State<LogisticsMainScreen> createState() => _LogisticsMainScreenState();
}

class _LogisticsMainScreenState extends State<LogisticsMainScreen> {
  int _index = 0;
  bool _redirecting = false;
  // Opening a tab loads it fresh, like opening the page on the website.
  final Map<int, int> _opened = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated || auth.user?.isLogistics != true) {
          if (!_redirecting) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            });
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        const tabs = [
          (Icons.dashboard_outlined, 'Dashboard', LogisticsDashboardScreen()),
          (Icons.warehouse_outlined, 'Hub', _HubMenu()),
          (Icons.two_wheeler, 'Riders', _RidersMenu()),
          (Icons.more_horiz, 'More', _MoreMenu()),
        ];
        void select(int i) => setState(() {
              if (i != _index) _opened[i] = (_opened[i] ?? 0) + 1;
              _index = i;
            });
        return StaffShell(
          brand: 'OPS',
          place: 'Hub Operations',
          userName: auth.user!.name,
          userRole: 'Logistics',
          tabs: tabs,
          index: _index,
          onSelect: select,
          body: IndexedStack(index: _index, children: [
            for (var i = 0; i < tabs.length; i++)
              TickerMode(enabled: i == _index, child: KeyedSubtree(key: ValueKey('tab-$i-${_opened[i] ?? 0}'), child: tabs[i].$3)),
          ]),
        );
      },
    );
  }
}

/// A portal menu (Hub, Riders, More): icons with the label under them (3 per row on phones, small tiles on tablets).
class _Menu extends StatelessWidget {
  final String title;
  final List<(IconData, String, String, Widget)> items;
  /// A Log out tile at the end (More).
  final bool logout;
  const _Menu(this.title, this.items, {this.logout = false});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    // The account hubs' grouped rows (buyer, seller, rider): the icon in the logo's orange, a line on what each page does.
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        ProfileMenuGroup(rows: [
          for (final it in items)
            ProfileMenuRow(icon: it.$1, color: const Color(0xFFFA4E1C), title: it.$2, subtitle: it.$3, onTap: () => open(it.$4)),
          if (logout) const DarkModeRow(),
        ]),
        if (logout) ...[
          const SizedBox(height: 18),
          TextButton.icon(onPressed: () => confirmLogout(context), icon: const Icon(Icons.logout, size: 20), label: const Text('Log Out')),
        ],
      ]),
    );
  }
}

class _HubMenu extends StatelessWidget {
  const _HubMenu();
  @override
  Widget build(BuildContext context) => const _Menu('Hub', [
        (Icons.view_list_outlined, 'Shipment Board', 'Scan, receive and follow every shipment', TrackingBoardScreen()),
        (Icons.assignment_outlined, 'Pickup Requests', 'Confirm or reject sellers\' pickups', PickupRequestsScreen()),
        (Icons.sort, 'Parcel Sorting', 'Sort received parcels by barangay', SortingScreen()),
        (Icons.assignment_ind_outlined, 'Delivery Assignment', 'Give sorted parcels to riders', AssignmentScreen()),
        (Icons.radar, 'Delivery Monitoring', 'Attempts, overrides, reschedules', MonitoringScreen()),
        (Icons.inventory_2_outlined, 'Shipments', 'Every parcel, by status and date', ShipmentsScreen()),
        (Icons.add_road, 'Linehaul Trips', 'Deliveries to and from other sorting centers', TripsScreen()),
      ]);
}

class _RidersMenu extends StatelessWidget {
  const _RidersMenu();
  @override
  Widget build(BuildContext context) => const _Menu('Riders', [
        (Icons.send_outlined, 'Dispatch', 'Auto-assign by barangay, manual and bulk', DispatchScreen()),
        (Icons.groups_outlined, 'Riders', 'Add riders, activation, suspend, documents', RidersScreen()),
        (Icons.account_balance_wallet_outlined, 'COD Remittances', 'Confirm the cash riders hand over', RemittancesScreen()),
        (Icons.local_shipping_outlined, 'Couriers', 'Add couriers, duty, activation, applications', CouriersScreen()),
        (Icons.warehouse_outlined, 'Hubs', 'Your hubs; each courier has a home hub', HubsScreen()),
      ]);
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return _Menu(
      user?.name ?? 'More',
      const [
        (Icons.payments_outlined, 'Commission & Earnings', 'Your share of shipping fees, commission and net', LogisticsCommissionsScreen()),
        (Icons.map_outlined, 'Coverage', 'Barangays you deliver to', CoverageScreen()),
        (Icons.local_shipping_outlined, 'Shipping Rates', 'Rates by route and delivery zones', RatesScreen()),
        (Icons.analytics_outlined, 'Reports', 'Daily, riders, areas and COD', LogisticsReportsScreen()),
        (Icons.history, 'Activity Log', 'Everything your account changed', ActivityScreen()),
        (Icons.chat_bubble_outline, 'Messages', 'Riders, couriers, sellers and ALVY', LogisticsChatScreen()),
        (Icons.notifications_outlined, 'Notifications', 'Updates for your company', NotificationsScreen()),
        (Icons.person_outline, 'Account', 'Name and email', LogisticsAccountScreen()),
        (Icons.shield_outlined, 'Security', 'Change your password', SecurityScreen()),
        (Icons.policy_outlined, 'Policies', 'Terms, privacy, prohibited items and more', PoliciesScreen()),
      ],
      logout: true,
    );
  }
}
