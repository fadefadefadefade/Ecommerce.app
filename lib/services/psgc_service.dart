import '../config/api_config.dart';
import 'api_service.dart';

class PsgcService {
  static Future<List<Map<String, dynamic>>> getRegions() async {
    try {
      final response = await ApiService.get('/psgc/regions');
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProvincesByRegion(
      String regionCode) async {
    try {
      final response =
          await ApiService.get('/psgc/regions/$regionCode/provinces');
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getMunicipalities(
      String provinceCode) async {
    try {
      final response =
          await ApiService.get('/psgc/provinces/$provinceCode/municipalities');
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getBarangays(
      String municipalityCode) async {
    try {
      final response = await ApiService.get(
          '/psgc/municipalities/$municipalityCode/barangays');
      if (response['success']) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
