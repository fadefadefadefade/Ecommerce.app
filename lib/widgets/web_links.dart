import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

import '../screens/buyer/account/collections_screens.dart';
import '../screens/buyer/account/my_orders_screen.dart';
import '../screens/buyer/account/order_detail_screen.dart';
import '../screens/buyer/chat_screen.dart';
import '../screens/buyer/product_detail_screen.dart';
import '../screens/buyer/store_screen.dart';
import '../screens/courier/courier_screens.dart';
import '../screens/courier/rider_screens.dart';
import '../screens/logistics/company_screens.dart';
import '../screens/logistics/hub_more_screens.dart';
import '../screens/logistics/hub_screens.dart';
import '../screens/logistics/rider_admin_screens.dart';
import '../screens/logistics/staff_screens.dart';
import '../screens/logistics/tracking_screens.dart';
import '../screens/seller/dashboard/seller_dashboard_screen.dart';
import '../screens/seller/marketing/marketing_screens.dart';
import '../screens/seller/orders/seller_order_details_screen.dart';
import '../screens/seller/orders/seller_orders_screen.dart';
import '../screens/seller/panel/panel_screens.dart';
import '../screens/seller/products/add_edit_product_screen.dart';
import '../screens/seller/products/seller_products_screen.dart';
import '../screens/seller/reports/seller_reports_screen.dart';
import '../screens/buyer/account/security_screen.dart';

/// Opens the app screen for a website link (a notification's link, or where a web action goes next).
/// Returns false when the link has no screen in the app.
Future<bool> openWebPath(BuildContext context, String? path) async {
  if (path == null || path.isEmpty) return false;
  final uri = Uri.tryParse(path);
  if (uri == null) return false;
  final seg = uri.pathSegments;
  Widget? screen;

  if (seg.length == 3 && seg[0] == 'profile' && seg[1] == 'orders' && int.tryParse(seg[2]) != null) {
    screen = OrderDetailScreen(orderId: int.parse(seg[2]));
  } else if (seg.length == 2 && seg[0] == 'profile' && seg[1] == 'orders') {
    screen = MyOrdersScreen(initialTab: uri.queryParameters['tab'] ?? 'all');
  } else if (seg.length == 2 && seg[0] == 'products') {
    screen = ProductDetailScreen(slug: seg[1]);
  } else if (seg.length == 2 && seg[0] == 'store' && int.tryParse(seg[1]) != null) {
    screen = StoreScreen(sellerId: int.parse(seg[1]));
  } else if (seg.length == 1 && seg[0] == 'my-vouchers') {
    screen = const VouchersScreen();
  } else if (seg.length == 1 && seg[0] == 'wishlist') {
    screen = const WishlistScreen();
  } else if (seg.length == 3 && seg[0] == 'messages' && seg[1] == 'direct') {
    screen = ChatScreen(type: 'direct', id: seg[2]);
  } else if (seg.length == 1 && seg[0] == 'messages') {
    screen = const ChatListScreen();
  } else if (seg.isNotEmpty && seg[0] == 'seller') {
    screen = _sellerScreen(seg);
  } else if (seg.isNotEmpty && seg[0] == 'courier') {
    screen = _courierScreen(seg, context.read<AuthProvider>().user?.home == 'rider');
  } else if (seg.isNotEmpty && seg[0] == 'sc') {
    screen = _logisticsScreen(seg);
  }

  if (screen == null || !context.mounted) return false;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  return true;
}

int? _id(List<String> seg, int i) => seg.length > i ? int.tryParse(seg[i]) : null;

