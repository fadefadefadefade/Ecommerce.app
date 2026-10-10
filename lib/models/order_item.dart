import 'seller_product.dart';

class OrderItem {
  final int id;
  final int orderId;
  final int productId;
  final int quantity;
  final double price;
  final double commissionRate;
  final double commissionAmount;
  final double sellerEarning;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Relationships
  final SellerProduct? product;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.commissionRate,
    required this.commissionAmount,
    required this.sellerEarning,
    required this.createdAt,
    required this.updatedAt,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      // API sends product/product_id (book/book_id kept for old payloads)
      productId: json['product_id'] ?? json['book_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '0') ?? 0.0,
      commissionAmount: double.tryParse(json['commission_amount']?.toString() ?? '0') ?? 0.0,
      sellerEarning: double.tryParse(json['seller_earning']?.toString() ?? '0') ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      product: (json['product'] ?? json['book']) != null
          ? SellerProduct.fromJson(Map<String, dynamic>.from(json['product'] ?? json['book']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'seller_earning': sellerEarning,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'product': product?.toJson(),
    };
  }

  // Business logic methods
  double get lineTotal {
    return double.parse((quantity * price).toStringAsFixed(2));
  }

  String get formattedPrice {
    return '₱${price.toStringAsFixed(2)}';
  }

  String get formattedLineTotal {
    return '₱${lineTotal.toStringAsFixed(2)}';
  }

  String get formattedCommission {
    return '₱${commissionAmount.toStringAsFixed(2)}';
  }

  String get formattedSellerEarning {
    return '₱${sellerEarning.toStringAsFixed(2)}';
  }

  double get commissionPercentage {
    return commissionRate;
  }
}