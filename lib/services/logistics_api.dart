import 'api_client.dart';

/// The logistics company's (sorting center) part of the web API (/api/v1/logistics), with the website's rules and messages.
class LogisticsApi {
  static const _p = '/logistics';

  // ── Parcels through the hub ──
  static Future<ApiResponse> dashboard({String? from, String? to}) => ApiClient.get('$_p/dashboard', query: {'from': from, 'to': to});
  static Future<ApiResponse> shipments({String? status, String? q, String? from, String? to, int page = 1}) =>
      ApiClient.get('$_p/shipments', query: {'status': status, 'q': q, 'from': from, 'to': to, 'page': page});
  static Future<ApiResponse> parcel(int id) => ApiClient.get('$_p/parcels/$id');
  static Future<ApiResponse> markException(int id, String type, String reason, {String? photo}) =>
      ApiClient.multipart('$_p/parcels/$id/exception', {'type': type, 'reason': reason}, files: {if (photo != null) 'photo': photo});
  static Future<ApiResponse> pickupRequests({String tab = 'pending', int page = 1}) => ApiClient.get('$_p/pickup-requests', query: {'tab': tab, 'page': page});
  static Future<ApiResponse> approvePickup(int id) => ApiClient.post('$_p/pickup-requests/$id/approve');
  static Future<ApiResponse> rejectPickup(int id, String reason) => ApiClient.post('$_p/pickup-requests/$id/reject', {'reason': reason});
  static Future<ApiResponse> incoming({String tab = 'all', String? search, int page = 1}) =>
      ApiClient.get('$_p/incoming', query: {'tab': tab, 'search': search, 'page': page});
  static Future<ApiResponse> scan(String tracking, {int? hubId}) => ApiClient.post('$_p/incoming/scan', {'tracking_number': tracking, if (hubId != null) 'hub_id': hubId});
  static Future<ApiResponse> receive(int id, {int? hubId}) => ApiClient.post('$_p/incoming/$id/receive', {if (hubId != null) 'hub_id': hubId});
  static Future<ApiResponse> sorting() => ApiClient.get('$_p/sorting');
  static Future<ApiResponse> sort(int id, int areaId) => ApiClient.post('$_p/sorting/$id', {'area_id': areaId});
  static Future<ApiResponse> assignment({int? areaId, int page = 1}) => ApiClient.get('$_p/assignment', query: {'area_id': areaId, 'page': page});
  static Future<ApiResponse> assign(int parcelId, int riderId) => ApiClient.post('$_p/assignment/$parcelId', {'rider_id': riderId});
  static Future<ApiResponse> monitoring({String? status, int page = 1}) => ApiClient.get('$_p/monitoring', query: {'status': status, 'page': page});
  static Future<ApiResponse> overrideStatus(int deliveryId, String status, String remarks) =>
      ApiClient.post('$_p/deliveries/$deliveryId/status', {'status': status, 'remarks': remarks});
  static Future<ApiResponse> reschedule(int deliveryId) => ApiClient.post('$_p/deliveries/$deliveryId/reschedule');
  static Future<ApiResponse> returnToSender(int deliveryId) => ApiClient.post('$_p/deliveries/$deliveryId/return');
  static Future<ApiResponse> rts() => ApiClient.get('$_p/rts');
  static Future<ApiResponse> assignRts(int parcelId, int riderId) => ApiClient.post('$_p/rts/$parcelId', {'rider_id': riderId});
  static Future<ApiResponse> transfers({String? search}) => ApiClient.get('$_p/transfers', query: {'search': search});
  static Future<ApiResponse> initiateTransfer(int parcelId, int toId, String reason, {int? transporterId}) => ApiClient.post('$_p/transfers',
      {'parcel_id': parcelId, 'to_sorting_center_id': toId, 'reason': reason, if (transporterId != null) 'transporter_rider_id': transporterId});
  static Future<ApiResponse> transferAction(int id, String action, [Map<String, dynamic>? body]) => ApiClient.post('$_p/transfers/$id/$action', body);

