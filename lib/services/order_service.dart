import '../models/order.dart';
import '../models/order_item.dart';
import 'api_service.dart';

class OrderService {
  // Get seller orders (orders containing seller's products)
  static Future<Map<String, dynamic>> getSellerOrders({
    int page = 1,
    String? status,
    String? search,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final endpoint = '/seller/orders${queryString.isNotEmpty ? '?$queryString' : ''}';
      final result = await ApiService.get(endpoint);
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'orders': (data['orders'] as List)
              .map((orderJson) => Order.fromJson(orderJson))
              .toList(),
          'pagination': data['pagination'] ?? {},
          'statusCounts': data['status_counts'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to load orders',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get single order details for seller
  static Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    try {
      final result = await ApiService.get('/seller/orders/$orderId');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'order': Order.fromJson(data['order']),
          'parcel': data['parcel'], // Parcel/delivery tracking info
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to load order details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Update order status (seller can update orders containing their products)
  /// Seller moves an order: 'Processing', 'Shipped' (to warehouse) or 'Cancelled' (needs [reason]).
  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status, {
    String? reason,
  }) async {
    try {
      final result = await ApiService.patch('/seller/orders/$orderId', {
        'status': status,
        if (reason != null) 'cancellation_reason': reason,
      });

      if (result['success']) {
        return {
          'success': true,
          'message': result['data']['message'] ?? 'Order status updated to $status',
          'order': Order.fromJson(result['data']['order']),
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to update order status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Schedule courier pickup for order
  static Future<Map<String, dynamic>> schedulePickup(
    int orderId, {
    required String courierName,
    String? trackingNumber,
    required DateTime pickupScheduledAt,
    String? notes,
  }) async {
    try {
      final result = await ApiService.post(
        '/seller/orders/$orderId/handover',
        body: {
          'courier_name': courierName,
          'tracking_number': trackingNumber,
          'pickup_scheduled_at': pickupScheduledAt.toIso8601String(),
          'notes': notes,
        },
      );
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'message': data['message'] ?? 'Pickup scheduled successfully',
          'order': Order.fromJson(data['order']),
          'delivery': data['delivery'],
          'parcel': data['parcel'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to schedule pickup',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Mark order as handed over to courier
  static Future<Map<String, dynamic>> markHandedOver(int orderId) async {
    try {
      final result = await ApiService.post(
        '/seller/orders/$orderId/handed-over',
        body: {},
      );
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'message': data['message'] ?? 'Order marked as handed over',
          'order': Order.fromJson(data['order']),
          'delivery': data['delivery'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to mark order as handed over',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get order status options available to seller
  static List<String> getOrderStatusOptions() {
    return ['Pending', 'Processing', 'Shipped', 'Delivered'];
  }

  // Get order status color scheme
  static Map<String, String> getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return {'bg': '#ECFDF5', 'text': '#059669'};
      case 'shipped':
        return {'bg': '#FFF7ED', 'text': '#C2410C'};
      case 'processing':
        return {'bg': 'rgba(200,169,138,.15)', 'text': '#6B4C3B'};
      case 'cancelled':
        return {'bg': '#FEF2F2', 'text': '#DC2626'};
      default: // Pending
        return {'bg': '#FFFBEB', 'text': '#B45309'};
    }
  }

  // Get order status badge text
  static String getStatusBadgeText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Check if status can be updated by seller
  static bool canUpdateStatus(String currentStatus, String newStatus) {
    final statusFlow = {
      'Pending': ['Processing'],
      'Processing': ['Shipped'],
      'Shipped': ['Delivered'],
      'Delivered': [], // Final status
      'Cancelled': [], // Final status
    };
    
    return statusFlow[currentStatus]?.contains(newStatus) ?? false;
  }

  // Get next possible status for an order
  static List<String> getNextPossibleStatuses(String currentStatus) {
    final statusFlow = <String, List<String>>{
      'Pending': ['Processing'],
      'Processing': ['Shipped'],
      'Shipped': ['Delivered'],
      'Delivered': <String>[],
      'Cancelled': <String>[],
    };
    
    return statusFlow[currentStatus] ?? <String>[];
  }

  // Get orders count by status for seller dashboard
  static Future<Map<String, dynamic>> getOrderCounts() async {
    try {
      final result = await ApiService.get('/seller/orders/counts');
      
      if (result['success']) {
        return {
          'success': true,
          'counts': result['data']['counts'] ?? {},
        };
      } else {
        return {
          'success': false,
          'counts': {
            'pending': 0,
            'processing': 0,
            'shipped': 0,
            'delivered': 0,
            'cancelled': 0,
            'total': 0,
          },
        };
      }
    } catch (e) {
      return {
        'success': false,
        'counts': {
          'pending': 0,
          'processing': 0,
          'shipped': 0,
          'delivered': 0,
          'cancelled': 0,
          'total': 0,
        },
      };
    }
  }

  // Get recent orders for seller dashboard
  static Future<Map<String, dynamic>> getRecentOrders({int limit = 5}) async {
    try {
      final result = await ApiService.get('/seller/orders?limit=$limit&recent=true');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'orders': (data['orders'] as List)
              .map((orderJson) => Order.fromJson(orderJson))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'orders': <Order>[],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'orders': <Order>[],
      };
    }
  }

  // Search orders by customer name, email, or order ID
  static Future<Map<String, dynamic>> searchOrders(String query) async {
    try {
      final result = await ApiService.get('/seller/orders?search=${Uri.encodeComponent(query)}');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'orders': (data['orders'] as List)
              .map((orderJson) => Order.fromJson(orderJson))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'orders': <Order>[],
          'message': result['message'] ?? 'Search failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'orders': <Order>[],
        'message': 'Network error: $e',
      };
    }
  }

  // Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  // Calculate total earnings for seller from order items
  static double calculateSellerEarnings(List<OrderItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.sellerEarning);
  }

  // Calculate total commission from order items
  static double calculateTotalCommission(List<OrderItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.commissionAmount);
  }

  // Format date for display
  static String formatOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}