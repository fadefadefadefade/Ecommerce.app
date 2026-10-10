import 'package:flutter/material.dart';
import '../../../widgets/product_thumb.dart';
import '../../../widgets/stock_stepper.dart';
import 'package:flutter/services.dart';
import '../../../models/seller_product.dart';
import '../../../services/seller_api_service.dart';
import 'add_edit_product_screen.dart';

class ProductActionsScreen extends StatefulWidget {
  final SellerProduct product;
  final VoidCallback? onProductUpdated;

  const ProductActionsScreen({
    super.key,
    required this.product,
    this.onProductUpdated,
  });

  @override
  State<ProductActionsScreen> createState() => _ProductActionsScreenState();
}

class _ProductActionsScreenState extends State<ProductActionsScreen> {
  final _apiService = SellerApiService();
  final _stockController = TextEditingController();
  
  late SellerProduct _product;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _stockController.text = _product.stock.toString();
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _updateStock() async {
    final newStock = int.tryParse(_stockController.text);
    if (newStock == null || newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid stock number')),
      );
      return;
    }

    if (newStock == _product.stock) return;

    setState(() => _isLoading = true);

    try {
      final updatedProduct = await _apiService.updateStock(_product.id!, newStock);
      setState(() {
        _product = updatedProduct;
      });
      widget.onProductUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock updated to $newStock')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating stock: $e')),
      );
      _stockController.text = _product.stock.toString(); // Reset to original
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      final updatedProduct = await _apiService.updateStatus(_product.id!, newStatus);
      setState(() {
        _product = updatedProduct;
      });
      widget.onProductUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _archiveProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${_product.title}"? It will be hidden from customers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final updatedProduct = await _apiService.archiveProduct(_product.id!);
      setState(() {
        _product = updatedProduct;
      });
      widget.onProductUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_product.title} archived')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error archiving product: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unarchiveProduct() async {
    setState(() => _isLoading = true);

    try {
      final updatedProduct = await _apiService.unarchiveProduct(_product.id!);
      setState(() {
        _product = updatedProduct;
      });
      widget.onProductUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_product.title} restored')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring product: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to permanently delete "${_product.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.deleteProduct(_product.id!);
      widget.onProductUpdated?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted permanently')),
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _product.statusStyle;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: const Text('Product Actions'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product overview card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ProductThumb(url: _product.primaryImageUrl, size: 88),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_product.author != null || _product.brand != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _product.author ?? _product.brand!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6b90aa),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '₱${_product.effectivePrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFfa4e1c),
                                ),
                              ),
                              if (_product.hasDiscount) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '₱${_product.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6b90aa),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(int.parse(statusStyle['bg']!.substring(1), radix: 16) + 0xFF000000),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusStyle['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(int.parse(statusStyle['color']!.substring(1), radix: 16) + 0xFF000000),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick stock update
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002b4d),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StockStepper(
                            controller: _stockController,
                            labelText: 'Current Stock',
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateStock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFfa4e1c),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading 
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Update'),
                        ),
                      ],
                    ),
                    if (_product.stock == 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Color(0xFFDC2626), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Product is out of stock',
                              style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_product.isLowStock()) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_outlined, color: Color(0xFFD97706), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Low stock warning',
                              style: TextStyle(color: Color(0xFFD97706), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status management
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002b4d),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (!_product.isArchived) ...[
                      _buildStatusButton(
                        'active',
                        'Publish',
                        'Make product visible to customers',
                        Icons.visibility,
                        const Color(0xFF059669),
                        _product.status != 'active',
                      ),
                      const SizedBox(height: 8),
                      _buildStatusButton(
                        'draft',
                        'Save as Draft',
                        'Hide from customers but keep editable',
                        Icons.drafts,
                        const Color(0xFF6B7280),
                        _product.status != 'draft',
                      ),
                      const SizedBox(height: 8),
                      _buildStatusButton(
                        'inactive',
                        'Mark Inactive',
                        'Temporarily hide from customers',
                        Icons.visibility_off,
                        const Color(0xFF6B7280),
                        _product.status != 'inactive',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Product actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002b4d),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildActionButton(
                      'Edit Product',
                      'Modify product details, images, and pricing',
                      Icons.edit,
                      const Color(0xFFfa4e1c),
                      () async {
                        final result = await Navigator.push<SellerProduct>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditProductScreen(product: _product),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _product = result;
                          });
                          widget.onProductUpdated?.call();
                        }
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    if (!_product.isArchived)
                      _buildActionButton(
                        'Archive Product',
                        'Move to archived products (can be restored)',
                        Icons.archive,
                        const Color(0xFFD97706),
                        _archiveProduct,
                      )
                    else
                      _buildActionButton(
                        'Restore Product',
                        'Move back to active products',
                        Icons.unarchive,
                        const Color(0xFF059669),
                        _unarchiveProduct,
                      ),
                    
                    const SizedBox(height: 8),
                    
                    _buildActionButton(
                      'Delete Permanently',
                      'Remove product completely (cannot be undone)',
                      Icons.delete_forever,
                      Colors.red,
                      _deleteProduct,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String status,
    String title,
    String description,
    IconData icon,
    Color color,
    bool enabled,
  ) {
    return InkWell(
      onTap: enabled && !_isLoading ? () => _updateStatus(status) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? color.withOpacity(0.05) : Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled ? color : Colors.grey,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey.shade700 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled)
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6b90aa),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}