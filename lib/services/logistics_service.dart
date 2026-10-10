import '../config/api_config.dart';
import '../models/logistics.dart';
import 'api_service.dart';

class LogisticsException implements Exception {
  final String message;
  LogisticsException(this.message);

  @override
  String toString() => message;
}

/// API calls for the logistics (admin) panel — /api/logistics/*.
class LogisticsService {
  static const _base = ApiConfig.logistics;

  static String _withQuery(String path, Map<String, dynamic> params) {
    final query = <String, String>{};
    params.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        query[key] = value.toString();
      }
    });
    if (query.isEmpty) return path;
    return '$path?${Uri(queryParameters: query).query}';
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> result) {
    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data'] as Map);
    }
    final errors = result['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw LogisticsException(first.first.toString());
      }
    }
    throw LogisticsException(result['message']?.toString() ?? 'Something went wrong');
  }

  static Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic> params = const {}]) async {
    return _unwrap(await ApiService.get(_withQuery('$_base$path', params)));
  }

  static Future<String> _post(String path, [Map<String, dynamic>? body]) async {
    final data = _unwrap(await ApiService.post('$_base$path', body: body ?? {}));
    return data['message']?.toString() ?? 'Done.';
  }

  // ── Dashboard ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() => _get('/dashboard');

  // ── Riders ────────────────────────────────────────────────

  static Future<PagedResult<Rider>> getRiders({int page = 1, String? status, String? search}) async {
    final data = await _get('/riders', {'page': page, 'status': status, 'search': search});
    return PagedResult.fromJson(data, Rider.fromJson);
  }

  static Future<Rider> getRider(int id) async {
    final data = await _get('/riders/$id');
    return Rider.fromJson(Map<String, dynamic>.from(data['rider']));
  }

  static Future<String> approveRider(int id) => _post('/riders/$id/approve');

  static Future<String> disapproveRider(int id, String? reason) =>
      _post('/riders/$id/disapprove', {'rejection_reason': reason});

  static Future<String> toggleRiderActive(int id) => _post('/riders/$id/toggle-active');

  // ── Pickup requests ───────────────────────────────────────

  static Future<PagedResult<Parcel>> getPickupRequests({int page = 1, String tab = 'all', String? search}) async {
    final data = await _get('/pickup-requests', {'page': page, 'tab': tab, 'search': search});
    return PagedResult.fromJson(data, Parcel.fromJson);
  }

  static Future<String> approvePickup(int parcelId) => _post('/pickup-requests/$parcelId/approve');

  static Future<String> rejectPickup(int parcelId, String? reason) =>
      _post('/pickup-requests/$parcelId/reject', {'reason': reason});

  // ── Parcels & sorting ─────────────────────────────────────

  static Future<List<DeliveryArea>> getAreas() async {
    final data = await _get('/areas');
    return (data['areas'] as List)
        .map((e) => DeliveryArea.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<PagedResult<Parcel>> getParcels({int page = 1, String? status, String? search}) async {
    final data = await _get('/parcels', {'page': page, 'status': status, 'search': search});
    return PagedResult.fromJson(data, Parcel.fromJson);
  }

  static Future<Parcel> getParcel(int id) async {
    final data = await _get('/parcels/$id');
    return Parcel.fromJson(Map<String, dynamic>.from(data['parcel']));
  }

  static Future<String> markPickedUp(int parcelId) => _post('/parcels/$parcelId/mark-picked-up');

  static Future<String> sortParcel(int parcelId, int areaId) =>
      _post('/parcels/$parcelId/sort', {'area_id': areaId});

  // ── Deliveries ────────────────────────────────────────────

  /// Sorted parcels waiting for a rider, plus the riders/areas to pick from.
  static Future<({PagedResult<Parcel> parcels, List<Rider> riders, List<DeliveryArea> areas})>
      getAssignment({int page = 1, int? areaId}) async {
    final data = await _get('/deliveries/assign', {'page': page, 'area_id': areaId});
    return (
      parcels: PagedResult.fromJson(Map<String, dynamic>.from(data['parcels']), Parcel.fromJson),
      riders: (data['riders'] as List).map((e) => Rider.fromJson(Map<String, dynamic>.from(e))).toList(),
      areas: (data['areas'] as List).map((e) => DeliveryArea.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  static Future<String> assignRider(int parcelId, int riderId) =>
      _post('/deliveries/$parcelId/assign', {'rider_id': riderId});

  static Future<({PagedResult<ParcelDelivery> deliveries, List<Rider> riders})> getMonitor({
    int page = 1,
    String? status,
    int? riderId,
  }) async {
    final data = await _get('/deliveries/monitor', {'page': page, 'status': status, 'rider_id': riderId});
    return (
      deliveries: PagedResult.fromJson(Map<String, dynamic>.from(data['deliveries']), ParcelDelivery.fromJson),
      riders: (data['riders'] as List).map((e) => Rider.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  static Future<String> updateDeliveryStatus(int deliveryId, String status, String? remarks) =>
      _post('/deliveries/$deliveryId/status', {'status': status, 'remarks': remarks});

  // ── Reports ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getReport({int page = 1, String? from, String? to}) =>
      _get('/reports', {'page': page, 'from': from, 'to': to});

  // ── Chat ──────────────────────────────────────────────────

  static Future<List<ChatContact>> getContacts({String? search}) async {
    final data = await _get('/chat/contacts', {'search': search});
    return (data['contacts'] as List)
        .map((e) => ChatContact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<ChatMessage>> getMessages(int contactId, {int? afterId}) async {
    final data = await _get('/chat/$contactId/messages', {'after_id': afterId});
    return (data['messages'] as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<ChatMessage> sendMessage(int receiverId, String body) async {
    final data = _unwrap(await ApiService.post(
      '$_base/chat/send',
      body: {'receiver_id': receiverId, 'body': body},
    ));
    return ChatMessage.fromJson(Map<String, dynamic>.from(data['message']));
  }

  // ── Account ───────────────────────────────────────────────

  /// Returns the updated user JSON (same shape as the login response).
  static Future<Map<String, dynamic>> updateAccount(String name, String email) async {
    final data = _unwrap(await ApiService.put('$_base/account', {'name': name, 'email': email}));
    return Map<String, dynamic>.from(data['user']);
  }

  static Future<String> updatePassword(String current, String password, String confirmation) async {
    final data = _unwrap(await ApiService.put('$_base/account/password', {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    }));
    return data['message']?.toString() ?? 'Password changed successfully.';
  }
}