  // ── The website's Shipment Board (tracking), Commissions and waybills ──
  static Future<ApiResponse> tracking({String tab = 'incoming', String? q, String? status, int page = 1}) =>
      ApiClient.get('$_p/tracking', query: {'tab': tab, 'q': q, 'status': status, 'page': page});
  static Future<ApiResponse> trackingParcel(int id) => ApiClient.get('$_p/tracking/$id');
  /// Confirm Package Received after checking it: condition good / damaged (notes required if damaged).
  static Future<ApiResponse> confirmReceived(int id, String condition, String? notes) =>
      ApiClient.post('$_p/tracking/$id/receive', {'condition': condition, if (notes != null && notes.isNotEmpty) 'notes': notes});
  static Future<ApiResponse> startSorting(int id) => ApiClient.post('$_p/tracking/$id/start-sorting');
  /// type: damaged_on_arrival, missing, other.
  static Future<ApiResponse> flagException(int id, String type, String details) => ApiClient.post('$_p/tracking/$id/exception', {'type': type, 'details': details});
  static Future<ApiResponse> toggleTransport(int riderId) => ApiClient.post('$_p/riders/$riderId/transport');
  static Future<ApiResponse> commissions({String period = 'month', String? from, String? to, String? status, int page = 1}) =>
      ApiClient.get('$_p/commissions', query: {'period': period, 'from': from, 'to': to, 'status': status, 'page': page});
  static Future<ApiDownload> exportCommissions(String format, {String period = 'month', String? from, String? to, String? status}) =>
      ApiClient.download('$_p/commissions/export', query: {'format': format, 'period': period, 'from': from, 'to': to, 'status': status});
  static Future<ApiResponse> waybills(List<int> ids) => ApiClient.get('$_p/waybills?${[for (final id in ids) 'ids%5B%5D=$id'].join('&')}');

  // ── Riders ──
  static Future<ApiResponse> dispatch() => ApiClient.get('$_p/dispatch');
  static Future<ApiResponse> autoAssign(int parcelId) => ApiClient.post('$_p/dispatch/$parcelId/auto');
  static Future<ApiResponse> manualAssign(int parcelId, int riderId) => ApiClient.post('$_p/dispatch/$parcelId/assign', {'rider_id': riderId});
  static Future<ApiResponse> reassign(int parcelId, int riderId) => ApiClient.post('$_p/dispatch/$parcelId/reassign', {'rider_id': riderId});
  static Future<ApiResponse> bulkAssign(int riderId, List<int> parcelIds) => ApiClient.post('$_p/dispatch/bulk', {'rider_id': riderId, 'parcel_ids': parcelIds});
  static Future<ApiResponse> riders({String tab = 'all', int page = 1}) => ApiClient.get('$_p/riders', query: {'tab': tab, 'page': page});
  static Future<ApiResponse> addRider(Map<String, dynamic> body) => ApiClient.post('$_p/riders', body);
  static Future<ApiResponse> rider(int id) => ApiClient.get('$_p/riders/$id');
  static Future<ApiResponse> riderAction(int id, String action, [Map<String, dynamic>? body]) => ApiClient.post('$_p/riders/$id/$action', body);
  static Future<ApiDownload> riderDocument(int id, String which) => ApiClient.download('$_p/riders/$id/documents/$which');
  static Future<ApiResponse> remittances({String? date, int page = 1}) => ApiClient.get('$_p/remittances', query: {'date': date, 'page': page});
  static Future<ApiResponse> confirmRemittance(int id) => ApiClient.post('$_p/remittances/$id/confirm');
  static Future<ApiResponse> couriers({String status = 'pending', int page = 1}) => ApiClient.get('$_p/couriers', query: {'status': status, 'page': page});
  static Future<ApiResponse> courier(int id) => ApiClient.get('$_p/couriers/$id');
  static Future<ApiResponse> approveCourier(int id) => ApiClient.post('$_p/couriers/$id/approve');
  static Future<ApiResponse> rejectCourier(int id, String reason) => ApiClient.post('$_p/couriers/$id/reject', {'rejection_reason': reason});
  static Future<ApiDownload> courierDocument(int id, String which) => ApiClient.download('$_p/couriers/$id/documents/$which');
  // Riders and couriers with their own login (Pending Activation until they set a password from the email), and hubs.
  static Future<ApiResponse> addRiderAccount(Map<String, String> fields, Map<String, String> files) =>
      ApiClient.multipart('$_p/riders/accounts', fields, files: files);
  static Future<ApiResponse> resendRiderActivation(int id) => ApiClient.post('$_p/riders/$id/resend-activation');
  static Future<ApiResponse> courierForm() => ApiClient.get('$_p/couriers/form');
  static Future<ApiResponse> addCourier(Map<String, String> fields, Map<String, String> files) => ApiClient.multipart('$_p/couriers', fields, files: files);
  static Future<ApiResponse> resendCourierActivation(int id) => ApiClient.post('$_p/couriers/$id/resend-activation');
  static Future<ApiResponse> hubs() => ApiClient.get('$_p/hubs');
  static Future<ApiResponse> addHub(Map<String, dynamic> body) => ApiClient.post('$_p/hubs', body);
  static Future<ApiResponse> updateHub(int id, Map<String, dynamic> body) => ApiClient.put('$_p/hubs/$id', body);

