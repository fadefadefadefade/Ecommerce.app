import 'package:flutter/material.dart';
import '../../../services/app_update.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/app_theme.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AccountCard(
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountRow(
                  icon: themeProvider.mode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  title: 'Dark mode',
                  subtitle: 'Easier on the eyes at night',
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (on) => themeProvider.setMode(on ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
                const SizedBox(height: 8),
                // The design's segmented switch: a beige track with the chosen one on white.
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    for (final (mode, icon, label) in const [
                      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
                      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                      (ThemeMode.system, Icons.settings_suggest_outlined, 'System'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => themeProvider.setMode(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: themeProvider.mode == mode ? c.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(icon, size: 17, color: themeProvider.mode == mode ? Alvy.orange : c.textSecondary),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: TextStyle(
                                      fontWeight: themeProvider.mode == mode ? FontWeight.w700 : FontWeight.w500,
                                      color: themeProvider.mode == mode ? Alvy.orange : c.textSecondary)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('"System" follows your phone\'s dark mode setting.', style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AccountCard(
            title: 'Account',
            child: Column(
              children: [
                AccountRow(
                  icon: Icons.lock_outline,
                  title: 'Security',
                  subtitle: 'Change your password',
                  navy: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
                ),
                AccountRow(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Order and account updates',
                  navy: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AccountCard(
            title: 'About',
            child: AccountRow(
              icon: Icons.info_outline,
              title: 'ALVY',
              subtitle: 'Shop local, delivered by local riders',
              trailing: FutureBuilder<String>(
                future: AppUpdate.versionName(),
                builder: (_, v) => Text(v.data == null || v.data!.isEmpty ? '' : 'v${v.data}', style: TextStyle(color: c.muted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
