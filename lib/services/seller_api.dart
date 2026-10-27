import 'api_client.dart';

/// The seller panel of the web API (/api/v1/seller). Every call follows the website's rules and messages.
class SellerApi {
  static Future<ApiResponse> status() => ApiClient.get('/seller/status');
  static Future<ApiResponse> resubmit(Map<String, String> files) => ApiClient.multipart('/seller/status/resubmit', {}, files: files);

  /// period: today, week, month (default) or custom with from / to (Y-m-d) — the website's dashboard range.
  static Future<ApiResponse> dashboard({String period = 'month', String? from, String? to}) =>
      ApiClient.get('/seller/dashboard', query: {'period': period, 'from': from, 'to': to});
  static Future<ApiResponse> commissions({String period = 'month', String? from, String? to, String? status, int page = 1}) =>
      ApiClient.get('/seller/commissions', query: {'period': period, 'from': from, 'to': to, 'status': status, 'page': page});
  static Future<ApiDownload> exportCommissions(String format, {String period = 'month', String? from, String? to, String? status}) =>
      ApiClient.download('/seller/commissions/export', query: {'format': format, 'period': period, 'from': from, 'to': to, 'status': status});
  static Future<ApiResponse> reports({String? from, String? to}) => ApiClient.get('/seller/reports', query: {'from': from, 'to': to});
  /// The website's report file: format csv or xlsx.
  /// The GCash receipt the buyer uploaded (orders paid by GCash receipt).
  static Future<ApiDownload> paymentProof(int orderId) => ApiClient.download('/seller/orders/$orderId/payment-proof');
  static Future<ApiDownload> exportReport(String format, {String? from, String? to}) =>
      ApiClient.download('/seller/reports/export', query: {'format': format, 'from': from, 'to': to});

  // Inventory
  /// The website's inventory: status tab, search, category_id, min_price, max_price, sort, page (25 a page).
  static Future<ApiResponse> products({String status = 'active', String? search, int? categoryId, String? minPrice, String? maxPrice, String? sort, int page = 1}) =>
      ApiClient.get('/seller/products', query: {
        'status': status, 'search': search, 'category_id': categoryId, 'min_price': minPrice, 'max_price': maxPrice, 'sort': sort, 'page': page,
      });
  static Future<ApiResponse> productForm() => ApiClient.get('/seller/products/form');
  static Future<ApiResponse> product(int id) => ApiClient.get('/seller/products/$id');
  static Future<ApiResponse> createProduct(Map<String, String> fields, Map<String, String> files) =>
      ApiClient.multipart('/seller/products', fields, files: files);
  static Future<ApiResponse> updateProduct(int id, Map<String, String> fields, Map<String, String> files) =>
      ApiClient.multipart('/seller/products/$id', fields, files: files);
  static Future<ApiResponse> deleteProduct(int id) => ApiClient.delete('/seller/products/$id');
  static Future<ApiResponse> duplicate(int id) => ApiClient.post('/seller/products/$id/duplicate');
  static Future<ApiResponse> endSale(int id) => ApiClient.patch('/seller/products/$id/end-sale');
  static Future<ApiResponse> archive(int id) => ApiClient.patch('/seller/products/$id/archive');
  static Future<ApiResponse> unarchive(int id) => ApiClient.patch('/seller/products/$id/unarchive');
  static Future<ApiResponse> stock(int id, int stock) => ApiClient.patch('/seller/products/$id/stock', {'stock': stock});
  static Future<ApiResponse> bulk(String action, List<int> ids) => ApiClient.post('/seller/products/bulk', {'action': action, 'ids': ids});

  // Orders
  static Future<ApiResponse> orders({String tab = 'new', int page = 1, String? q}) =>
      ApiClient.get('/seller/orders', query: {'tab': tab, 'page': page, if (q != null && q.isNotEmpty) 'q': q});
  static Future<ApiResponse> order(int id) => ApiClient.get('/seller/orders/$id');
  static Future<ApiResponse> accept(int id) => ApiClient.post('/seller/orders/$id/accept');
  static Future<ApiResponse> pack(int id) => ApiClient.post('/seller/orders/$id/pack');
  static Future<ApiResponse> cancel(int id, String reason, String details) =>
      ApiClient.post('/seller/orders/$id/cancel', {'reason': reason, 'details': details});
  static Future<ApiResponse> handover(int id, Map<String, dynamic> body) => ApiClient.post('/seller/orders/$id/handover', body);
  static Future<ApiResponse> handedOver(int id) => ApiClient.post('/seller/orders/$id/handed-over');
  static Future<ApiResponse> decideReturn(int id, String decision, String note) =>
      ApiClient.post('/seller/orders/$id/return', {'decision': decision, 'seller_note': note});
  static Future<ApiResponse> returnedReceived(int id) => ApiClient.post('/seller/orders/$id/returned-received');
  static Future<ApiResponse> waybill(int id) => ApiClient.get('/seller/orders/$id/waybill');