/// The seller panel's pages (seller.*) as app screens.
Widget? _sellerScreen(List<String> seg) {
  final page = seg.length > 1 ? seg[1] : '';
  return switch (page) {
    '' => const SellerDashboardScreen(),
    'orders' when _id(seg, 2) != null => SellerOrderDetailsScreen(orderId: _id(seg, 2)!),
    'orders' => const SellerOrdersScreen(),
    'books' when _id(seg, 2) != null => AddEditProductScreen(productId: _id(seg, 2)),
    'books' => const SellerProductsScreen(),
    'earnings' => const SellerEarningsScreen(),
    'reports' => const SellerReportsScreen(),
    'reviews' => const SellerReviewsScreen(),
    'vouchers' => const SellerVouchersScreen(),
    'flash-sales' => const SellerFlashSalesScreen(),
    'promotions' => const SellerPromotionsScreen(),
    'store-categories' => const SellerStoreCategoriesScreen(),
    'store-settings' => const SellerStoreSettingsScreen(),
    'account' when seg.length > 2 && seg[2] == 'security' => const SecurityScreen(),
    'account' => const SellerAccountScreen(),
    'status' => const SellerStatusScreen(),
    _ => null,
  };
}

/// The courier portal's pages (courier.*) as app screens. A rider of a logistics company works from Hub Jobs.
Widget? _courierScreen(List<String> seg, bool rider) {
  final page = seg.length > 1 ? seg[1] : '';
  if (page == 'rider') {
    final sub = seg.length > 2 ? seg[2] : '';
    return switch (sub) {
      '' => const RiderJobsScreen(),
      'pickups' when _id(seg, 3) != null => RiderPickupScreen(pickupId: _id(seg, 3)!),
      'deliveries' when _id(seg, 3) != null => RiderDeliveryScreen(deliveryId: _id(seg, 3)!),
      'cod' => const RiderCodScreen(),
      'earnings' => const RiderEarningsScreen(),
      'history' => const RiderHistoryScreen(),
      'profile' => const RiderProfileScreen(),
      _ => null,
    };
  }
  return switch (page) {
    '' => rider ? const RiderJobsScreen() : const CourierDashboardScreen(),
    'deliveries' when _id(seg, 2) != null => CourierDeliveryScreen(deliveryId: _id(seg, 2)!),
    'history' => const CourierHistoryScreen(),
    'profit' => const CourierProfitScreen(),
    'account' when seg.length > 2 && seg[2] == 'security' => const SecurityScreen(),
    'account' => const CourierAccountScreen(),
    'status' => const CourierStatusScreen(),
    _ => null,
  };
}

/// The logistics company's pages (sc.*) as app screens.
Widget? _logisticsScreen(List<String> seg) {
  final page = seg.length > 1 ? seg[1] : '';
  return switch (page) {
    'dashboard' || '' => const LogisticsDashboardScreen(),
    'pickup-requests' => const PickupRequestsScreen(),
    'incoming-parcels' => const IncomingScreen(),
    'parcel-sorting' => const SortingScreen(),
    'delivery-assignment' => const AssignmentScreen(),
    'delivery-monitoring' => const MonitoringScreen(),
    'rts' => const RtsScreen(),
    'shipments' => const ShipmentsScreen(),
    'transfers' => const TransfersScreen(),
    'tracking' when _id(seg, 2) != null => TrackingDetailScreen(parcelId: _id(seg, 2)!),
    'tracking' => const TrackingBoardScreen(),
    'commissions' => const LogisticsCommissionsScreen(),
    'dispatch' => const DispatchScreen(),
    'riders' when _id(seg, 2) != null => RiderDetailScreen(riderId: _id(seg, 2)!),
    'riders' => const RidersScreen(),
    'remittances' => const RemittancesScreen(),
    'courier-applications' when _id(seg, 2) != null => CourierDetailScreen(courierId: _id(seg, 2)!),
    'courier-applications' => const CouriersScreen(),
    'areas' => const CoverageScreen(),
    'rates' => const RatesScreen(),
    'reports' => const LogisticsReportsScreen(),
    'activity' => const ActivityScreen(),
    'chat' => const LogisticsChatScreen(),
    'account' => const LogisticsAccountScreen(),
    _ => null,
  };
}
