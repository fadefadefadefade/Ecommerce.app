import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/profile_kit.dart';
import '../../buyer/account/notifications_screen.dart';
import '../../buyer/account/security_screen.dart';
import '../account/logistics_account_screen.dart';
import '../chat/chat_contacts_screen.dart';
import '../reports/logistics_reports_screen.dart';
import '../riders/riders_screen.dart';

/// Logistics admin profile ("More" tab), same layout as the buyer's My Account.
class LogisticsMoreScreen extends StatelessWidget {
  const LogisticsMoreScreen({super.key});

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
          roleLabel: 'Logistics Admin',
          roleIcon: Icons.local_shipping,
        ),
        const SizedBox(height: 24),
        ProfileInfoCard(
          title: 'Account Information',
          items: [
            ('Full Name', user?.name ?? ''),
            ('Email Address', user?.email ?? ''),
            ('Role', 'Administrator · Logistics'),
            ('Member Since', memberSince(user?.createdAt)),
          ],
          onEdit: () => _push(context, const LogisticsAccountScreen()),
        ),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          ProfileAction(
            icon: Icons.two_wheeler,
            label: 'Rider Management',
            color: const Color(0xFF3B82F6),
            onTap: () => _push(context, const RidersScreen()),
          ),
          ProfileAction(
            icon: Icons.analytics_outlined,
            label: 'Reports',
            color: const Color(0xFF8B5CF6),
            onTap: () => _push(context, const LogisticsReportsScreen()),
          ),
          ProfileAction(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            color: const Color(0xFF10B981),
            onTap: () => _push(context, const ChatContactsScreen()),
          ),
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
