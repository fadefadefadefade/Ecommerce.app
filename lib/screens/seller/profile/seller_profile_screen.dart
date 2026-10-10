import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/profile_kit.dart';
import '../../buyer/account/notifications_screen.dart';
import '../../buyer/account/security_screen.dart';
import '../../buyer/personal_info_screen.dart';
import '../seller_main_screen.dart';

/// Seller profile, same layout as the buyer's My Account.
class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _tab(BuildContext context, int index) => SellerMainScreen.of(context)?.goTo(index);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final verified = user?.isApprovedSeller == true;

    return ProfileScaffold(
      title: 'Profile & Settings',
      children: [
        ProfileHeaderCard(
          name: user?.name ?? '',
          email: user?.email ?? '',
          roleLabel: verified ? 'Verified Seller' : 'Seller',
          roleIcon: verified ? Icons.verified : Icons.storefront,
          avatarColor: const Color(0xFFFA4E1C),
        ),
        const SizedBox(height: 24),
        ProfileInfoCard(
          title: 'Seller Information',
          items: [
            ('Full Name', user?.name ?? ''),
            ('Email Address', user?.email ?? ''),
            ('Phone Number', user?.phone ?? ''),
            ('Account Status', verified ? 'Approved' : (user?.approvalStatus ?? '').toUpperCase()),
            ('Member Since', memberSince(user?.createdAt)),
          ],
          onEdit: () => _push(context, const PersonalInfoScreen()),
        ),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          ProfileAction(
            icon: Icons.inventory_2_outlined,
            label: 'My Products',
            color: const Color(0xFF3B82F6),
            onTap: () => _tab(context, SellerMainScreenState.tabProducts),
          ),
          ProfileAction(
            icon: Icons.receipt_long_outlined,
            label: 'Orders',
            color: const Color(0xFF10B981),
            onTap: () => _tab(context, SellerMainScreenState.tabOrders),
          ),
          ProfileAction(
            icon: Icons.analytics_outlined,
            label: 'Reports',
            color: const Color(0xFF8B5CF6),
            onTap: () => _tab(context, SellerMainScreenState.tabReports),
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
