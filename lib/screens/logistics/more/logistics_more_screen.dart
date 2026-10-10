import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../account/logistics_account_screen.dart';
import '../chat/chat_contacts_screen.dart';
import '../reports/logistics_reports_screen.dart';
import '../riders/riders_screen.dart';
import '../widgets/logistics_ui.dart';

class LogisticsMoreScreen extends StatelessWidget {
  const LogisticsMoreScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (ok && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('More'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: LogisticsColors.primary,
                  child: Text(
                    (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Admin',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(user?.email ?? '', style: const TextStyle(color: LogisticsColors.muted)),
                      const SizedBox(height: 4),
                      const StatusBadge(status: 'info', label: 'Logistics Admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tile(context, Icons.two_wheeler, 'Rider Management', () => _push(context, const RidersScreen())),
                const Divider(height: 1),
                _tile(context, Icons.analytics, 'Reports', () => _push(context, const LogisticsReportsScreen())),
                const Divider(height: 1),
                _tile(context, Icons.chat, 'Chat / Messaging', () => _push(context, const ChatContactsScreen())),
                const Divider(height: 1),
                _tile(context, Icons.person, 'Account', () => _push(context, const LogisticsAccountScreen())),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout, color: LogisticsColors.danger),
              title: const Text('Log out', style: TextStyle(color: LogisticsColors.danger, fontWeight: FontWeight.w600)),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: LogisticsColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: LogisticsColors.muted),
      onTap: onTap,
    );
  }
}