  // Marketing
  static Future<ApiResponse> vouchers() => ApiClient.get('/seller/vouchers');
  static Future<ApiResponse> voucherForm([int? id]) => ApiClient.get(id == null ? '/seller/vouchers/form' : '/seller/vouchers/form/$id');
  static Future<ApiResponse> saveVoucher(int? id, Map<String, dynamic> body) =>
      id == null ? ApiClient.post('/seller/vouchers', body) : ApiClient.put('/seller/vouchers/$id', body);
  static Future<ApiResponse> toggleVoucher(int id) => ApiClient.patch('/seller/vouchers/$id/toggle');
  static Future<ApiResponse> deleteVoucher(int id) => ApiClient.delete('/seller/vouchers/$id');

  static Future<ApiResponse> flashSales() => ApiClient.get('/seller/flash-sales');
  static Future<ApiResponse> addFlashSale(Map<String, dynamic> body) => ApiClient.post('/seller/flash-sales', body);
  static Future<ApiResponse> deleteFlashSale(int id) => ApiClient.delete('/seller/flash-sales/$id');

  static Future<ApiResponse> promotions() => ApiClient.get('/seller/promotions');
  static Future<ApiResponse> addPromotion(Map<String, dynamic> body) => ApiClient.post('/seller/promotions', body);
  static Future<ApiResponse> togglePromotion(int id) => ApiClient.patch('/seller/promotions/$id/toggle');
  static Future<ApiResponse> deletePromotion(int id) => ApiClient.delete('/seller/promotions/$id');

  static Future<ApiResponse> storeCategories() => ApiClient.get('/seller/store-categories');
  /// Adds an ALVY category (see "available" in [storeCategories]) to the store.
  static Future<ApiResponse> addStoreCategory(int categoryId) => ApiClient.post('/seller/store-categories', {'category_id': categoryId});
  static Future<ApiResponse> renameStoreCategory(int id, String name) => ApiClient.put('/seller/store-categories/$id', {'name': name});
  static Future<ApiResponse> reorderStoreCategories(List<int> ids) => ApiClient.post('/seller/store-categories/reorder', {'ids': ids});
  static Future<ApiResponse> toggleStoreCategory(int id) => ApiClient.patch('/seller/store-categories/$id/toggle');
  static Future<ApiResponse> deleteStoreCategory(int id, {bool confirm = false}) =>
      ApiClient.delete('/seller/store-categories/$id${confirm ? '?confirm=1' : ''}');

  // Reviews, earnings
  static Future<ApiResponse> reviews({int? stars, String? replied, int page = 1}) =>
      ApiClient.get('/seller/reviews', query: {'stars': stars, 'replied': replied, 'page': page});
  static Future<ApiResponse> reply(int reviewId, String reply) => ApiClient.post('/seller/reviews/$reviewId/reply', {'reply': reply});
  static Future<ApiResponse> earnings({int page = 1}) => ApiClient.get('/seller/earnings', query: {'page': page});
  static Future<ApiResponse> requestPayout(String amount, String token) =>
      ApiClient.post('/seller/earnings/payouts', {'amount': amount, 'request_token': token});

  // Account, store settings
  static Future<ApiResponse> account() => ApiClient.get('/seller/account');
  static Future<ApiResponse> updateAccount(Map<String, String> fields, {String? avatar}) =>
      ApiClient.multipart('/seller/account', fields, files: {if (avatar != null) 'avatar': avatar});
  static Future<ApiResponse> changePassword(String current, String password, String confirm, {String via = 'email'}) =>
      ApiClient.put('/seller/account/password', {'current_password': current, 'password': password, 'password_confirmation': confirm, 'code_via': via});
  static Future<ApiResponse> storeSettings() => ApiClient.get('/seller/store-settings');
  static Future<ApiResponse> updateStoreSettings(Map<String, String> fields, {String? logo, String? banner}) => ApiClient.multipart(
      '/seller/store-settings', fields, files: {if (logo != null) 'logo': logo, if (banner != null) 'banner': banner});
}
