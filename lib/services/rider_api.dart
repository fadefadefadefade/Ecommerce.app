import 'api_client.dart';

/// Riders of a logistics company (/api/v1/rider) and direct couriers (/api/v1/courier), with the website's rules and messages.
class RiderApi {
  // ── Rider (Hub Jobs) ──
  static Future<ApiResponse> jobs() => ApiClient.get('/rider/jobs');
  static Future<ApiResponse> setOnline(bool online) => ApiClient.post('/rider/online', {'online': online});
  static Future<ApiResponse> acceptOffer(int id) => ApiClient.post('/rider/offers/$id/accept');
  static Future<ApiResponse> declineOffer(int id) => ApiClient.post('/rider/offers/$id/decline');
  // A job the hub assigned (kind: pickup / delivery): "I saw it", can't do it (reason), and "On my way" to the seller.
  static Future<ApiResponse> acknowledgeJob(String kind, int id) => ApiClient.post('/rider/jobs/$kind/$id/acknowledge');
  static Future<ApiResponse> declineJob(String kind, int id, String reason) => ApiClient.post('/rider/jobs/$kind/$id/decline', {'reason': reason});
  static Future<ApiResponse> onMyWay(int pickupId) => ApiClient.post('/rider/pickups/$pickupId/arriving');
  static Future<ApiResponse> remittanceReceipt(int id) => ApiClient.get('/rider/cod/remittances/$id');
  static Future<ApiResponse> pickup(int id) => ApiClient.get('/rider/pickups/$id');
  static Future<ApiResponse> confirmPickup(int id, String tracking) => ApiClient.post('/rider/pickups/$id/confirm', {'tracking_number': tracking});
  static Future<ApiResponse> delivery(int id) => ApiClient.get('/rider/deliveries/$id');
  static Future<ApiResponse> startDelivery(int id) => ApiClient.post('/rider/deliveries/$id/start');
  static Future<ApiResponse> deliver(int id, {required String otp, String? cod, String? photo}) => ApiClient.multipart(
      '/rider/deliveries/$id/deliver', {'otp': otp, if (cod != null) 'cod_collected': cod}, files: {if (photo != null) 'pod_photo': photo});
  static Future<ApiResponse> failDelivery(int id, String reason) => ApiClient.post('/rider/deliveries/$id/fail', {'reason': reason});
  static Future<ApiResponse> returnedToSeller(int parcelId) => ApiClient.post('/rider/returns/$parcelId/returned');
  static Future<ApiResponse> profile() => ApiClient.get('/rider/profile');
  static Future<ApiResponse> updateProfile(Map<String, String> fields, {String? licenseFile, String? orCrFile}) => ApiClient.multipart(
      '/rider/profile', fields, files: {if (licenseFile != null) 'license_file': licenseFile, if (orCrFile != null) 'or_cr_file': orCrFile});
  static Future<ApiDownload> document(String which) => ApiClient.download('/rider/documents/$which');
  static Future<ApiResponse> history({String? from, String? to}) => ApiClient.get('/rider/history', query: {'from': from, 'to': to});
  /// period: today, week (default), last_week, month — the website's Rider Pay.
  static Future<ApiResponse> earnings({String period = 'week'}) => ApiClient.get('/rider/earnings', query: {'period': period});
  static Future<ApiResponse> cod() => ApiClient.get('/rider/cod');
  static Future<ApiResponse> remit(String amount, String token) => ApiClient.post('/rider/cod/remit', {'amount': amount, 'request_token': token});

  // ── Direct courier ──
  static Future<ApiResponse> courierStatus() => ApiClient.get('/courier/status');
  static Future<ApiResponse> courierDashboard() => ApiClient.get('/courier/dashboard');
  static Future<ApiResponse> courierDelivery(int id) => ApiClient.get('/courier/deliveries/$id');
  static Future<ApiResponse> courierAction(int id, String action, [Map<String, dynamic>? body]) =>
      ApiClient.post('/courier/deliveries/$id/$action', body);
  /// q: an order # or tracking no. · status: in_progress, delivered, failed · date (Y-m-d).
  static Future<ApiResponse> courierHistory({String? status, String? q, String? date, int page = 1}) =>
      ApiClient.get('/courier/history', query: {'status': status, 'q': q, 'date': date, 'page': page});
  static Future<ApiResponse> courierProfit() => ApiClient.get('/courier/profit');
  static Future<ApiResponse> courierAccount() => ApiClient.get('/courier/account');
  static Future<ApiResponse> updateCourierAccount(String contactNo, {String? avatar}) =>
      ApiClient.multipart('/courier/account', {'contact_no': contactNo}, files: {if (avatar != null) 'avatar': avatar});

  /// Riders and couriers change their password on the courier portal's security page.
  static Future<ApiResponse> changePassword(String current, String password, String confirm, {String via = 'email'}) =>
      ApiClient.put('/courier/account/password', {'current_password': current, 'password': password, 'password_confirmation': confirm, 'code_via': via});
}
