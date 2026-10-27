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
import 'account/collections_screens.dart';
import 'chat_screen.dart';

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
            color: const Color(0xFF2563EB),
            onTap: () => _push(context, const MyOrdersScreen()),
          ),
          ProfileAction(
            icon: Icons.favorite_border,
            label: 'Wishlist',
            color: const Color(0xFFE11D48),
            onTap: () => _push(context, const WishlistScreen()),
          ),
          ProfileAction(
            icon: Icons.confirmation_number_outlined,
            label: 'My Vouchers',
            color: const Color(0xFFfa4e1c),
            onTap: () => _push(context, const VouchersScreen()),
          ),
          ProfileAction(
            icon: Icons.storefront_outlined,
            label: 'Following',
            color: const Color(0xFF0EA5E9),
            onTap: () => _push(context, const FollowingScreen()),
          ),
          ProfileAction(
            icon: Icons.chat_bubble_outline,
            label: 'Messages',
            color: const Color(0xFF059669),
            onTap: () => _push(context, const ChatListScreen()),
          ),
          ProfileAction(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: const Color(0xFFF59E0B),
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
