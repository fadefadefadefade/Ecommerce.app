import 'api_client.dart';

/// A courier of a logistics company (/api/v1/linehaul): duty, hub-to-hub trips, history, earnings and profile.
class LinehaulApi {
  static const _p = '/linehaul';

  static Future<ApiResponse> home() => ApiClient.get('$_p/home');

  /// Going On Duty sends the checklist ({'Tires': 'ok' | 'not_ok', …}), a note for Not OK items and the location.
  static Future<ApiResponse> duty(bool on, {Map<String, String>? items, String? note, Map<String, dynamic> location = const {}}) =>
      ApiClient.post('$_p/duty', {'on': on, if (items != null) 'items': items, if (note != null && note.isNotEmpty) 'note': note, ...location});
  static Future<ApiResponse> ping(Map<String, dynamic> location) => ApiClient.post('$_p/ping', location);

  static Future<ApiResponse> trip(int id) => ApiClient.get('$_p/trips/$id');
  static Future<ApiResponse> accept(int id) => ApiClient.post('$_p/trips/$id/accept');
  static Future<ApiResponse> decline(int id, String reason) => ApiClient.post('$_p/trips/$id/decline', {'reason': reason});
  static Future<ApiResponse> startLoading(int id) => ApiClient.post('$_p/trips/$id/loading');
  static Future<ApiResponse> scan(int id, String tracking) => ApiClient.post('$_p/trips/$id/scan', {'tracking': tracking});
  static Future<ApiResponse> depart(int id, String seal, Map<String, dynamic> location) =>
      ApiClient.post('$_p/trips/$id/depart', {'seal_number': seal, ...location});
  static Future<ApiResponse> delay(int id, String reason, String eta, {String? photo}) =>
      ApiClient.multipart('$_p/trips/$id/delay', {'reason': reason, 'eta': eta}, files: {if (photo != null) 'photo': photo});
  static Future<ApiResponse> arrived(int id, Map<String, dynamic> location) => ApiClient.post('$_p/trips/$id/arrived', location);
  static Future<ApiResponse> note(int id, String note) => ApiClient.post('$_p/trips/$id/note', {'note': note});

  static Future<ApiResponse> history({String? from, String? to}) => ApiClient.get('$_p/history', query: {'from': from, 'to': to});
  static Future<ApiResponse> earnings({String? from, String? to}) => ApiClient.get('$_p/earnings', query: {'from': from, 'to': to});

  static Future<ApiResponse> profile() => ApiClient.get('$_p/profile');
  static Future<ApiResponse> updateProfile(Map<String, String> fields, Map<String, String> files) => ApiClient.multipart('$_p/profile', fields, files: files);
  static Future<ApiDownload> document(String which) => ApiClient.download('$_p/documents/$which');
}
