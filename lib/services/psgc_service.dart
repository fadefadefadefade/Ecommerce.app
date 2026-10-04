import 'api_service.dart';

class PsgcService {
  static Future<List<Map<String, dynamic>>> getRegions() async {
    try {
      print('PsgcService: Starting getRegions()');
      final response = await ApiService.get('/psgc/regions');
      print('PsgcService: Got response: $response');
      
      if (response['success']) {
        final data = List<Map<String, dynamic>>.from(response['data']);
        print('PsgcService: Parsed ${data.length} regions');
        return data;
      }
      print('PsgcService: Response not successful');
      return [];
    } catch (e) {
      print('PsgcService: Error in getRegions: $e');
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

  // Alias for getProvincesByRegion
  static Future<List<Map<String, dynamic>>> getProvinces(
      String regionCode) async {
    return getProvincesByRegion(regionCode);
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
