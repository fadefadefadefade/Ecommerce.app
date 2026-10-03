import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/psgc_service.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipCodeController = TextEditingController();

  // PSGC State
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _municipalities = [];
  List<Map<String, dynamic>> _barangays = [];

  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;

  String? _selectedRegionName;
  String? _selectedProvinceName;
  String? _selectedCityName;
  String? _selectedBarangayName;

  // Data
  List<dynamic> _items = [];
  double _subtotal = 0;
  double _shipping = 0;
  double _total = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
    _loadRegions();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckoutData() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/checkout');
      setState(() {
        _items = response['items'] ?? [];
        _subtotal = (response['subtotal'] ?? 0).toDouble();
        _shipping = (response['shipping'] ?? 0).toDouble();
        _total = (response['total'] ?? 0).toDouble();
        
        // Pre-fill user data
        final user = response['user'];
        if (user != null) {
          _fullNameController.text = user['name'] ?? '';
          _emailController.text = user['email'] ?? '';
          _phoneController.text = user['phone'] ?? '';
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await PsgcService.getRegions();
      setState(() => _regions = regions);
    } catch (e) {
      debugPrint('Error loading regions: $e');
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      final provinces = await PsgcService.getProvinces(regionCode);
      setState(() {
        _provinces = provinces;
        _municipalities = [];
        _barangays = [];
        _selectedProvince = null;
        _selectedCity = null;
        _selectedBarangay = null;
      });
    } catch (e) {
      debugPrint('Error loading provinces: $e');
    }
  }

  Future<void> _loadMunicipalities(String provinceCode) async {
    try {
      final municipalities = await PsgcService.getMunicipalities(provinceCode);
      setState(() {
        _municipalities = municipalities;
        _barangays = [];
        _selectedCity = null;
        _selectedBarangay = null;
      });
    } catch (e) {
      debugPrint('Error loading municipalities: $e');
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    try {
      final barangays = await PsgcService.getBarangays(cityCode);
      setState(() {
        _barangays = barangays;
        _selectedBarangay = null;
      });
    } catch (e) {
      debugPrint('Error loading barangays: $e');
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.post('/checkout', body: {
        'full_name': _fullNameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'region': _selectedRegionName ?? _selectedRegion,
        'province': _selectedProvinceName ?? _selectedProvince,
        'city': _selectedCityName ?? _selectedCity,
        'barangay': _selectedBarangayName ?? _selectedBarangay,
        'house_number': _houseNumberController.text,
        'street': _streetController.text,
        'zip_code': _zipCodeController.text,
        'payment_method': 'cod',
      });

      if (mounted) {
        // Navigate to confirmation screen with order ID
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              orderId: response['order_id'],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFFFA4E1C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Progress steps
                _buildProgressSteps(),
                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact Information
                          _buildSectionCard(
                            'Contact Information',
                            Column(
                              children: [
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number *',
                                    border: OutlineInputBorder(),
                                    hintText: '+63 912 345 6789',
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Delivery Address
                          _buildSectionCard(
                            'Delivery Address',
                            Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedRegion,
                                  decoration: const InputDecoration(
                                    labelText: 'Region *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _regions.map((region) {
                                    return DropdownMenuItem<String>(
                                      value: region['code'],
                                      child: Text(region['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      final region = _regions.firstWhere((r) => r['code'] == value);
                                      setState(() {
                                        _selectedRegion = value;
                                        _selectedRegionName = region['name'];
                                      });
                                      _loadProvinces(value);
                                    }
                                  },
                                  validator: (v) => v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedProvince,
                                  decoration: const InputDecoration(
                                    labelText: 'Province *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _provinces.map((province) {
                                    return DropdownMenuItem<String>(
                                      value: province['code'],
                                      child: Text(province['name']),
                                    );
                                  }).toList(),
                                  onChanged: _selectedRegion == null
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            final province = _provinces.firstWhere((p) => p['code'] == value);
                                            setState(() {
                                              _selectedProvince = value;
                                              _selectedProvinceName = province['name'];
                                            });
                                            _loadMunicipalities(value);
                                          }
                                        },
                                  validator: (v) => v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedCity,
                                  decoration: const InputDecoration(
                                    labelText: 'City / Municipality *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _municipalities.map((city) {
                                    return DropdownMenuItem<String>(
                                      value: city['code'],
                                      child: Text(city['name']),
                                    );
                                  }).toList(),
                                  onChanged: _selectedProvince == null
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            final city = _municipalities.firstWhere((c) => c['code'] == value);
                                            setState(() {
                                              _selectedCity = value;
                                              _selectedCityName = city['name'];
                                            });
                                            _loadBarangays(value);
                                          }
                                        },
                                  validator: (v) => v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _selectedBarangay,
                                  decoration: const InputDecoration(
                                    labelText: 'Barangay *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _barangays.map((barangay) {
                                    return DropdownMenuItem<String>(
                                      value: barangay['code'],
                                      child: Text(barangay['name']),
                                    );
                                  }).toList(),
                                  onChanged: _selectedCity == null
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            final barangay = _barangays.firstWhere((b) => b['code'] == value);
                                            setState(() {
                                              _selectedBarangay = value;
                                              _selectedBarangayName = barangay['name'];
                                            });
                                          }
                                        },
                                  validator: (v) => v == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _houseNumberController,
                                        decoration: const InputDecoration(
                                          labelText: 'House / Unit No.',
                                          border: OutlineInputBorder(),
                                          hintText: 'e.g. 123',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _zipCodeController,
                                        decoration: const InputDecoration(
                                          labelText: 'ZIP Code *',
                                          border: OutlineInputBorder(),
                                          hintText: 'e.g. 1000',
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _streetController,
                                  decoration: const InputDecoration(
                                    labelText: 'Street / Subdivision',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g. Rizal Street',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment Method
                          _buildSectionCard(
                            'Payment Method',
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8F4),
                                    border: Border.all(
                                      color: const Color(0xFFFA4E1C),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFA4E1C),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '💵',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cash on Delivery (COD)',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF222222),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Pay in cash when your order arrives',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF757575),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFA4E1C),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Selected',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1EE),
                                    border: Border.all(color: const Color(0xFFFDB49E)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('💡', style: TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF555555),
                                            ),
                                            children: [
                                              const TextSpan(text: 'Please prepare '),
                                              TextSpan(
                                                text: '₱${_total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFFA4E1C),
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' upon delivery. No advance payment needed.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Order Summary
                          _buildSectionCard(
                            'Order Summary',
                            Column(
                              children: [
                                ..._items.map((item) {
                                  final product = item['product'];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            product['image_url'] ?? '',
                                            width: 50,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 50,
                                              height: 60,
                                              color: const Color(0xFFE8F0F6),
                                              child: const Icon(Icons.shopping_bag, size: 24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['title'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Qty: ${item['quantity']}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B90AA),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₱${(item['subtotal'] ?? 0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFA4E1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const Divider(height: 24),
                                _buildSummaryRow('Subtotal', _subtotal),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Shipping Fee', _shipping),
                                const Divider(height: 24),
                                _buildSummaryRow('Total', _total, isBold: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA4E1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildProgressSteps() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStep(1, 'Cart', false),
          _buildStepLine(true),
          _buildStep(2, 'Checkout', true),
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
            color: active ? const Color(0xFFFA4E1C) : const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF6B90AA),
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
            color: active ? const Color(0xFFFA4E1C) : const Color(0xFF6B90AA),
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
        color: const Color(0xFFDCE8F0),
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF222222) : const Color(0xFF6B90AA),
          ),
        ),
        Text(
          '₱${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF222222),
          ),
        ),
      ],
    );
  }
}



