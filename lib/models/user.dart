class User {
  final int id;
  final String name;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? phone;
  final String role;
  final String? approvalStatus;

  /// Which part of the app this account opens (from the web API):
  /// buyer, seller, seller_status, rider, courier, courier_status, logistics or admin.
  final String home;
  final String? photoUrl;
  final int? riderId;
  /// A rider of a logistics company (Hub Jobs) / an approved direct courier — an account can be both, like on the website.
  final bool hasRider;
  final bool hasCourier;
  final DateTime? previousLoginAt;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    this.firstName,
    this.lastName,
    required this.email,
    this.phone,
    required this.role,
    this.approvalStatus,
    required this.home,
    this.photoUrl,
    this.riderId,
    this.hasRider = false,
    this.hasCourier = false,
    this.previousLoginAt,
    this.createdAt,
  });

  // Role checking methods
  bool get isSeller => role == 'seller';
  bool get isBuyer => home == 'buyer';
  bool get isCustomer => isBuyer;
  bool get isCourier => role == 'courier';
  bool get isRider => home == 'rider';
  bool get isAdmin => role == 'admin';
  bool get isLogistics => home == 'logistics';

  // Seller status checking
  bool get isApprovedSeller => isSeller && approvalStatus == 'approved';
  bool get isPendingSeller => isSeller && approvalStatus == 'pending';
  bool get isRejectedSeller => isSeller && approvalStatus == 'rejected';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'buyer',
      approvalStatus: json['approval_status'],
      home: json['home'] ?? 'buyer',
      photoUrl: json['photo_url'],
      riderId: json['rider_id'],
      hasRider: json['has_rider'] == true,
      hasCourier: json['has_courier'] == true,
      previousLoginAt: json['previous_login_at'] != null ? DateTime.tryParse(json['previous_login_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'role': role,
      'approval_status': approvalStatus,
      'home': home,
      'photo_url': photoUrl,
      'rider_id': riderId,
      'has_rider': hasRider,
      'has_courier': hasCourier,
      'previous_login_at': previousLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
