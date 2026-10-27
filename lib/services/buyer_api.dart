import 'api_client.dart';

/// The buyer's part of the web API (/api/v1). Every call follows the website's rules and messages.
class BuyerApi {
  // Browsing
  static Future<ApiResponse> home() => ApiClient.get('/home');
  static Future<ApiResponse> forgotPassword(String email) => ApiClient.post('/auth/forgot-password', {'email': email});
  static Future<ApiResponse> voucherCenter({String tab = 'all'}) => ApiClient.get('/vouchers/center', query: {'tab': tab});
  static Future<ApiDownload> paymentProof(int orderId) => ApiClient.download('/orders/$orderId/payment-proof');
  static Future<ApiDownload> proofOfDelivery(int orderId) => ApiClient.download('/orders/$orderId/proof-of-delivery');
  // ALVY Assistant (the website's chat helper)
  static Future<ApiResponse> assistantHistory() => ApiClient.get('/assistant/history');
  static Future<ApiResponse> assistantAsk(String message) => ApiClient.post('/assistant/ask', {'message': message});
  static Future<ApiResponse> assistantConfirm(String token) => ApiClient.post('/assistant/actions/$token');
  static Future<ApiResponse> assistantReset() => ApiClient.post('/assistant/reset');
  static Future<ApiResponse> shop(Map<String, dynamic> query) => ApiClient.get('/shop', query: query);
  static Future<ApiResponse> categories() => ApiClient.get('/categories');
  static Future<ApiResponse> category(String slug, {String? sort}) => ApiClient.get('/categories/$slug', query: {'sort': sort});
  static Future<ApiResponse> product(String slugOrId) => ApiClient.get('/products/${productSlug(slugOrId)}');
  static Future<ApiResponse> store(int sellerId, Map<String, dynamic> query) => ApiClient.get('/stores/$sellerId', query: query);
  static Future<ApiResponse> policy(String key) => ApiClient.get('/policies/$key');

  /// The web's product links end with the id ("rattan-fruit-basket-12"); an id alone works too.
  static String productSlug(Object slugOrId) => slugOrId is int || int.tryParse('$slugOrId') != null ? 'p-$slugOrId' : '$slugOrId';

  // Cart
  static Future<ApiResponse> cart() => ApiClient.get('/cart');
  static Future<ApiResponse> addToCart(int productId, {int quantity = 1, int? variationId, bool buyNow = false}) =>
      ApiClient.post('/cart/$productId', {'quantity': quantity, if (variationId != null) 'variation_id': variationId, if (buyNow) 'action': 'buy_now'});
  static Future<ApiResponse> updateCart(int lineId, int quantity) => ApiClient.patch('/cart/item/$lineId', {'quantity': quantity});
  static Future<ApiResponse> removeFromCart(int lineId) => ApiClient.delete('/cart/item/$lineId');

  // Checkout
  static Future<ApiResponse> checkout({List<int>? items, bool buyNow = false, int? addressId}) => ApiClient.get('/checkout', query: {
        if (buyNow) 'buy_now': 1,
        if (addressId != null) 'address_id': addressId,
        for (var i = 0; i < (items ?? const []).length; i++) 'items[$i]': items![i],
      });
  static Future<ApiResponse> preview(Map<String, dynamic> body) => ApiClient.post('/checkout/preview', body);
  static Future<ApiResponse> placeOrder(Map<String, dynamic> body) => ApiClient.post('/checkout', body);

  /// GCash paid by receipt: the same order body, sent as a form with the screenshot (payment_proof).
  static Future<ApiResponse> placeOrderWithReceipt(Map<String, dynamic> body, String receiptPath) =>
      ApiClient.multipart('/checkout', formFields(body), files: {'payment_proof': receiptPath});

  /// A JSON body as form fields: nested maps and lists become key[sub] (the website's form names).
  static Map<String, String> formFields(Map<String, dynamic> body, [String prefix = '']) {
    final out = <String, String>{};
    body.forEach((k, v) {
      final key = prefix.isEmpty ? k : '$prefix[$k]';
      if (v == null) return;
      if (v is Map) {
        out.addAll(formFields(Map<String, dynamic>.from(v), key));
      } else if (v is List) {
        for (var i = 0; i < v.length; i++) {
          final item = v[i];
          item is Map ? out.addAll(formFields(Map<String, dynamic>.from(item), '$key[$i]')) : out['$key[$i]'] = '$item';
        }
      } else {
        out[key] = v is bool ? (v ? '1' : '0') : '$v';
      }
    });
    return out;
  }

