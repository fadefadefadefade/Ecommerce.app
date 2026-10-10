import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/profile_kit.dart';
import '../auth/login_screen.dart';
import '../buyer/account/notifications_screen.dart';
import '../buyer/account/security_screen.dart';
import '../buyer/personal_info_screen.dart';
import 'courier_deliveries_screen.dart';

/// Courier (rider) app: deliveries assigned by logistics, history and account.
class CourierMainScreen extends StatefulWidget {
  const CourierMainScreen({super.key});

  @override
  State<CourierMainScreen> createState() => _CourierMainScreenState();
}

class _CourierMainScreenState extends State<CourierMainScreen> {
  int _index = 0;
  bool _redirecting = false;
  // Bumped when the History tab opens so it shows the latest finished deliveries.
  int _historyToken = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated || auth.user?.isCourier != true) {
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              const CourierDeliveriesScreen(),
              CourierDeliveriesScreen(key: ValueKey(_historyToken), history: true),
              const _CourierAccountScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFA4E1C).withValues(alpha: 0.12),
            onDestinationSelected: (i) => setState(() {
              if (i == 1) _historyToken++;
              _index = i;
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping, color: Color(0xFFFA4E1C)),
                label: 'Deliveries',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history, color: Color(0xFFFA4E1C)),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: Color(0xFFFA4E1C)),
                label: 'Account',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourierAccountScreen extends StatelessWidget {
  const _CourierAccountScreen();

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return ProfileScaffold(
      title: 'My Account',
      children: [
        ProfileHeaderCard(
          name: user?.name ?? '',
          email: user?.email ?? '',
          roleLabel: 'Courier',
          roleIcon: Icons.two_wheeler,
          avatarColor: const Color(0xFF00838F),
        ),
        const SizedBox(height: 24),
        ProfileInfoCard(
          title: 'Rider Information',
          items: [
            ('Full Name', user?.name ?? ''),
            ('Email Address', user?.email ?? ''),
            ('Phone Number', user?.phone ?? ''),
            ('Member Since', memberSince(user?.createdAt)),
          ],
          onEdit: () => _push(context, const PersonalInfoScreen()),
        ),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          ProfileAction(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: const Color(0xFFFFA500),
            onTap: () => _push(context, const NotificationsScreen()),
          ),
          ProfileAction(
            icon: Icons.lock_outline,
            label: 'Security',
            color: const Color(0xFFDC2626),
            onTap: () => _push(context, const SecurityScreen()),
          ),
          ProfileAction.logout(context),
        ]),
      ],
    );
  }
}
