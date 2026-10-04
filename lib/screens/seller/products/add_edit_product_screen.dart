import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/seller_product.dart';
import '../../../services/seller_api_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final SellerProduct? product; // null for add, existing product for edit

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = SellerApiService();
  final _imagePicker = ImagePicker();
  
  // Form controllers
  final _titleController = TextEditingController();
  final _brandController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publicationYearController = TextEditingController();
  final _editionController = TextEditingController();
  final _languageController = TextEditingController();
  final _pagesController = TextEditingController();
  final _formatController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _voucherCodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  
  // Form state
  bool _isLoading = false;
  bool _isDraft = false;
  List<File> _selectedImages = [];
  List<ProductImage> _existingImages = [];
  List<int> _removedImageIds = [];
  File? _selectedVideo;
  List<ProductCategory> _categories = [];
  List<ProductVariation> _variations = [];
  int? _selectedCategoryId;
  String? _selectedSubcategory;
  String _status = 'active';

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) {
      _populateForm();
    }
  }
  @override
  void dispose() {
    _titleController.dispose();
    _brandController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _publicationYearController.dispose();
    _editionController.dispose();
    _languageController.dispose();
    _pagesController.dispose();
    _formatController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _discountController.dispose();
    _voucherCodeController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _populateForm() {
    final product = widget.product!;
    _titleController.text = product.title;
    _brandController.text = product.brand ?? '';
    _authorController.text = product.author ?? '';
    _isbnController.text = product.isbn ?? '';
    _publisherController.text = product.publisher ?? '';
    _publicationYearController.text = product.publicationYear?.toString() ?? '';
    _editionController.text = product.edition ?? '';
    _languageController.text = product.language ?? '';
    _pagesController.text = product.pages?.toString() ?? '';
    _formatController.text = product.format ?? '';
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toString();
    _salePriceController.text = product.salePrice?.toString() ?? '';
    _discountController.text = product.discountPercent.toString();
    _voucherCodeController.text = product.voucherCode ?? '';
    _stockController.text = product.stock.toString();
    _skuController.text = product.sku ?? '';
    _weightController.text = product.weightKg?.toString() ?? '';
    _lengthController.text = product.lengthCm?.toString() ?? '';
    _widthController.text = product.widthCm?.toString() ?? '';
    _heightController.text = product.heightCm?.toString() ?? '';
    
    _selectedCategoryId = product.categoryId;
    _selectedSubcategory = product.subcategory;
    _status = product.status;
    _existingImages = product.images ?? [];
    _variations = List.from(product.variations ?? []);
  }
  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
        // Limit to 9 images total
        if (_selectedImages.length > 9) {
          _selectedImages = _selectedImages.take(9).toList();
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedFile = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    final image = _existingImages[index];
    setState(() {
      _removedImageIds.add(image.id);
      _existingImages.removeAt(index);
    });
  }

  void _addVariation() {
    setState(() {
      _variations.add(ProductVariation(
        name: '',
        stock: 0,
        sortOrder: _variations.length,
      ));
    });
  }

  void _removeVariation(int index) {
    setState(() {
      _variations.removeAt(index);
      // Update sort orders
      for (int i = 0; i < _variations.length; i++) {
        _variations[i] = ProductVariation(
          id: _variations[i].id,
          productId: _variations[i].productId,
          name: _variations[i].name,
          price: _variations[i].price,
          stock: _variations[i].stock,
          sku: _variations[i].sku,
          sortOrder: i,
        );
      }
    });
  }
  Future<void> _saveProduct({bool asDraft = false}) async {
    if (!_formKey.currentState!.validate() && !asDraft) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isDraft = asDraft;
    });

    try {
      final productData = {
        'title': _titleController.text,
        'brand': _brandController.text.isNotEmpty ? _brandController.text : null,
        'author': _authorController.text.isNotEmpty ? _authorController.text : null,
        'isbn': _isbnController.text.isNotEmpty ? _isbnController.text : null,
        'publisher': _publisherController.text.isNotEmpty ? _publisherController.text : null,
        'publication_year': _publicationYearController.text.isNotEmpty 
            ? int.tryParse(_publicationYearController.text) : null,
        'edition': _editionController.text.isNotEmpty ? _editionController.text : null,
        'language': _languageController.text.isNotEmpty ? _languageController.text : null,
        'pages': _pagesController.text.isNotEmpty 
            ? int.tryParse(_pagesController.text) : null,
        'format': _formatController.text.isNotEmpty ? _formatController.text : null,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'category_id': _selectedCategoryId,
        'subcategory': _selectedSubcategory,
        'price': double.tryParse(_priceController.text) ?? 0,
        'sale_price': _salePriceController.text.isNotEmpty 
            ? double.tryParse(_salePriceController.text) : null,
        'discount_percent': double.tryParse(_discountController.text) ?? 0,
        'voucher_code': _voucherCodeController.text.isNotEmpty ? _voucherCodeController.text : null,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'sku': _skuController.text.isNotEmpty ? _skuController.text : null,
        'weight_kg': _weightController.text.isNotEmpty 
            ? double.tryParse(_weightController.text) : null,
        'length_cm': _lengthController.text.isNotEmpty 
            ? double.tryParse(_lengthController.text) : null,
        'width_cm': _widthController.text.isNotEmpty 
            ? double.tryParse(_widthController.text) : null,
        'height_cm': _heightController.text.isNotEmpty 
            ? double.tryParse(_heightController.text) : null,
        'status': asDraft ? 'draft' : _status,
        'variations': _variations.map((v) => v.toJson()).toList(),
      };

      SellerProduct result;
      if (_isEditing) {
        result = await _apiService.updateProduct(
          widget.product!.id!,
          productData,
          newImages: _selectedImages,
          newVideo: _selectedVideo,
          removedImageIds: _removedImageIds,
        );
      } else {
        result = await _apiService.createProduct(
          productData,
          images: _selectedImages,
          video: _selectedVideo,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing 
                ? 'Product updated successfully' 
                : asDraft 
                  ? 'Product saved as draft'
                  : 'Product created successfully'
            ),
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () => _saveProduct(asDraft: true),
              child: const Text(
                'DRAFT',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildImageSection(),
              const SizedBox(height: 16),
              _buildBasicInfoSection(),
              const SizedBox(height: 16),
              _buildPricingSection(),
              const SizedBox(height: 16),
              _buildVariationsSection(),
              const SizedBox(height: 16),
              _buildShippingSection(),
              const SizedBox(height: 16),
              _buildBookDetailsSection(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Photos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002b4d),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload up to 9 photos. First photo is the main image.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6b90aa),
              ),
            ),
            const SizedBox(height: 16),
            
            // Existing images (for editing)
            if (_existingImages.isNotEmpty) ...[
              const Text(
                'Current Photos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6b90aa),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  itemBuilder: (context, index) {
                    final image = _existingImages[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image.url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (index == 0)
                            Positioned(
                              bottom: 2,
                              left: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFfa4e1c),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MAIN',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Selected images
            if (_selectedImages.isNotEmpty) ...[
              const Text(
                'New Photos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6b90aa),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeSelectedImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Add photos button
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFfa4e1c),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFfff1ee),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Color(0xFFfa4e1c),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to add photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFfa4e1c),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Video section
            const Text(
              'Product Video (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6b90aa),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedVideo != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Color(0xFF6b90aa)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedVideo!.path.split('/').last,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedVideo = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Add Video'),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002b4d),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Cotton Oversized T-Shirt',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Product name is required' : null,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Category is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _selectedSubcategory,
                    decoration: const InputDecoration(
                      labelText: 'Subcategory',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _selectedSubcategory = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Brand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your product features, materials, condition...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 5000,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing & Inventory',
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
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (₱) *',
                      border: OutlineInputBorder(),
                      prefixText: '₱ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Price is required';
                      if (double.tryParse(value!) == null) return 'Invalid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _salePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price (₱)',
                      border: OutlineInputBorder(),
                      prefixText: '₱ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isNotEmpty ?? false) {
                        final salePrice = double.tryParse(value!);
                        final originalPrice = double.tryParse(_priceController.text);
                        if (salePrice != null && originalPrice != null && salePrice >= originalPrice) {
                          return 'Sale price must be less than original price';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Stock is required';
                      if (int.tryParse(value!) == null) return 'Invalid stock';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU (Optional)',
                      hintText: 'Auto-generated if empty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    decoration: const InputDecoration(
                      labelText: 'Discount %',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isNotEmpty ?? false) {
                        final discount = double.tryParse(value!);
                        if (discount != null && (discount < 0 || discount > 99)) {
                          return 'Discount must be between 0-99%';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _voucherCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Voucher Code',
                      hintText: 'e.g. SAVE20',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildVariationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Variations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002b4d),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Add options like color or size with individual stock & price',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6b90aa),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addVariation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFfa4e1c),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_variations.isNotEmpty) ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _variations.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFcfdce8)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: _variations[index].name,
                                decoration: const InputDecoration(
                                  labelText: 'Variation',
                                  hintText: 'e.g. Black / S',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  _variations[index] = ProductVariation(
                                    id: _variations[index].id,
                                    productId: _variations[index].productId,
                                    name: value,
                                    price: _variations[index].price,
                                    stock: _variations[index].stock,
                                    sku: _variations[index].sku,
                                    sortOrder: _variations[index].sortOrder,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: _variations[index].price?.toString() ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Price (₱)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _variations[index] = ProductVariation(
                                    id: _variations[index].id,
                                    productId: _variations[index].productId,
                                    name: _variations[index].name,
                                    price: double.tryParse(value),
                                    stock: _variations[index].stock,
                                    sku: _variations[index].sku,
                                    sortOrder: _variations[index].sortOrder,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: _variations[index].stock.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Stock',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  _variations[index] = ProductVariation(
                                    id: _variations[index].id,
                                    productId: _variations[index].productId,
                                    name: _variations[index].name,
                                    price: _variations[index].price,
                                    stock: int.tryParse(value) ?? 0,
                                    sku: _variations[index].sku,
                                    sortOrder: _variations[index].sortOrder,
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeVariation(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _variations[index].sku ?? '',
                          decoration: const InputDecoration(
                            labelText: 'SKU (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            _variations[index] = ProductVariation(
                              id: _variations[index].id,
                              productId: _variations[index].productId,
                              name: _variations[index].name,
                              price: _variations[index].price,
                              stock: _variations[index].stock,
                              sku: value.isNotEmpty ? value : null,
                              sortOrder: _variations[index].sortOrder,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else
              const Center(
                child: Text(
                  'No variations added yet',
                  style: TextStyle(
                    color: Color(0xFF6b90aa),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildShippingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shipping',
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
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lengthController,
                    decoration: const InputDecoration(
                      labelText: 'Length (cm)',
                      border: OutlineInputBorder(),
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    decoration: const InputDecoration(
                      labelText: 'Width (cm)',
                      border: OutlineInputBorder(),
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(),
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Details (Optional)',
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
                  child: TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author/Creator',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _isbnController,
                    decoration: const InputDecoration(
                      labelText: 'ISBN/Product Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Publisher/Manufacturer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _publicationYearController,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _editionController,
                    decoration: const InputDecoration(
                      labelText: 'Edition/Version',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _languageController,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pagesController,
                    decoration: const InputDecoration(
                      labelText: 'Pages/Count',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _formatController,
                    decoration: const InputDecoration(
                      labelText: 'Format/Type',
                      hintText: 'e.g. Hardcover, Digital',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _saveProduct(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFfa4e1c),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isEditing ? 'Update Product' : 'Create Product',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}