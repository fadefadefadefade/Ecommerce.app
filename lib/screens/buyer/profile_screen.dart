import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/profile_kit.dart';
import 'personal_info_screen.dart';
import 'addresses_screen.dart';
import 'account/my_orders_screen.dart';
import 'account/notifications_screen.dart';
import 'account/security_screen.dart';
import 'account/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          roleLabel: user?.role ?? 'buyer',
          roleIcon: Icons.shopping_bag,
        ),
        const SizedBox(height: 24),
        ProfileInfoCard(
          title: 'Personal Information',
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
            icon: Icons.shopping_bag_outlined,
            label: 'My Orders',
            color: const Color(0xFF3B82F6),
            onTap: () => _push(context, const MyOrdersScreen()),
          ),
          ProfileAction(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: const Color(0xFFFFA500),
            onTap: () => _push(context, const NotificationsScreen()),
          ),
          ProfileAction(
            icon: Icons.location_on_outlined,
            label: 'Addresses',
            color: const Color(0xFF8B5CF6),
            onTap: () => _push(context, const AddressesScreen()),
          ),
          ProfileAction(
            icon: Icons.lock_outline,
            label: 'Security',
            color: const Color(0xFFDC2626),
            onTap: () => _push(context, const SecurityScreen()),
          ),
          ProfileAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            color: context.bc.muted,
            onTap: () => _push(context, const SettingsScreen()),
          ),
          ProfileAction.logout(context),
        ]),
      ],
    );
  }
}
