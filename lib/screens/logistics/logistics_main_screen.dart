import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/profile_kit.dart';
import '../auth/login_screen.dart';
import '../buyer/account/notifications_screen.dart';
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
        return Scaffold(
          body: IndexedStack(index: _index, children: [
            for (var i = 0; i < tabs.length; i++)
              TickerMode(enabled: i == _index, child: KeyedSubtree(key: ValueKey('tab-$i-${_opened[i] ?? 0}'), child: tabs[i].$3)),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            indicatorColor: const Color(0xFFFA4E1C).withValues(alpha: 0.12),
            onDestinationSelected: (i) => setState(() {
              if (i != _index) _opened[i] = (_opened[i] ?? 0) + 1;
              _index = i;
            }),
            destinations: [
              for (final t in tabs) NavigationDestination(icon: Icon(t.$1), selectedIcon: Icon(t.$1, color: const Color(0xFFFA4E1C)), label: t.$2),
            ],
          ),
        );
      },
    );
  }
}

class _Menu extends StatelessWidget {
  final String title;
  final List<(IconData, String, String, Widget)> items;
  final List<Widget> footer;
  const _Menu(this.title, this.items, {this.footer = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), foregroundColor: Colors.white),
      body: ListView(children: [
        for (final it in items)
          ListTile(
            leading: Icon(it.$1, color: const Color(0xFFFA4E1C)),
            title: Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(it.$3),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.$4)),
          ),
        ...footer,
      ]),
    );
  }
}

class _HubMenu extends StatelessWidget {
  const _HubMenu();
  @override
  Widget build(BuildContext context) => const _Menu('Hub', [
        (Icons.view_list_outlined, 'Shipment Board', 'Every shipment you hold or expect, by stage', TrackingBoardScreen()),
        (Icons.assignment_outlined, 'Pickup Requests', 'Confirm or reject sellers\' pickups', PickupRequestsScreen()),
        (Icons.move_to_inbox_outlined, 'Incoming Parcels', 'Scan and receive parcels at the hub', IncomingScreen()),
        (Icons.sort, 'Parcel Sorting', 'Sort received parcels by barangay', SortingScreen()),
        (Icons.assignment_ind_outlined, 'Delivery Assignment', 'Give sorted parcels to riders', AssignmentScreen()),
        (Icons.radar, 'Delivery Monitoring', 'Attempts, overrides, reschedules', MonitoringScreen()),
        (Icons.assignment_return_outlined, 'Return to Sender', 'Parcels going back to sellers', RtsScreen()),
        (Icons.inventory_2_outlined, 'Shipments', 'Every parcel, by status and date', ShipmentsScreen()),
        (Icons.swap_horiz, 'Transfers', 'Send or receive parcels from other hubs', TransfersScreen()),
      ]);
}

class _RidersMenu extends StatelessWidget {
  const _RidersMenu();
  @override
  Widget build(BuildContext context) => const _Menu('Riders', [
        (Icons.send_outlined, 'Dispatch', 'Offers, manual and bulk assignment', DispatchScreen()),
        (Icons.groups_outlined, 'Riders', 'Add riders, activation, suspend, documents', RidersScreen()),
        (Icons.account_balance_wallet_outlined, 'COD Remittances', 'Confirm the cash riders hand over', RemittancesScreen()),
        (Icons.add_road, 'Hub-to-hub Trips', 'Create, assign, follow and receive trips', TripsScreen()),
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
        (Icons.person_outline, 'Account', 'Name, email and password', LogisticsAccountScreen()),
      ],
      footer: [
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
          title: const Text('Log out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          onTap: () => confirmLogout(context),
        ),
      ],
    );
  }
}
