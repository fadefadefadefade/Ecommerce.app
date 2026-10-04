import 'order_item.dart';
import 'user.dart';

class Order {
  final int id;
  final int userId;
  final String fullName;
  final String phone;
  final String email;
  final String addressLine;
  final String city;
  final String province;
  final String zipCode;
  final String? shippingAddress;
  final double subtotal;
  final double shippingFee;
  final double totalPrice;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Relationships
  final User? user;
  final List<OrderItem> items;
  final Delivery? delivery;

  const Order({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.addressLine,
    required this.city,
    required this.province,
    required this.zipCode,
    this.shippingAddress,
    required this.subtotal,
    required this.shippingFee,
    required this.totalPrice,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.items = const [],
    this.delivery,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      addressLine: json['address_line'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      zipCode: json['zip_code'] ?? '',
      shippingAddress: json['shipping_address'],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      shippingFee: double.tryParse(json['shipping_fee']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      status: json['status'] ?? '',
      cancellationReason: json['cancellation_reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      items: json['items'] != null 
          ? (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList()
          : [],
      delivery: json['delivery'] != null ? Delivery.fromJson(json['delivery']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'address_line': addressLine,
      'city': city,
      'province': province,
      'zip_code': zipCode,
      'shipping_address': shippingAddress,
      'subtotal': subtotal,
      'shipping_fee': shippingFee,
      'total_price': totalPrice,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'status': status,
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user': user?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'delivery': delivery?.toJson(),
    };
  }

  // Business logic methods
  bool get isCancellableByBuyer {
    return ['Pending', 'Processing'].contains(status);
  }

  String get fullAddress {
    return [addressLine, city, province, zipCode]
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  Map<String, String> get statusColor {
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

  // Helper methods for seller-specific data
  List<OrderItem> get sellerItems {
    // This will be filtered by the service layer based on seller's book IDs
    return items;
  }

  double get sellerSubtotal {
    return sellerItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get sellerCommission {
    return sellerItems.fold(0.0, (sum, item) => sum + item.commissionAmount);
  }

  double get sellerEarnings {
    return sellerItems.fold(0.0, (sum, item) => sum + item.sellerEarning);
  }
}

class Delivery {
  final int id;
  final int orderId;
  final String courierName;
  final String? trackingNumber;
  final DateTime? pickupScheduledAt;
  final DateTime? pickedUpAt;
  final DateTime? handedOverAt;
  final String status;
  final double deliveryFee;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Delivery({
    required this.id,
    required this.orderId,
    required this.courierName,
    this.trackingNumber,
    this.pickupScheduledAt,
    this.pickedUpAt,
    this.handedOverAt,
    required this.status,
    required this.deliveryFee,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      courierName: json['courier_name'] ?? '',
      trackingNumber: json['tracking_number'],
      pickupScheduledAt: json['pickup_scheduled_at'] != null 
          ? DateTime.tryParse(json['pickup_scheduled_at']) : null,
      pickedUpAt: json['picked_up_at'] != null 
          ? DateTime.tryParse(json['picked_up_at']) : null,
      handedOverAt: json['handed_over_at'] != null 
          ? DateTime.tryParse(json['handed_over_at']) : null,
      status: json['status'] ?? '',
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'courier_name': courierName,
      'tracking_number': trackingNumber,
      'pickup_scheduled_at': pickupScheduledAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'handed_over_at': handedOverAt?.toIso8601String(),
      'status': status,
      'delivery_fee': deliveryFee,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}