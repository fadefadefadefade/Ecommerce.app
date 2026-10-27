import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Address pickers from the web's PSA PSGC dataset (/api/psgc), the same lists the website uses.
/// NCR has no provinces: its cities sit directly under the region, so load them with the region code.
class PsgcService {
  static Future<List<Map<String, dynamic>>> _list(String path) async {
    try {
      final res = await http
          .get(Uri.parse('${ApiConfig.psgcUrl}$path'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = data is Map ? (data['data'] ?? []) : data;
      return List<Map<String, dynamic>>.from((list as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRegions() => _list('/regions');

  /// Empty for NCR (use getMunicipalities with the region code instead).
  static Future<List<Map<String, dynamic>>> getProvincesByRegion(String regionCode) =>
      _list('/regions/$regionCode/provinces');

  /// Same as [getProvincesByRegion] (older screens use this name).
  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) => getProvincesByRegion(regionCode);

  /// Cities/municipalities of a province — or of a region with no provinces (NCR).
  static Future<List<Map<String, dynamic>>> getMunicipalities(String provinceOrRegionCode) =>
      _list('/provinces/$provinceOrRegionCode/municipalities');

  static Future<List<Map<String, dynamic>>> getBarangays(String municipalityCode) =>
      _list('/municipalities/$municipalityCode/barangays');
}
