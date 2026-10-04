class SellerProduct {
  final int? id;
  final int? categoryId;
  final String? subcategory;
  final int sellerId;
  final String? productCode;
  final String? brand;
  final String title;
  final String? author;
  final String? isbn;
  final String? publisher;
  final int? publicationYear;
  final String? edition;
  final String? language;
  final int? pages;
  final String? format;
  final double price;
  final double? salePrice;
  final double discountPercent;
  final String? voucherCode;
  final int stock;
  final String? sku;
  final String availability;
  final String status;
  final String? description;
  final Map<String, dynamic>? specs;
  final String? image;
  final String? videoPath;
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final int? addressId;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Relationships
  final ProductCategory? category;
  final List<ProductImage>? images;
  final List<ProductVariation>? variations;

  SellerProduct({
    this.id,
    this.categoryId,
    this.subcategory,
    required this.sellerId,
    this.productCode,
    this.brand,
    required this.title,
    this.author,
    this.isbn,
    this.publisher,
    this.publicationYear,
    this.edition,
    this.language,
    this.pages,
    this.format,
    required this.price,
    this.salePrice,
    this.discountPercent = 0,
    this.voucherCode,
    required this.stock,
    this.sku,
    this.availability = 'in_stock',
    this.status = 'active',
    this.description,
    this.specs,
    this.image,
    this.videoPath,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.addressId,
    this.isArchived = false,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.images,
    this.variations,
  });

  factory SellerProduct.fromJson(Map<String, dynamic> json) {
    return SellerProduct(
      id: json['id'],
      categoryId: json['category_id'],
      subcategory: json['subcategory'],
      sellerId: json['seller_id'] ?? 0,
      productCode: json['product_code'],
      brand: json['brand'],
      title: json['title'] ?? '',
      author: json['author'],
      isbn: json['isbn'],
      publisher: json['publisher'],
      publicationYear: json['publication_year'],
      edition: json['edition'],
      language: json['language'],
      pages: json['pages'],
      format: json['format'],
      price: (json['price'] ?? 0).toDouble(),
      salePrice: json['sale_price']?.toDouble(),
      discountPercent: (json['discount_percent'] ?? 0).toDouble(),
      voucherCode: json['voucher_code'],
      stock: json['stock'] ?? 0,
      sku: json['sku'],
      availability: json['availability'] ?? 'in_stock',
      status: json['status'] ?? 'active',
      description: json['description'],
      specs: json['specs'],
      image: json['image'],
      videoPath: json['video_path'],
      weightKg: json['weight_kg']?.toDouble(),
      lengthCm: json['length_cm']?.toDouble(),
      widthCm: json['width_cm']?.toDouble(),
      heightCm: json['height_cm']?.toDouble(),
      addressId: json['address_id'],
      isArchived: json['is_archived'] ?? false,
      archivedAt: json['archived_at'] != null 
          ? DateTime.parse(json['archived_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      category: json['category'] != null 
          ? ProductCategory.fromJson(json['category']) 
          : null,
      images: json['images'] != null
          ? (json['images'] as List).map((i) => ProductImage.fromJson(i)).toList()
          : null,
      variations: json['variations'] != null
          ? (json['variations'] as List).map((v) => ProductVariation.fromJson(v)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'subcategory': subcategory,
      'seller_id': sellerId,
      'product_code': productCode,
      'brand': brand,
      'title': title,
      'author': author,
      'isbn': isbn,
      'publisher': publisher,
      'publication_year': publicationYear,
      'edition': edition,
      'language': language,
      'pages': pages,
      'format': format,
      'price': price,
      'sale_price': salePrice,
      'discount_percent': discountPercent,
      'voucher_code': voucherCode,
      'stock': stock,
      'sku': sku,
      'availability': availability,
      'status': status,
      'description': description,
      'specs': specs,
      'image': image,
      'video_path': videoPath,
      'weight_kg': weightKg,
      'length_cm': lengthCm,
      'width_cm': widthCm,
      'height_cm': heightCm,
      'address_id': addressId,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper methods matching Laravel model
  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    if (discountPercent > 0) {
      return price * (1 - discountPercent / 100);
    }
    return price;
  }

  bool get hasDiscount {
    return (salePrice != null && salePrice! > 0 && salePrice! < price) ||
           discountPercent > 0;
  }

  bool get inStock {
    return totalStock > 0 && 
           availability != 'out_of_stock' && 
           status != 'out_of_stock';
  }

  int get totalStock {
    if (variations != null && variations!.isNotEmpty) {
      return variations!.fold(0, (sum, v) => sum + v.stock);
    }
    return stock;
  }

  bool isLowStock([int threshold = 5]) {
    return stock > 0 && stock <= threshold;
  }

  bool get isDraft {
    return status == 'draft';
  }

  String? get primaryImageUrl {
    if (images != null && images!.isNotEmpty) {
      return images!.first.url;
    }
    if (image != null) {
      return image!.startsWith('http') 
          ? image 
          : 'http://127.0.0.1:8001/storage/$image';
    }
    return null;
  }

  String get displayImage {
    return primaryImageUrl ?? 'https://placehold.co/200x200/fa4e1c/fff?text=P';
  }

  // Status-based styling
  Map<String, String> get statusStyle {
    switch (status) {
      case 'active':
        return {'label': 'Active', 'color': '#059669', 'bg': '#ECFDF5'};
      case 'draft':
        return {'label': 'Draft', 'color': '#6B7280', 'bg': '#F3F4F6'};
      case 'inactive':
        return {'label': 'Inactive', 'color': '#6B7280', 'bg': '#F3F4F6'};
      case 'out_of_stock':
        return {'label': 'Out of Stock', 'color': '#DC2626', 'bg': '#FEF2F2'};
      default:
        return {'label': 'Active', 'color': '#059669', 'bg': '#ECFDF5'};
    }
  }

  SellerProduct copyWith({
    int? id,
    int? categoryId,
    String? subcategory,
    int? sellerId,
    String? productCode,
    String? brand,
    String? title,
    String? author,
    String? isbn,
    String? publisher,
    int? publicationYear,
    String? edition,
    String? language,
    int? pages,
    String? format,
    double? price,
    double? salePrice,
    double? discountPercent,
    String? voucherCode,
    int? stock,
    String? sku,
    String? availability,
    String? status,
    String? description,
    Map<String, dynamic>? specs,
    String? image,
    String? videoPath,
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    int? addressId,
    bool? isArchived,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProductCategory? category,
    List<ProductImage>? images,
    List<ProductVariation>? variations,
  }) {
    return SellerProduct(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      subcategory: subcategory ?? this.subcategory,
      sellerId: sellerId ?? this.sellerId,
      productCode: productCode ?? this.productCode,
      brand: brand ?? this.brand,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      edition: edition ?? this.edition,
      language: language ?? this.language,
      pages: pages ?? this.pages,
      format: format ?? this.format,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      discountPercent: discountPercent ?? this.discountPercent,
      voucherCode: voucherCode ?? this.voucherCode,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      availability: availability ?? this.availability,
      status: status ?? this.status,
      description: description ?? this.description,
      specs: specs ?? this.specs,
      image: image ?? this.image,
      videoPath: videoPath ?? this.videoPath,
      weightKg: weightKg ?? this.weightKg,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      addressId: addressId ?? this.addressId,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      images: images ?? this.images,
      variations: variations ?? this.variations,
    );
  }
}

class ProductImage {
  final int id;
  final int productId;
  final String path;
  final String? label;
  final int sortOrder;

  ProductImage({
    required this.id,
    required this.productId,
    required this.path,
    this.label,
    required this.sortOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'],
      productId: json['product_id'] ?? json['book_id'],
      path: json['path'],
      label: json['label'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  String get url {
    return path.startsWith('http') 
        ? path 
        : 'http://127.0.0.1:8001/storage/$path';
  }
}

class ProductVariation {
  final int? id;
  final int? productId;
  final String name;
  final double? price;
  final int stock;
  final String? sku;
  final int sortOrder;

  ProductVariation({
    this.id,
    this.productId,
    required this.name,
    this.price,
    required this.stock,
    this.sku,
    required this.sortOrder,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id'],
      productId: json['product_id'] ?? json['book_id'],
      name: json['name'],
      price: json['price']?.toDouble(),
      stock: json['stock'] ?? 0,
      sku: json['sku'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'price': price,
      'stock': stock,
      'sku': sku,
      'sort_order': sortOrder,
    };
  }
}

class ProductCategory {
  final int id;
  final String name;
  final String? description;

  ProductCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }
}