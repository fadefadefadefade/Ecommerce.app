import 'package:flutter/material.dart';
import '../../utils/num_utils.dart';
import '../../widgets/net_image.dart';
import '../../theme/buyer_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/live_refresh.dart';
import 'buyer_main_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  /// "Browse Items" action; defaults to popping back when the cart was pushed.
  final VoidCallback? onBrowse;

  /// Called after the cart contents load or change (used for the nav badge).
  final VoidCallback? onChanged;

  const CartScreen({super.key, this.onBrowse, this.onChanged});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with LiveRefresh {
  List<dynamic> _cartItems = [];
  double _subtotal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  int? get liveTab => BuyerMainScreenState.tabCart;

  @override
  Future<void> onLiveRefresh() => _loadCart(silent: true);

  int _stockOf(dynamic item) => ((item['product']?['stock']) as num?)?.toInt() ?? 0;

  /// Items whose quantity is more than what's left (or that sold out).
  List<dynamic> get _stockProblems =>
      _cartItems.where((i) => (i['quantity'] as num).toInt() > _stockOf(i)).toList();

  Future<void> _loadCart({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final response = ApiService.unwrap(await ApiService.get('/cart'));
      if (!mounted) return;
      setState(() {
        _cartItems = response['items'] ?? [];
        _subtotal = asDouble(response['subtotal']);
        _isLoading = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cart: $e')),
        );
      }
    }
  }

  Future<void> _updateQuantity(int cartItemId, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      ApiService.unwrap(await ApiService.patch('/cart/$cartItemId', {
        'quantity': newQuantity,
      }));
      _loadCart(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        _loadCart(silent: true);
      }
    }
  }

  Future<void> _removeItem(int cartItemId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "$title" from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ApiService.unwrap(await ApiService.delete('/cart/$cartItemId'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item removed from cart')),
          );
        }
        _loadCart();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing item: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: const Color(0xFFFA4E1C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    // Progress steps
                    _buildProgressSteps(),
                    // Cart items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) {
                          final item = _cartItems[index];
                          return _buildCartItem(item);
                        },
                      ),
                    ),
                    // Bottom checkout section
                    _buildCheckoutSection(),
                  ],
                ),
    );
  }

  Widget _buildProgressSteps() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: context.bc.surface,
      child: Row(
        children: [
          _buildStep(1, 'Cart', true),
          _buildStepLine(false),
          _buildStep(2, 'Checkout', false),
          _buildStepLine(false),
          _buildStep(3, 'Confirm', false),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFA4E1C) : context.bc.subtle,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? Colors.white : context.bc.muted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFFA4E1C) : context.bc.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 1,
        color: context.bc.subtle,
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.bc.subtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 40,
                color: Color(0xFFFA4E1C),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.bc.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Looks like you haven\'t added anything yet.',
              style: TextStyle(
                fontSize: 14,
                color: context.bc.muted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onBrowse ?? () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA4E1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Browse Items'),
            ),
          ],
        ),
      ),
    );
  }

  /// Live stock line under the price: sold out / not enough / few left / in stock.
  Widget _buildStockNote(int quantity, int stock) {
    const red = Color(0xFFC62828);
    const orange = Color(0xFFEF6C00);
    final (String text, Color color, bool bold) = stock <= 0
        ? ('Out of stock — please remove', red, true)
        : quantity > stock
            ? ('Only $stock left — lower the quantity', red, true)
            : stock <= 5
                ? ('Only $stock left in stock', orange, true)
                : ('$stock in stock', context.bc.muted, false);
    return Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final product = item['product'];
    final quantity = item['quantity'] as int;
    final subtotal = asDouble(item['subtotal']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.bc.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: NetImage(
                product['image_url'] ?? 'https://placehold.co/80x100/FF6300/FFFFFF?text=Product',
                width: 80,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 100,
                    color: context.bc.subtle,
                    child: const Icon(Icons.shopping_bag, color: Color(0xFFFA4E1C)),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['title'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.bc.text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by ${product['author'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.bc.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₱${asDouble(product['effective_price']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFA4E1C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildStockNote(quantity, _stockOf(item)),
                          ],
                        ),
                      ),
                      // Remove button
                      IconButton(
                        onPressed: () => _removeItem(item['id'], product['title']),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quantity controls and subtotal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity stepper
                      Container(
                        decoration: BoxDecoration(
                          color: context.bc.subtle,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFDCC2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: quantity > 1
                                  ? () => _updateQuantity(item['id'], quantity - 1)
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                              style: IconButton.styleFrom(
                                foregroundColor: const Color(0xFFFA4E1C),
                                disabledForegroundColor: context.bc.muted,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$quantity',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: context.bc.text,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: quantity < 99 && quantity < _stockOf(item)
                                  ? () => _updateQuantity(item['id'], quantity + 1)
                                  : null,
                              icon: const Icon(Icons.add, size: 16),
                              style: IconButton.styleFrom(
                                foregroundColor: const Color(0xFFFA4E1C),
                                disabledForegroundColor: context.bc.muted,
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Line total
                      Text(
                        '₱${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.bc.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.bc.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal:',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.bc.muted,
                  ),
                ),
                Text(
                  '₱${_subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.bc.text,
                  ),
                ),
              ],
            ),
            if (_stockProblems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFC62828), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Some items no longer have enough stock. Lower the quantity or remove them to continue.',
                        style: TextStyle(fontSize: 12, color: context.bc.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cartItems.isEmpty || _stockProblems.isNotEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CheckoutScreen(),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA4E1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


