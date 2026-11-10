import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../widgets/profile_kit.dart';
import '../../buyer/account/notifications_screen.dart';
import '../../buyer/account/policy_screens.dart';
import '../../buyer/account/security_screen.dart';
import '../../buyer/chat_screen.dart';
import '../marketing/marketing_screens.dart';
import '../panel/panel_screens.dart';
import '../reports/seller_commissions_screen.dart';

/// Seller profile: the rest of the web's seller menu (store, marketing, money, account).
const _orange = Color(0xFFFA4E1C);

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
          avatarColor: _orange,
        ),
        const SizedBox(height: 16),
        // The buyer account hub's grouped rows, in the logo's two colors: orange for selling, navy for the account.
        ProfileMenuGroup(title: 'Store', rows: [
          ProfileMenuRow(icon: Icons.storefront_outlined, color: _orange, title: 'Store Settings', subtitle: 'Name, logo, banner and vacation mode',
              onTap: () => _push(context, const SellerStoreSettingsScreen())),
          ProfileMenuRow(icon: Icons.category_outlined, color: _orange, title: 'Store Categories', subtitle: 'Group your products for buyers',
              onTap: () => _push(context, const SellerStoreCategoriesScreen())),
          ProfileMenuRow(icon: Icons.reviews_outlined, color: _orange, title: 'Reviews', subtitle: 'What buyers say, and your replies',
              onTap: () => _push(context, const SellerReviewsScreen())),
        ]),
        const SizedBox(height: 14),
        ProfileMenuGroup(title: 'Marketing', rows: [
          ProfileMenuRow(icon: Icons.confirmation_number_outlined, color: _orange, title: 'Vouchers', subtitle: 'Discount codes for your store',
              onTap: () => _push(context, const SellerVouchersScreen())),
          ProfileMenuRow(icon: Icons.flash_on_outlined, color: _orange, title: 'Flash Sales', subtitle: 'Time-limited prices',
              onTap: () => _push(context, const SellerFlashSalesScreen())),
          ProfileMenuRow(icon: Icons.redeem_outlined, color: _orange, title: 'Bundles & Promos', subtitle: 'Buy-more-save-more deals',
              onTap: () => _push(context, const SellerPromotionsScreen())),
        ]),
        const SizedBox(height: 14),
        ProfileMenuGroup(title: 'Money', rows: [
          ProfileMenuRow(icon: Icons.account_balance_wallet_outlined, title: 'Earnings', subtitle: 'What you earned and your payouts',
              onTap: () => _push(context, const SellerEarningsScreen())),
          ProfileMenuRow(icon: Icons.percent, title: 'Commissions', subtitle: 'ALVY fees per order',
              onTap: () => _push(context, const SellerCommissionsScreen())),
        ]),
        const SizedBox(height: 14),
        ProfileMenuGroup(title: 'Account & Preferences', rows: [
          ProfileMenuRow(icon: Icons.chat_bubble_outline, title: 'Messages', subtitle: 'Chats with buyers', onTap: () => _push(context, const ChatListScreen())),
          ProfileMenuRow(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Orders, stock and payouts',
              onTap: () => _push(context, const NotificationsScreen())),
          ProfileMenuRow(icon: Icons.person_outline, title: 'Account', subtitle: 'Name, email, phone and photo', onTap: () => _push(context, const SellerAccountScreen())),
          ProfileMenuRow(icon: Icons.lock_outline, title: 'Security', subtitle: 'Password', onTap: () => _push(context, const SecurityScreen())),
          const DarkModeRow(),
          ProfileMenuRow(icon: Icons.policy_outlined, title: 'Policies', subtitle: 'Seller terms and rules', onTap: () => _push(context, const PoliciesScreen())),
        ]),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: ProfileAction.logout(context).onTap,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Log Out'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
