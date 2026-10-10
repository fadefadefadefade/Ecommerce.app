import '../models/seller_product.dart';
import 'api_service.dart';

class ReportService {
  // Get seller sales report with date range
  static Future<Map<String, dynamic>> getSalesReport({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = to ?? DateTime.now();
      
      final queryParams = {
        'from': fromDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
        'to': toDate.toIso8601String().split('T')[0],
      };
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final result = await ApiService.get('/seller/reports?$queryString');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          // API wraps the figures: {success: true, report: {...}}
          'report': SalesReport.fromJson(Map<String, dynamic>.from(data['report'] ?? data)),
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to load sales report',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get dashboard summary metrics
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final result = await ApiService.get('/seller/dashboard/summary');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'summary': DashboardSummary.fromJson(data),
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Failed to load dashboard summary',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get product performance analytics
  static Future<Map<String, dynamic>> getProductPerformance({
    DateTime? from,
    DateTime? to,
    int limit = 10,
  }) async {
    try {
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = to ?? DateTime.now();
      
      final queryParams = {
        'from': fromDate.toIso8601String().split('T')[0],
        'to': toDate.toIso8601String().split('T')[0],
        'limit': limit.toString(),
      };
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final result = await ApiService.get('/seller/reports/product-performance?$queryString');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'products': (data['products'] as List? ?? [])
              .map((p) => ProductPerformance.fromJson(Map<String, dynamic>.from(p)))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'products': <ProductPerformance>[],
          'message': result['message'] ?? 'Failed to load product performance',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'products': <ProductPerformance>[],
        'message': 'Network error: $e',
      };
    }
  }

  // Get sales trend data for charts
  static Future<Map<String, dynamic>> getSalesTrend({
    DateTime? from,
    DateTime? to,
    String period = 'daily', // daily, weekly, monthly
  }) async {
    try {
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = to ?? DateTime.now();
      
      final queryParams = {
        'from': fromDate.toIso8601String().split('T')[0],
        'to': toDate.toIso8601String().split('T')[0],
        'period': period,
      };
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final result = await ApiService.get('/seller/reports/trends?$queryString');
      
      if (result['success']) {
        final data = result['data'];
        return {
          'success': true,
          'trends': (data['trends'] as List)
              .map((t) => SalesTrend.fromJson(t))
              .toList(),
        };
      } else {
        return {
          'success': false,
          'trends': <SalesTrend>[],
          'message': result['message'] ?? 'Failed to load sales trends',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'trends': <SalesTrend>[],
        'message': 'Network error: $e',
      };
    }
  }

  // Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  // Calculate percentage change
  static double calculatePercentageChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  // Format percentage
  static String formatPercentage(double percentage) {
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${percentage.toStringAsFixed(1)}%';
  }

  // Get date range presets
  static List<DateRangePreset> getDateRangePresets() {
    final now = DateTime.now();
    return [
      DateRangePreset(
        label: 'Today',
        from: DateTime(now.year, now.month, now.day),
        to: now,
      ),
      DateRangePreset(
        label: 'Yesterday',
        from: DateTime(now.year, now.month, now.day - 1),
        to: DateTime(now.year, now.month, now.day - 1, 23, 59, 59),
      ),
      DateRangePreset(
        label: 'This Week',
        from: now.subtract(Duration(days: now.weekday - 1)),
        to: now,
      ),
      DateRangePreset(
        label: 'Last Week',
        from: now.subtract(Duration(days: now.weekday + 6)),
        to: now.subtract(Duration(days: now.weekday)),
      ),
      DateRangePreset(
        label: 'This Month',
        from: DateTime(now.year, now.month, 1),
        to: now,
      ),
      DateRangePreset(
        label: 'Last Month',
        from: DateTime(now.year, now.month - 1, 1),
        to: DateTime(now.year, now.month, 0, 23, 59, 59),
      ),
      DateRangePreset(
        label: 'Last 30 Days',
        from: now.subtract(const Duration(days: 30)),
        to: now,
      ),
      DateRangePreset(
        label: 'Last 90 Days',
        from: now.subtract(const Duration(days: 90)),
        to: now,
      ),
    ];
  }
}

// Sales Report Model
class SalesReport {
  final DateTime fromDate;
  final DateTime toDate;
  final double totalRevenue;
  final double totalCommission;
  final double totalEarnings;
  final int totalOrders;
  final double commissionRate;
  final List<ProductPerformance> productPerformance;
  final List<SalesTrend> salesTrend;

  const SalesReport({
    required this.fromDate,
    required this.toDate,
    required this.totalRevenue,
    required this.totalCommission,
    required this.totalEarnings,
    required this.totalOrders,
    required this.commissionRate,
    required this.productPerformance,
    required this.salesTrend,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    // Current API keys first (from_date, product_performance, sales_trend), older ones as fallback.
    final products = json['product_performance'] ?? json['by_product'];
    final trend = json['sales_trend'] ?? json['by_date'];
    return SalesReport(
      fromDate: DateTime.tryParse('${json['from_date'] ?? json['from'] ?? ''}') ?? DateTime.now(),
      toDate: DateTime.tryParse('${json['to_date'] ?? json['to'] ?? ''}') ?? DateTime.now(),
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
      totalCommission: double.tryParse(json['total_commission']?.toString() ?? '0') ?? 0.0,
      totalEarnings: double.tryParse(json['total_earnings']?.toString() ?? '0') ?? 0.0,
      totalOrders: int.tryParse('${json['total_orders'] ?? 0}') ?? 0,
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '10') ?? 10.0,
      productPerformance: products is List
          ? products.map((p) => ProductPerformance.fromJson(Map<String, dynamic>.from(p))).toList()
          : [],
      salesTrend: trend is List
          ? trend.map((t) => SalesTrend.fromJson(Map<String, dynamic>.from(t))).toList()
          : trend is Map
              ? trend.entries
                  .map((e) => SalesTrend(date: '${e.key}', earnings: double.tryParse(e.value.toString()) ?? 0.0))
                  .toList()
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': fromDate.toIso8601String(),
      'to': toDate.toIso8601String(),
      'total_revenue': totalRevenue,
      'total_commission': totalCommission,
      'total_earnings': totalEarnings,
      'total_orders': totalOrders,
      'commission_rate': commissionRate,
      'by_product': productPerformance.map((p) => p.toJson()).toList(),
      'by_date': Map.fromEntries(salesTrend.map((t) => MapEntry(t.date, t.earnings))),
    };
  }

  // Calculated properties
  double get averageOrderValue {
    return totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
  }

  double get profitMargin {
    return totalRevenue > 0 ? (totalEarnings / totalRevenue) * 100 : 0.0;
  }

  String get formattedTotalRevenue => ReportService.formatCurrency(totalRevenue);
  String get formattedTotalCommission => ReportService.formatCurrency(totalCommission);
  String get formattedTotalEarnings => ReportService.formatCurrency(totalEarnings);
  String get formattedAverageOrderValue => ReportService.formatCurrency(averageOrderValue);
}

// Product Performance Model
class ProductPerformance {
  final int? bookId;
  final String title;
  final int quantity;
  final double revenue;
  final double earnings;
  final double commission;
  final SellerProduct? product;

  const ProductPerformance({
    this.bookId,
    required this.title,
    required this.quantity,
    required this.revenue,
    required this.earnings,
    required this.commission,
    this.product,
  });

  factory ProductPerformance.fromJson(Map<String, dynamic> json) {
    return ProductPerformance(
      bookId: json['book_id'],
      title: json['title'] ?? 'Unknown Product',
      quantity: json['qty'] ?? json['quantity'] ?? 0,
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0.0,
      earnings: double.tryParse(json['earnings']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0.0,
      product: json['product'] != null ? SellerProduct.fromJson(json['product']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'title': title,
      'quantity': quantity,
      'revenue': revenue,
      'earnings': earnings,
      'commission': commission,
      'product': product?.toJson(),
    };
  }

  // Calculated properties
  double get averagePrice {
    return quantity > 0 ? revenue / quantity : 0.0;
  }

  double get profitMargin {
    return revenue > 0 ? (earnings / revenue) * 100 : 0.0;
  }

  String get formattedRevenue => ReportService.formatCurrency(revenue);
  String get formattedEarnings => ReportService.formatCurrency(earnings);
  String get formattedCommission => ReportService.formatCurrency(commission);
  String get formattedAveragePrice => ReportService.formatCurrency(averagePrice);
}

// Sales Trend Model
class SalesTrend {
  final String date;
  final double earnings;
  final double? revenue;
  final int? orders;

  const SalesTrend({
    required this.date,
    required this.earnings,
    this.revenue,
    this.orders,
  });

  factory SalesTrend.fromJson(Map<String, dynamic> json) {
    return SalesTrend(
      date: json['date'] ?? json['label'] ?? '',
      earnings: double.tryParse(json['earnings']?.toString() ?? '0') ?? 0.0,
      revenue: json['revenue'] != null ? double.tryParse(json['revenue'].toString()) : null,
      orders: json['orders'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'earnings': earnings,
      if (revenue != null) 'revenue': revenue,
      if (orders != null) 'orders': orders,
    };
  }
}

// Dashboard Summary Model
class DashboardSummary {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final int totalOrders;
  final int pendingOrders;
  final int activeProducts;
  final int totalProducts;
  final double totalRevenue;

  const DashboardSummary({
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.totalOrders,
    required this.pendingOrders,
    required this.activeProducts,
    required this.totalProducts,
    required this.totalRevenue,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      todayEarnings: double.tryParse(json['today_earnings']?.toString() ?? '0') ?? 0.0,
      weekEarnings: double.tryParse(json['week_earnings']?.toString() ?? '0') ?? 0.0,
      monthEarnings: double.tryParse(json['month_earnings']?.toString() ?? '0') ?? 0.0,
      totalOrders: json['total_orders'] ?? 0,
      pendingOrders: json['pending_orders'] ?? 0,
      activeProducts: json['active_products'] ?? 0,
      totalProducts: json['total_products'] ?? 0,
      totalRevenue: double.tryParse(json['total_revenue']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'today_earnings': todayEarnings,
      'week_earnings': weekEarnings,
      'month_earnings': monthEarnings,
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'active_products': activeProducts,
      'total_products': totalProducts,
      'total_revenue': totalRevenue,
    };
  }
}

// Date Range Preset Model
class DateRangePreset {
  final String label;
  final DateTime from;
  final DateTime to;

  const DateRangePreset({
    required this.label,
    required this.from,
    required this.to,
  });

  @override
  String toString() => label;
}