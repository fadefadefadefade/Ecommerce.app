// Models for the logistics (admin) panel. Mirrors the web app's
// Parcel, Rider, ParcelDelivery, DeliveryArea and Message models.

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

int? _int(dynamic v) => v == null ? null : int.tryParse(v.toString());

String _humanize(String value) {
  if (value.isEmpty) return value;
  final s = value.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

class PagedResult<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  PagedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  /// Parses a Laravel paginator payload.
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PagedResult(
      items: (json['data'] as List? ?? [])
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: _int(json['current_page']) ?? 1,
      lastPage: _int(json['last_page']) ?? 1,
      total: _int(json['total']) ?? 0,
    );
  }
}

class DeliveryArea {
  final int id;
  final String name;

  DeliveryArea({required this.id, required this.name});

  factory DeliveryArea.fromJson(Map<String, dynamic> json) =>
      DeliveryArea(id: json['id'], name: json['name'] ?? '');
}

class ParcelDelivery {
  static const statuses = [
    'assigned',
    'out_for_delivery',
    'delivered',
    'failed',
    'returned',
  ];

  final int id;
  final int? parcelId;
  final String? trackingNumber;
  final String? receiverName;
  final int? riderId;
  final String? riderName;
  final String? areaName;
  final String status;
  final String? remarks;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ParcelDelivery({
    required this.id,
    this.parcelId,
    this.trackingNumber,
    this.receiverName,
    this.riderId,
    this.riderName,
    this.areaName,
    required this.status,
    this.remarks,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
  });

  String get statusLabel => _humanize(status);

  factory ParcelDelivery.fromJson(Map<String, dynamic> json) {
    final parcel = json['parcel'] as Map<String, dynamic>?;
    final rider = json['rider'] as Map<String, dynamic>?;
    final area = json['area'] as Map<String, dynamic>?;
    return ParcelDelivery(
      id: json['id'],
      parcelId: _int(json['parcel_id']),
      trackingNumber: parcel?['tracking_number'],
      receiverName: parcel?['receiver_name'],
      riderId: _int(json['rider_id']),
      riderName: rider?['full_name'],
      areaName: area?['name'],
      status: json['status'] ?? '',
      remarks: json['remarks'],
      deliveredAt: _date(json['delivered_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class Parcel {
  final int id;
  final String trackingNumber;
  final String? sellerName;
  final String? receiverName;
  final String? receiverPhone;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? weightKg;
  final String? size;
  final String? notes;
  final int? areaId;
  final String? areaName;
  final String status;
  final String statusLabel;
  final DateTime? createdAt;
  final ParcelDelivery? delivery;

  Parcel({
    required this.id,
    required this.trackingNumber,
    this.sellerName,
    this.receiverName,
    this.receiverPhone,
    this.pickupAddress,
    this.dropoffAddress,
    this.weightKg,
    this.size,
    this.notes,
    this.areaId,
    this.areaName,
    required this.status,
    required this.statusLabel,
    this.createdAt,
    this.delivery,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    final area = json['area'] as Map<String, dynamic>?;
    final delivery = json['parcel_delivery'] as Map<String, dynamic>?;
    final status = json['status'] ?? '';
    return Parcel(
      id: json['id'],
      trackingNumber: json['tracking_number'] ?? '—',
      sellerName: seller?['name'],
      receiverName: json['receiver_name'],
      receiverPhone: json['receiver_phone'],
      pickupAddress: json['pickup_address'],
      dropoffAddress: json['dropoff_address'],
      weightKg: json['weight_kg']?.toString(),
      size: json['size'],
      notes: json['notes'],
      areaId: _int(json['area_id']),
      areaName: area?['name'],
      status: status,
      statusLabel: json['status_label'] ?? _humanize(status),
      createdAt: _date(json['created_at']),
      delivery: delivery != null ? ParcelDelivery.fromJson(delivery) : null,
    );
  }
}

class Rider {
  final int id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? vehicleType;
  final String? licenseNumber;
  final int? areaId;
  final String? areaName;
  final String applicationStatus;
  final String? rejectionReason;
  final bool isActive;
  final String? idDocumentUrl;
  final DateTime? createdAt;
  final List<ParcelDelivery> deliveries;

  Rider({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.vehicleType,
    this.licenseNumber,
    this.areaId,
    this.areaName,
    required this.applicationStatus,
    this.rejectionReason,
    required this.isActive,
    this.idDocumentUrl,
    this.createdAt,
    this.deliveries = const [],
  });

  bool get isPending => applicationStatus == 'pending';
  bool get isApproved => applicationStatus == 'approved';

  factory Rider.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final area = json['area'] as Map<String, dynamic>?;
    return Rider(
      id: json['id'],
      fullName: json['full_name'] ?? '—',
      phone: json['phone'],
      email: user?['email'],
      vehicleType: json['vehicle_type'],
      licenseNumber: json['license_number'],
      areaId: _int(json['area_id']),
      areaName: area?['name'],
      applicationStatus: json['application_status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      idDocumentUrl: json['id_document_url'],
      createdAt: _date(json['created_at']),
      deliveries: (json['parcel_deliveries'] as List? ?? [])
          .map((e) => ParcelDelivery.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ChatContact {
  final int id;
  final String name;
  final String? role;
  final int unread;

  ChatContact({
    required this.id,
    required this.name,
    this.role,
    this.unread = 0,
  });

  String get roleLabel => _humanize(role ?? 'user');

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
        id: json['id'],
        name: json['name'] ?? '',
        role: json['role'],
        unread: _int(json['unread']) ?? 0,
      );
}

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String body;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        senderId: _int(json['sender_id']) ?? 0,
        receiverId: _int(json['receiver_id']) ?? 0,
        body: json['body'] ?? '',
        createdAt: _date(json['created_at']),
      );
}