  // My Purchases
  static Future<ApiResponse> orders({String tab = 'all', int page = 1}) => ApiClient.get('/orders', query: {'tab': tab, 'page': page});
  static Future<ApiResponse> order(int id) => ApiClient.get('/orders/$id');
  static Future<ApiResponse> cancel(int id, String reason) => ApiClient.post('/orders/$id/cancel', {'cancellation_reason': reason});
  static Future<ApiResponse> received(int id) => ApiClient.post('/orders/$id/received');
  static Future<ApiResponse> escalate(int id, String note) => ApiClient.post('/orders/$id/escalate', {'dispute_note': note});
  static Future<ApiResponse> pay(int id) => ApiClient.post('/orders/$id/pay');
  static Future<ApiResponse> requestReturn(int id, Map<String, String> fields, List<String> photos) => ApiClient.multipart(
      '/orders/$id/return', fields, files: {for (var i = 0; i < photos.length; i++) 'evidence_photos[$i]': photos[i]});
  static Future<ApiResponse> review(int itemId, Map<String, String> fields, List<String> photos) => ApiClient.multipart(
      '/reviews/item/$itemId', fields, files: {for (var i = 0; i < photos.length; i++) 'photos[$i]': photos[i]});
  static Future<ApiResponse> editReview(int reviewId, Map<String, String> fields, List<String> photos) => ApiClient.multipart(
      '/reviews/$reviewId', fields, files: {for (var i = 0; i < photos.length; i++) 'photos[$i]': photos[i]});

  // Account
  static Future<ApiResponse> profile() => ApiClient.get('/profile');
  static Future<ApiResponse> updateProfile(Map<String, String> fields, {String? avatar}) =>
      ApiClient.multipart('/profile', fields, files: {if (avatar != null) 'avatar': avatar});
  static Future<ApiResponse> changePassword(String current, String password, String confirm, {String via = 'email'}) =>
      ApiClient.patch('/profile/password', {'current_password': current, 'password': password, 'password_confirmation': confirm, 'code_via': via});
  static Future<ApiResponse> changeEmail(String email) => ApiClient.post('/profile/email', {'email': email});
  static Future<ApiResponse> changePhone(String phone) => ApiClient.post('/profile/phone', {'phone': phone});
  static Future<ApiResponse> verifyContact(String code) => ApiClient.post('/profile/contact/verify', {'code': code});
  static Future<ApiResponse> resendContact() => ApiClient.post('/profile/contact/resend');
  static Future<ApiResponse> cancelContact() => ApiClient.post('/profile/contact/cancel');

  static Future<ApiResponse> addresses() => ApiClient.get('/addresses');
  static Future<ApiResponse> addAddress(Map<String, dynamic> body) => ApiClient.post('/addresses', body);
  static Future<ApiResponse> updateAddress(int id, Map<String, dynamic> body) => ApiClient.patch('/addresses/$id', body);
  static Future<ApiResponse> deleteAddress(int id) => ApiClient.delete('/addresses/$id');
  static Future<ApiResponse> defaultAddress(int id) => ApiClient.patch('/addresses/$id/default');

  static Future<ApiResponse> notifications({int page = 1}) => ApiClient.get('/notifications', query: {'page': page});
  static Future<ApiResponse> openNotification(int id) => ApiClient.post('/notifications/$id/open');
  static Future<ApiResponse> readAllNotifications() => ApiClient.post('/notifications/read-all');

  static Future<ApiResponse> wishlist() => ApiClient.get('/wishlist');
  static Future<ApiResponse> toggleWish(int productId, {bool? on}) =>
      ApiClient.post('/wishlist/$productId', {if (on != null) 'state': on ? 'on' : 'off'});
  static Future<ApiResponse> vouchers() => ApiClient.get('/vouchers');
  static Future<ApiResponse> claimVoucher(int id) => ApiClient.post('/vouchers/$id/claim');
  static Future<ApiResponse> following() => ApiClient.get('/following');
  static Future<ApiResponse> toggleFollow(int sellerId) => ApiClient.post('/stores/$sellerId/follow');
  static Future<ApiResponse> remindFlashSale(int flashSaleId) => ApiClient.post('/flash-sales/$flashSaleId/remind');

  // Chat (every role)
  static Future<ApiResponse> threads() => ApiClient.get('/messages');
  static Future<ApiResponse> thread(String type, String id) => ApiClient.get('/messages/$type/$id');
  static Future<ApiResponse> send(String type, String id, String body) => ApiClient.post('/messages/$type/$id', {'body': body});
  static Future<ApiResponse> startChat(int receiverId, {int? productId}) =>
      ApiClient.post('/messages/start', {'receiver_id': receiverId, if (productId != null) 'product_id': productId});
}
