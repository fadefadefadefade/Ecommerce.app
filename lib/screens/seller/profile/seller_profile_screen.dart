import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../widgets/profile_kit.dart';
import '../../buyer/account/notifications_screen.dart';
import '../../buyer/account/security_screen.dart';
import '../../buyer/chat_screen.dart';
import '../marketing/marketing_screens.dart';
import '../panel/panel_screens.dart';
import '../reports/seller_commissions_screen.dart';

/// Seller profile: the rest of the web's seller menu (store, marketing, money, account).
class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final verified = user?.isApprovedSeller == true;

    return ProfileScaffold(
      title: 'Seller Center',
      children: [
        ProfileHeaderCard(
          name: user?.name ?? '',
          email: user?.email ?? '',
          roleLabel: verified ? 'Verified Seller' : 'Seller',
          roleIcon: verified ? Icons.verified : Icons.storefront,
          avatarColor: const Color(0xFFFA4E1C),
        ),
        const SizedBox(height: 16),
        ProfileActionGrid(actions: [
          ProfileAction(icon: Icons.storefront_outlined, label: 'Store Settings', color: const Color(0xFFFA4E1C),
              onTap: () => _push(context, const SellerStoreSettingsScreen())),
          ProfileAction(icon: Icons.category_outlined, label: 'Store Categories', color: const Color(0xFF0891B2),
              onTap: () => _push(context, const SellerStoreCategoriesScreen())),
          ProfileAction(icon: Icons.confirmation_number_outlined, label: 'Vouchers', color: const Color(0xFF9333EA),
              onTap: () => _push(context, const SellerVouchersScreen())),
          ProfileAction(icon: Icons.flash_on_outlined, label: 'Flash Sales', color: const Color(0xFFDC2626),
              onTap: () => _push(context, const SellerFlashSalesScreen())),
          ProfileAction(icon: Icons.redeem_outlined, label: 'Bundles & Promos', color: const Color(0xFFDB2777),
              onTap: () => _push(context, const SellerPromotionsScreen())),
          ProfileAction(icon: Icons.reviews_outlined, label: 'Reviews', color: const Color(0xFFF59E0B),
              onTap: () => _push(context, const SellerReviewsScreen())),
          ProfileAction(icon: Icons.account_balance_wallet_outlined, label: 'Earnings', color: const Color(0xFF15803D),
              onTap: () => _push(context, const SellerEarningsScreen())),
          ProfileAction(icon: Icons.percent, label: 'Commissions', color: const Color(0xFF9333EA),
              onTap: () => _push(context, const SellerCommissionsScreen())),
          ProfileAction(icon: Icons.chat_bubble_outline, label: 'Messages', color: const Color(0xFF2563EB),
              onTap: () => _push(context, const ChatListScreen())),
          ProfileAction(icon: Icons.notifications_outlined, label: 'Notifications', color: const Color(0xFFF59E0B),
              onTap: () => _push(context, const NotificationsScreen())),
          ProfileAction(icon: Icons.person_outline, label: 'Account', color: const Color(0xFF2563EB),
              onTap: () => _push(context, const SellerAccountScreen())),
          ProfileAction(icon: Icons.lock_outline, label: 'Security', color: const Color(0xFF6B7280),
              onTap: () => _push(context, const SecurityScreen())),
          ProfileAction.logout(context),
        ]),
      ],
    );
  }
}
