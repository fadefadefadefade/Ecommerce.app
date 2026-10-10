import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'dashboard/logistics_dashboard_screen.dart';
import 'pickups/pickup_requests_screen.dart';
import 'parcels/parcels_screen.dart';
import 'deliveries/deliveries_screen.dart';
import 'more/logistics_more_screen.dart';
import 'widgets/logistics_ui.dart';

/// Mobile version of the web "ParcelOps" logistics panel (admin role).
class LogisticsMainScreen extends StatefulWidget {
  const LogisticsMainScreen({super.key});

  @override
  State<LogisticsMainScreen> createState() => _LogisticsMainScreenState();
}

class _LogisticsMainScreenState extends State<LogisticsMainScreen> {
  int _currentIndex = 0;
  bool _redirecting = false;

  static const tabDashboard = 0;
  static const tabPickups = 1;
  static const tabParcels = 2;
  static const tabDeliveries = 3;
  static const tabMore = 4;

  void _goTo(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated || authProvider.user?.isAdmin != true) {
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

        final screens = [
          LogisticsDashboardScreen(
            onOpenPickups: () => _goTo(tabPickups),
            onOpenParcels: () => _goTo(tabParcels),
            onOpenDeliveries: () => _goTo(tabDeliveries),
          ),
          const PickupRequestsScreen(),
          const ParcelsScreen(),
          const DeliveriesScreen(),
          const LogisticsMoreScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
                    _buildNavItem(icon: Icons.dashboard, label: 'Dashboard', index: tabDashboard),
                    _buildNavItem(icon: Icons.move_to_inbox, label: 'Pickups', index: tabPickups),
                    _buildNavItem(icon: Icons.inventory_2, label: 'Parcels', index: tabParcels),
                    _buildNavItem(icon: Icons.local_shipping, label: 'Deliveries', index: tabDeliveries),
                    _buildNavItem(icon: Icons.person, label: 'Account', index: tabMore),
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
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _goTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? LogisticsColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? LogisticsColors.primary : LogisticsColors.muted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? LogisticsColors.primary : LogisticsColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
