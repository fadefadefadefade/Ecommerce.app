import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/seller_product.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class SellerApiService {
  final AuthService _authService = AuthService();

  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get multipart headers for file uploads
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _authService.getToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  // Get seller dashboard data
  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/seller/dashboard'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get seller products with pagination and filters
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    String? status,
    String? search,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/seller/products')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'products': (data['products'] as List)
              .map((p) => SellerProduct.fromJson(p))
              .toList(),
          'pagination': data['pagination'] ?? {},
          'counts': data['counts'] ?? {},
        };
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get single product details
  Future<SellerProduct> getProduct(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SellerProduct.fromJson(data['product']);
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create new product
  Future<SellerProduct> createProduct(
    Map<String, dynamic> productData, {
    List<File>? images,
    File? video,
  }) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/seller/products'),
      );

      request.headers.addAll(headers);

      // Add product data fields
      productData.forEach((key, value) {
        if (value != null) {
          if (value is Map || value is List) {
            request.fields[key] = json.encode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Add cover image if provided
      if (images != null && images.isNotEmpty) {
        final coverImage = images.first;
        request.files.add(await http.MultipartFile.fromPath(
          'cover_image',
          coverImage.path,
          contentType: MediaType('image', _getFileExtension(coverImage.path)),
        ));

        // Add additional images
        for (int i = 0; i < images.length; i++) {
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            images[i].path,
            contentType: MediaType('image', _getFileExtension(images[i].path)),
          ));
        }
      }

      // Add video if provided
      if (video != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'video',
          video.path,
          contentType: MediaType('video', _getFileExtension(video.path)),
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(responseBody);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(responseBody);
        throw Exception(error['message'] ?? 'Failed to create product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update existing product
  Future<SellerProduct> updateProduct(
    int id,
    Map<String, dynamic> productData, {
    List<File>? newImages,
    File? newVideo,
    List<int>? removedImageIds,
    List<int>? imageOrder,
  }) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST', // Laravel uses POST with _method=PUT for file uploads
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id'),
      );

      request.headers.addAll(headers);
      request.fields['_method'] = 'PUT';

      // Add product data fields
      productData.forEach((key, value) {
        if (value != null) {
          if (value is Map || value is List) {
            request.fields[key] = json.encode(value);
          } else {
            request.fields[key] = value.toString();
          }
        }
      });

      // Add removed image IDs
      if (removedImageIds != null && removedImageIds.isNotEmpty) {
        for (int i = 0; i < removedImageIds.length; i++) {
          request.fields['removed_images[$i]'] = removedImageIds[i].toString();
        }
      }

      // Add image order
      if (imageOrder != null && imageOrder.isNotEmpty) {
        for (int i = 0; i < imageOrder.length; i++) {
          request.fields['image_order[$i]'] = imageOrder[i].toString();
        }
      }

      // Add new images
      if (newImages != null && newImages.isNotEmpty) {
        if (newImages.length == 1) {
          // Single cover image
          request.files.add(await http.MultipartFile.fromPath(
            'cover_image',
            newImages.first.path,
            contentType: MediaType('image', _getFileExtension(newImages.first.path)),
          ));
        }

        // Additional images
        for (int i = 0; i < newImages.length; i++) {
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            newImages[i].path,
            contentType: MediaType('image', _getFileExtension(newImages[i].path)),
          ));
        }
      }

      // Add new video
      if (newVideo != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'video',
          newVideo.path,
          contentType: MediaType('video', _getFileExtension(newVideo.path)),
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(responseBody);
        throw Exception(error['message'] ?? 'Failed to update product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete product
  Future<bool> deleteProduct(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Archive product
  Future<SellerProduct> archiveProduct(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id/archive'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to archive product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Unarchive product
  Future<SellerProduct> unarchiveProduct(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id/unarchive'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to unarchive product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update product stock
  Future<SellerProduct> updateStock(int id, int stock) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id/stock'),
        headers: headers,
        body: json.encode({'stock': stock}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update stock');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update product status
  Future<SellerProduct> updateStatus(int id, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/$id/status'),
        headers: headers,
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SellerProduct.fromJson(data['product']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get categories for product creation/editing
  Future<List<ProductCategory>> getCategories() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/categories'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['categories'] as List)
            .map((c) => ProductCategory.fromJson(c))
            .toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get product status counts for tabs
  Future<Map<String, int>> getProductCounts() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/seller/products/counts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, int>.from(data['counts']);
      } else {
        return {
          'active': 0,
          'draft': 0,
          'low_stock': 0,
          'out_of_stock': 0,
          'archived': 0,
        };
      }
    } catch (e) {
      return {
        'active': 0,
        'draft': 0,
        'low_stock': 0,
        'out_of_stock': 0,
        'archived': 0,
      };
    }
  }

  // Helper method to get file extension
  String _getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }
}