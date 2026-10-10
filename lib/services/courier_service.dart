import 'api_service.dart';

/// Courier (rider) API — /api/courier/*.
class CourierService {
  static Future<Map<String, dynamic>> dashboard() async =>
      ApiService.unwrap(await ApiService.get('/courier/dashboard'));

  /// [tab] is 'active' (to deliver / delivering) or 'history'.
  static Future<List<Map<String, dynamic>>> deliveries({String tab = 'active'}) async {
    final data = ApiService.unwrap(await ApiService.get('/courier/deliveries?tab=$tab'));
    return (data['deliveries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> delivery(int id) async {
    final data = ApiService.unwrap(await ApiService.get('/courier/deliveries/$id'));
    return Map<String, dynamic>.from(data['delivery']);
  }

  /// To Deliver → Delivering
  static Future<String> start(int id) => _action('/courier/deliveries/$id/start');

  /// Delivering → Delivered
  static Future<String> deliver(int id) => _action('/courier/deliveries/$id/deliver');

  /// Could not deliver; logistics will re-assign.
  static Future<String> fail(int id, String reason) =>
      _action('/courier/deliveries/$id/fail', {'reason': reason});

  static Future<String> _action(String path, [Map<String, dynamic>? body]) async {
    final data = ApiService.unwrap(await ApiService.post(path, body: body ?? {}));
    return data['message']?.toString() ?? 'Done.';
  }
}
