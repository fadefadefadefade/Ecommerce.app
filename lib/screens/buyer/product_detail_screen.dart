import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? product;
  List<dynamic> relatedProducts = [];
  bool isLoading = true;
  int quantity = 1;
  String? selectedVariation;
  int selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final result = await ApiService.get('/products/${widget.productId}');
      setState(() {
        product = result['product'];
        relatedProducts = result['related'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product: $e')),
        );
      }
    }
  }

  Future<void> _addToCart({bool buyNow = false}) async {
    if (product == null) return;

    // Check variations
    if ((product!['variations'] as List?)?.isNotEmpty == true &&
        selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a variation')),
      );
      return;
    }

    try {
      await ApiService.post('/cart', body: {
        'product_id': widget.productId,
        'quantity': quantity,
      });

      if (mounted) {
        if (buyNow) {
          // Navigate to checkout
          Navigator.pushNamed(context, '/checkout');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to cart successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFfa4e1c)),
        ),
      );
    }

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product Not Found')),
        body: const Center(child: Text('Product not found')),
      );
    }

    final images = product!['images'] as List? ?? [];
    final allImages = [
      if (product!['image_url'] != null) product!['image_url'],
      ...images.map((img) => img['url']),
    ];

    final stock = product!['stock'] ?? 0;
    final inStock = stock > 0;
    final hasDiscount = product!['discount_percent'] != null &&
        product!['discount_percent'] > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF002b4d),
            elevation: 0,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Implement share
                },
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {
                  // TODO: Implement wishlist
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Gallery
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: PageView.builder(
                        itemCount: allImages.length,
                        onPageChanged: (index) {
                          setState(() => selectedImageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return Container(
                            color: const Color(0xFFF3EDE4),
                            child: Image.network(
                              allImages[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 60, color: Color(0xFFCCCCCC)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        left: 0,
                        top: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFF002b4d),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            '-${product!['discount_percent']}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Page indicator
                    if (allImages.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            allImages.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selectedImageIndex == index
                                    ? const Color(0xFFfa4e1c)
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Product Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category & Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (product!['category'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFfa4e1c).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product!['category']['name'].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFfa4e1c),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3EDE4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product!['format'] ?? 'Paperback',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1a4d6e),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        product!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002b4d),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Author/Brand
                      if (product!['author'] != null)
                        Text(
                          product!['author'],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1a4d6e),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Price
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              '₱',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFfa4e1c),
                              ),
                            ),
                            Text(
                              (product!['effective_price'] ?? product!['price'] ?? 0)
                                  .toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFfa4e1c),
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 12),
                              Text(
                                '₱${(product!['price'] ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                  color: Color(0xFF6b90aa),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFfa4e1c),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${product!['discount_percent']}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stock Status
                      Row(
                        children: [
                          Icon(
                            inStock ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: inStock
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            inStock ? 'In Stock — $stock available' : 'Out of Stock',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: inStock
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      if (product!['description'] != null) ...[
                        Text(
                          product!['description'],
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1a4d6e),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Variations
                      if ((product!['variations'] as List?)?.isNotEmpty == true) ...[
                        const Text(
                          'Variation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF002b4d),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (product!['variations'] as List).map((variation) {
                            final isSelected =
                                selectedVariation == variation['name'];
                            final varStock = variation['stock'] ?? 0;
                            final available = varStock > 0;

                            return InkWell(
                              onTap: available
                                  ? () {
                                      setState(() {
                                        selectedVariation = variation['name'];
                                      });
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFfa4e1c).withOpacity(0.1)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFfa4e1c)
                                        : const Color(0xFFcfdce8),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${variation['name']}${!available ? ' (out)' : ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: available
                                        ? (isSelected
                                            ? const Color(0xFFfa4e1c)
                                            : const Color(0xFF1a4d6e))
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quantity & Add to Cart
                      Row(
                        children: [
                          // Quantity selector
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF7F2),
                              border: Border.all(color: const Color(0xFFcfdce8)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 20),
                                  onPressed: quantity > 1
                                      ? () => setState(() => quantity--)
                                      : null,
                                  color: const Color(0xFF1a4d6e),
                                ),
                                Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  child: Text(
                                    quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF002b4d),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 20),
                                  onPressed: quantity < stock
                                      ? () => setState(() => quantity++)
                                      : null,
                                  color: const Color(0xFF1a4d6e),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Add to Cart button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: inStock ? () => _addToCart() : null,
                              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                              label: Text(inStock ? 'Add to Cart' : 'Out of Stock'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFfa4e1c),
                                side: const BorderSide(
                                  color: Color(0xFFfa4e1c),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Buy Now button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: inStock ? () => _addToCart(buyNow: true) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFfa4e1c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Buy Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Trust Badges
                      Row(
                        children: [
                          _buildTrustBadge('🚚', 'Free shipping', 'orders over \$50'),
                          const SizedBox(width: 12),
                          _buildTrustBadge('↩️', 'Easy returns', '30-day policy'),
                          const SizedBox(width: 12),
                          _buildTrustBadge('🔒', 'Secure', 'checkout'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Product Details
                      _buildDetailsSection(),
                      const SizedBox(height: 16),

                      // Seller Info
                      if (product!['seller'] != null) _buildSellerInfo(),
                    ],
                  ),
                ),

                // Related Products
                if (relatedProducts.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'You May Also Like',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002b4d),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: relatedProducts.length,
                      itemBuilder: (context, index) {
                        final related = relatedProducts[index];
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    productId: related['id'],
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: related['image_url'] != null
                                        ? Image.network(
                                            related['image_url'],
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.image),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  related['title'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₱${(related['price'] ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFfa4e1c),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(String icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFcfdce8)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a4d6e),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6b90aa),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final details = <String, dynamic>{
      if (product!['product_code'] != null)
        'Product ID': product!['product_code'],
      if (product!['category'] != null)
        'Category': product!['category']['name'],
      if (product!['author'] != null) 'Author': product!['author'],
      if (product!['isbn'] != null) 'ISBN': product!['isbn'],
      if (product!['publisher'] != null) 'Publisher': product!['publisher'],
    };

    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF7),
        border: Border.all(color: const Color(0xFFcfdce8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCT DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF002b4d),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...details.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6b90aa),
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF002b4d),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFcfdce8)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFfa4e1c),
            child: Text(
              product!['seller']['name'][0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sold by',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6b90aa),
                  ),
                ),
                Text(
                  product!['seller']['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF002b4d),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              // TODO: Visit store
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFfa4e1c),
              side: const BorderSide(color: Color(0xFFfa4e1c)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text(
              'Visit Store',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}


