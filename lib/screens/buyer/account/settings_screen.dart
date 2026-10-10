import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/buyer_colors.dart';
import 'account_ui.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: c.background,
      appBar: accountAppBar('Settings'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AccountCard(
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: BuyerPalette.primary,
                  secondary: Icon(
                    themeProvider.mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    color: BuyerPalette.primary,
                  ),
                  title: Text('Dark mode', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                  subtitle: Text('Easier on the eyes at night', style: TextStyle(color: c.muted, fontSize: 12)),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (on) => themeProvider.setMode(on ? ThemeMode.dark : ThemeMode.light),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                      ButtonSegment(
                          value: ThemeMode.system, icon: Icon(Icons.settings_suggest), label: Text('System')),
                    ],
                    selected: {themeProvider.mode},
                    onSelectionChanged: (s) => themeProvider.setMode(s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: BuyerPalette.primary,
                      selectedForegroundColor: Colors.white,
                      foregroundColor: c.text,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"System" follows your phone\'s dark mode setting.',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AccountCard(
            title: 'Account',
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tile(context, Icons.lock_outline, 'Security', 'Change your password',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                Divider(height: 1, color: c.border),
                _tile(context, Icons.notifications_outlined, 'Notifications', 'Order and account updates',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AccountCard(
            title: 'About',
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: BuyerPalette.primary),
                  title: Text('ALVY', style: TextStyle(color: c.text)),
                  trailing: Text('v1.0.0', style: TextStyle(color: c.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final c = context.bc;
    return ListTile(
      leading: Icon(icon, color: BuyerPalette.primary),
      title: Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: c.muted),
      onTap: onTap,
    );
  }
}
