import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/profile_kit.dart';
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

        return Scaffold(
          body: IndexedStack(index: _index, children: [
            // A hidden tab's timers (e.g. Hub Jobs' 15-second refresh) pause: TickerMode is off for it.
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
              for (final t in tabs)
                NavigationDestination(icon: Icon(t.$1), selectedIcon: Icon(t.$1, color: const Color(0xFFFA4E1C)), label: t.$2),
            ],
          ),
        );
      },
    );
  }
}

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
          avatarColor: const Color(0xFF00838F),
        ),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          if (linehaul)
            ProfileAction(icon: Icons.badge_outlined, label: 'My Profile', color: const Color(0xFFFA4E1C), onTap: () => _push(context, const LinehaulProfileScreen()))
          else if (rider)
            ProfileAction(icon: Icons.badge_outlined, label: 'Rider Profile', color: const Color(0xFFFA4E1C), onTap: () => _push(context, const RiderProfileScreen()))
          else
            ProfileAction(icon: Icons.person_outline, label: 'Account', color: const Color(0xFFFA4E1C), onTap: () => _push(context, const CourierAccountScreen())),
          // A direct courier who is also a logistics company's rider gets Hub Jobs too (the web's nav shows both).
          if (!rider && user?.hasRider == true) ...[
            ProfileAction(icon: Icons.inventory_2_outlined, label: 'Hub Jobs', color: const Color(0xFF2563EB), onTap: () => _push(context, const RiderJobsScreen())),
            ProfileAction(icon: Icons.history, label: 'Job History', color: const Color(0xFF6B7280), onTap: () => _push(context, const RiderHistoryScreen())),
            ProfileAction(icon: Icons.payments_outlined, label: 'Rider Pay', color: const Color(0xFF15803D), onTap: () => _push(context, const RiderEarningsScreen())),
            ProfileAction(icon: Icons.account_balance_wallet_outlined, label: 'COD Remittance', color: const Color(0xFFB45309), onTap: () => _push(context, const RiderCodScreen())),
            ProfileAction(icon: Icons.badge_outlined, label: 'Rider Profile', color: const Color(0xFF9333EA), onTap: () => _push(context, const RiderProfileScreen())),
          ],
          // The web's floating chat on the courier pages.
          ProfileAction(icon: Icons.chat_bubble_outline, label: 'Messages', color: const Color(0xFF2563EB), onTap: () => _push(context, const ChatListScreen())),
          ProfileAction(icon: Icons.notifications_outlined, label: 'Notifications', color: const Color(0xFFF59E0B), onTap: () => _push(context, const NotificationsScreen())),
          ProfileAction(icon: Icons.lock_outline, label: 'Security', color: const Color(0xFFDC2626), onTap: () => _push(context, const SecurityScreen())),
          ProfileAction.logout(context),
        ]),
      ],
    );
  }
}
