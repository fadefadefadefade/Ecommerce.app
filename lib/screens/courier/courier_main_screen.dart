import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../buyer/account/policy_screens.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/profile_kit.dart';
import '../../widgets/staff_shell.dart';
import '../auth/login_screen.dart';
import '../buyer/account/notifications_screen.dart';
import '../buyer/account/security_screen.dart';
import '../buyer/chat_screen.dart';
import 'courier_screens.dart';
import 'linehaul_screens.dart';
import 'rider_screens.dart';

/// The courier portal. A rider of a logistics company (user.home == 'rider') gets the web's Hub Jobs menu
/// (jobs, job history, rider pay, COD remittance, profile); a direct courier gets dashboard, history, earnings, account.
class CourierMainScreen extends StatefulWidget {
  const CourierMainScreen({super.key});

  @override
  State<CourierMainScreen> createState() => _CourierMainScreenState();
}

class _CourierMainScreenState extends State<CourierMainScreen> {
  int _index = 0;
  bool _redirecting = false;
  // Opening a tab loads it fresh, like opening the page on the website.
  final Map<int, int> _opened = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated || auth.user?.isCourier != true) {
          if (!_redirecting) {
            _redirecting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            });
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final rider = auth.user!.home == 'rider';
        // A courier of a logistics company (Add Courier) drives hub-to-hub trips.
        final linehaul = auth.user!.home == 'linehaul';
        final tabs = linehaul
            ? const [
                (Icons.local_shipping_outlined, 'Trips', LinehaulHomeScreen()),
                (Icons.history, 'History', LinehaulHistoryScreen()),
                (Icons.payments_outlined, 'Earnings', LinehaulEarningsScreen()),
                (Icons.person_outline, 'More', _MoreScreen(rider: false, linehaul: true)),
              ]
            : rider
            ? const [
                (Icons.inventory_2_outlined, 'Hub Jobs', RiderJobsScreen()),
                (Icons.history, 'History', RiderHistoryScreen()),
                (Icons.payments_outlined, 'Pay', RiderEarningsScreen()),
                (Icons.account_balance_wallet_outlined, 'COD', RiderCodScreen()),
                (Icons.person_outline, 'More', _MoreScreen(rider: true)),
              ]
            : const [
                (Icons.dashboard_outlined, 'Dashboard', CourierDashboardScreen()),
                (Icons.history, 'History', CourierHistoryScreen()),
                (Icons.payments_outlined, 'Earnings', CourierProfitScreen()),
                (Icons.person_outline, 'More', _MoreScreen(rider: false)),
              ];
        if (_index >= tabs.length) _index = 0;

        void select(int i) => setState(() {
              if (i != _index) _opened[i] = (_opened[i] ?? 0) + 1;
              _index = i;
            });
        return StaffShell(
          brand: linehaul ? 'LINEHAUL' : rider ? 'RIDER' : 'COURIER',
          place: linehaul ? 'Hub-to-hub Trips' : rider ? 'Rider Console' : 'Courier Console',
          userName: auth.user!.name,
          userRole: linehaul ? 'Linehaul courier' : rider ? 'Rider' : 'Courier',
          tabs: tabs,
          index: _index,
          onSelect: select,
          body: IndexedStack(index: _index, children: [
            // A hidden tab's timers (e.g. Hub Jobs' 15-second refresh) pause: TickerMode is off for it.
            for (var i = 0; i < tabs.length; i++)
              TickerMode(enabled: i == _index, child: KeyedSubtree(key: ValueKey('tab-$i-${_opened[i] ?? 0}'), child: tabs[i].$3)),
          ]),
        );
      },
    );
  }
}

const _orange = Color(0xFFFA4E1C);

class _MoreScreen extends StatelessWidget {
  final bool rider;
  final bool linehaul;
  const _MoreScreen({required this.rider, this.linehaul = false});

  void _push(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return ProfileScaffold(
      title: rider ? 'Rider' : 'Courier',
      children: [
        ProfileHeaderCard(
          name: user?.name ?? '',
          email: user?.email ?? '',
          roleLabel: rider ? 'Rider' : 'Courier',
          roleIcon: Icons.two_wheeler,
          avatarColor: const Color(0xFFFA4E1C),
        ),
        const SizedBox(height: 16),
        // The buyer account hub's grouped rows, in the logo's two colors.
        ProfileMenuGroup(title: 'Work', rows: [
          if (linehaul)
            ProfileMenuRow(icon: Icons.badge_outlined, color: _orange, title: 'My Profile', subtitle: 'Vehicle, license and documents',
                onTap: () => _push(context, const LinehaulProfileScreen()))
          else if (rider)
            ProfileMenuRow(icon: Icons.badge_outlined, color: _orange, title: 'Rider Profile', subtitle: 'Vehicle, license and documents',
                onTap: () => _push(context, const RiderProfileScreen()))
          else
            ProfileMenuRow(icon: Icons.person_outline, color: _orange, title: 'Account', subtitle: 'Your courier details',
                onTap: () => _push(context, const CourierAccountScreen())),
          // A direct courier who is also a logistics company's rider gets Hub Jobs too (the web's nav shows both).
          if (!rider && user?.hasRider == true) ...[
            ProfileMenuRow(icon: Icons.inventory_2_outlined, color: _orange, title: 'Hub Jobs', subtitle: 'Pickups and deliveries from your hub',
                onTap: () => _push(context, const RiderJobsScreen())),
            ProfileMenuRow(icon: Icons.history, color: _orange, title: 'Job History', subtitle: 'Jobs you finished', onTap: () => _push(context, const RiderHistoryScreen())),
            ProfileMenuRow(icon: Icons.payments_outlined, color: _orange, title: 'Rider Pay', subtitle: 'What you earned', onTap: () => _push(context, const RiderEarningsScreen())),
            ProfileMenuRow(icon: Icons.account_balance_wallet_outlined, color: _orange, title: 'COD Remittance', subtitle: 'Cash to hand over',
                onTap: () => _push(context, const RiderCodScreen())),
            ProfileMenuRow(icon: Icons.badge_outlined, color: _orange, title: 'Rider Profile', subtitle: 'Vehicle, license and documents',
                onTap: () => _push(context, const RiderProfileScreen())),
          ],
        ]),
        const SizedBox(height: 14),
        ProfileMenuGroup(title: 'Account & Preferences', rows: [
          // The web's floating chat on the courier pages.
          ProfileMenuRow(icon: Icons.chat_bubble_outline, title: 'Messages', subtitle: 'Chats about your jobs', onTap: () => _push(context, const ChatListScreen())),
          ProfileMenuRow(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'New jobs and updates', onTap: () => _push(context, const NotificationsScreen())),
          ProfileMenuRow(icon: Icons.lock_outline, title: 'Security', subtitle: 'Password', onTap: () => _push(context, const SecurityScreen())),
          const DarkModeRow(),
          ProfileMenuRow(icon: Icons.policy_outlined, title: 'Policies', subtitle: 'Terms and rules', onTap: () => _push(context, const PoliciesScreen())),
        ]),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: ProfileAction.logout(context).onTap,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