  // ── Hub-to-hub trips and couriers on duty ──
  static Future<ApiResponse> trips({String status = 'active', int page = 1}) => ApiClient.get('$_p/trips', query: {'status': status, 'page': page});
  static Future<ApiResponse> tripForm({int? originHubId}) => ApiClient.get('$_p/trips/form', query: {'origin_hub_id': originHubId});
  static Future<ApiResponse> createTrip(Map<String, dynamic> body) => ApiClient.post('$_p/trips', body);
  static Future<ApiResponse> trip(int id) => ApiClient.get('$_p/trips/$id');
  static Future<ApiResponse> assignTrip(int id, int courierId, {String? reason}) =>
      ApiClient.post('$_p/trips/$id/assign', {'courier_id': courierId, if (reason != null) 'reason': reason});
  static Future<ApiResponse> cancelTrip(int id, String reason) => ApiClient.post('$_p/trips/$id/cancel', {'reason': reason});
  static Future<ApiResponse> removeTripParcel(int id, int parcelId) => ApiClient.post('$_p/trips/$id/parcels/$parcelId/remove');
  static Future<ApiResponse> tripSeal(int id, String seal, {String? note}) => ApiClient.post('$_p/trips/$id/seal', {'seal_number': seal, if (note != null) 'note': note});
  static Future<ApiResponse> receiveParcel(int hubId, String tracking) => ApiClient.post('$_p/trips/receive', {'hub_id': hubId, 'tracking': tracking});
  static Future<ApiResponse> damagedParcel(int id, int parcelId, String? photo) =>
      ApiClient.multipart('$_p/trips/$id/parcels/$parcelId/damaged', {}, files: {if (photo != null) 'photo': photo});
  static Future<ApiResponse> closeReceiving(int id, {bool confirm = false}) => ApiClient.post('$_p/trips/$id/close', {'confirm': confirm});
  static Future<ApiResponse> dutyBoard() => ApiClient.get('$_p/linehaul-couriers');
  static Future<ApiResponse> suspendCourier(int id, String reason) => ApiClient.post('$_p/couriers/$id/suspend', {'reason': reason});
  static Future<ApiResponse> reactivateCourier(int id) => ApiClient.post('$_p/couriers/$id/reactivate');
  static Future<ApiResponse> verifyCourier(int id) => ApiClient.post('$_p/couriers/$id/verify');

  // ── The company ──
  static Future<ApiResponse> areas() => ApiClient.get('$_p/areas');
  static Future<ApiResponse> addArea(String psgc, String? code) => ApiClient.post('$_p/areas', {'barangay_psgc': psgc, 'barangay_code': code});
  static Future<ApiResponse> removeArea(int id) => ApiClient.delete('$_p/areas/$id');
  static Future<ApiResponse> rates() => ApiClient.get('$_p/rates');
  static Future<ApiResponse> updateRate(String route, String first, String additional) =>
      ApiClient.post('$_p/rates', {'route': route, 'first_kg': first, 'additional_kg': additional});
  static Future<ApiResponse> addZone(String provinceCode, String name, String first, String additional) =>
      ApiClient.post('$_p/zones', {'province_code': provinceCode, 'name': name, 'first_kg': first, 'additional_kg': additional});
  static Future<ApiResponse> reports({String? from, String? to}) => ApiClient.get('$_p/reports', query: {'from': from, 'to': to});
  static Future<ApiDownload> exportReport(String tab, String format, {String? from, String? to}) =>
      ApiClient.download('$_p/reports/export', query: {'tab': tab, 'format': format, 'from': from, 'to': to});
  static Future<ApiResponse> activity({int page = 1}) => ApiClient.get('$_p/activity', query: {'page': page});
  static Future<ApiResponse> chat({int? contactId}) => ApiClient.get('$_p/chat', query: {'contact_id': contactId});
  static Future<ApiResponse> sendMessage(int receiverId, String body) => ApiClient.post('$_p/chat', {'receiver_id': receiverId, 'body': body});
  static Future<ApiResponse> pollMessages(int contactId, int? afterId) => ApiClient.get('$_p/chat/poll', query: {'contact_id': contactId, 'after_id': afterId});
  static Future<ApiResponse> account() => ApiClient.get('$_p/account');
  static Future<ApiResponse> updateAccount(Map<String, dynamic> body) => ApiClient.put('$_p/account', body);
}
