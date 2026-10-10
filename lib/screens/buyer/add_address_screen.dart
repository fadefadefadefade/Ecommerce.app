import 'package:flutter/material.dart';
import '../../theme/buyer_colors.dart';
import '../../services/api_service.dart';
import '../../services/psgc_service.dart';

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? address;
  const AddAddressScreen({super.key, this.address});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();

  static const _labels = ['Home', 'Work', 'Other'];

  String _selectedLabel = 'Home';
  bool _isDefault = false;
  bool _isSaving = false;

  bool get _isEdit => widget.address != null;

  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _municipalities = [];
  List<Map<String, dynamic>> _barangays = [];

  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  String? _selectedRegionName;
  String? _selectedProvinceName;
  String? _selectedMunicipalityName;
  String? _selectedBarangayName;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    if (a != null) {
      _fullNameController.text = a['full_name'] ?? '';
      _phoneController.text = a['phone'] ?? '';
      _zipController.text = a['zip'] ?? '';
      _selectedLabel = a['label'] ?? 'Home';
      _isDefault = a['is_default'] == true || a['is_default'] == 1;
      // address_line is saved as "house, street"
      final line = (a['address_line'] ?? '') as String;
      final comma = line.indexOf(', ');
      if (comma > 0) {
        _houseNumberController.text = line.substring(0, comma);
        _streetController.text = line.substring(comma + 2);
      } else {
        _streetController.text = line;
      }
    }
    _loadRegions();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final a = widget.address;
    // When editing without re-picking the location, keep the saved one.
    final city = _selectedMunicipalityName ?? a?['city'];
    if (city == null || (city as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your region, province, city and barangay')),
      );
      return;
    }
    final relocated = _selectedMunicipalityName != null;
    final house = _houseNumberController.text.trim();
    final street = _streetController.text.trim();
    final body = {
      'label': _selectedLabel,
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address_line': [house, street].where((s) => s.isNotEmpty).join(', '),
      'barangay': relocated ? _selectedBarangayName : a?['barangay'],
      'city': city,
      'province': relocated ? (_selectedProvinceName ?? _selectedRegionName) : a?['province'],
      'zip': _zipController.text.trim(),
      'is_default': _isDefault,
    };

    setState(() => _isSaving = true);
    try {
      final result = _isEdit
          ? await ApiService.put('/addresses/${a!['id']}', body)
          : await ApiService.post('/addresses', body: body);
      final data = ApiService.unwrap(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['message'] ?? 'Address saved'),
        backgroundColor: const Color(0xFF059669),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await PsgcService.getRegions();
      if (!mounted) return;
      setState(() => _regions = regions);
    } catch (e) {
      print('Error loading regions: $e');
    }
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      final provinces = await PsgcService.getProvinces(regionCode);
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _municipalities = [];
        _barangays = [];
        _selectedProvince = null;
        _selectedMunicipality = null;
        _selectedBarangay = null;
      });
    } catch (e) {
      print('Error loading provinces: $e');
    }
  }
  Future<void> _loadMunicipalities(String provinceCode) async {
    try {
      final municipalities = await PsgcService.getMunicipalities(provinceCode);
      if (!mounted) return;
      setState(() {
        _municipalities = municipalities;
        _barangays = [];
        _selectedMunicipality = null;
        _selectedBarangay = null;
      });
    } catch (e) {
      print('Error loading municipalities: $e');
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    try {
      final barangays = await PsgcService.getBarangays(cityCode);
      if (!mounted) return;
      setState(() {
        _barangays = barangays;
        _selectedBarangay = null;
      });
    } catch (e) {
      print('Error loading barangays: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit Address' : 'Add Address'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              const Text('Full Name *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  hintText: 'Enter full name',
                  filled: true,
                  fillColor: context.bc.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'Please enter your full name' : null,
              ),
              const SizedBox(height: 20),

              // Phone
              const Text('Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 30,
                decoration: InputDecoration(
                  hintText: '09XX XXX XXXX',
                  counterText: '',
                  filled: true,
                  fillColor: context.bc.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Label
              const Text('Label', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final label in _labels)
                    ChoiceChip(
                      label: Text(label),
                      selected: _selectedLabel == label,
                      selectedColor: const Color(0xFFfa4e1c).withValues(alpha: 0.15),
                      onSelected: (_) => setState(() => _selectedLabel = label),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Address Section
              const Text('Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('Select your region, province, city/municipality, then barangay',
                style: TextStyle(fontSize: 12, color: context.bc.muted)),
              if (_isEdit && _selectedMunicipalityName == null) ...[
                const SizedBox(height: 6),
                Text(
                  'Current: ${[widget.address!['barangay'], widget.address!['city'], widget.address!['province']].where((s) => s != null && '$s'.isNotEmpty).join(', ')}'
                  ' — leave blank to keep it',
                  style: TextStyle(fontSize: 12, color: context.bc.textSecondary),
                ),
              ],
              const SizedBox(height: 16),

              // Region Dropdown
              const Text('Region *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.bc.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.bc.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRegion,
                    hint: const Text('— Select Region —', style: TextStyle(fontSize: 12)),
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() {
                        _selectedRegion = value;
                        _selectedRegionName = _regions.firstWhere((r) => r['code'] == value)['name'];
                      });
                      if (value != null) _loadProvinces(value);
                    },
                    items: _regions.map<DropdownMenuItem<String>>((region) {
                      return DropdownMenuItem<String>(
                        value: region['code'],
                        child: Text(
                          region['name'],
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Province and Municipality Row
              Row(
                children: [
                  // Province
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Province *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: context.bc.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.bc.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedProvince,
                              hint: Text(
                                _selectedRegion == null ? 'Select region' : '— Province —',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isExpanded: true,
                              onChanged: _selectedRegion == null ? null : (value) {
                                setState(() {
                                  _selectedProvince = value;
                                  _selectedProvinceName = _provinces.firstWhere((p) => p['code'] == value)['name'];
                                });
                                if (value != null) _loadMunicipalities(value);
                              },
                              items: _provinces.map<DropdownMenuItem<String>>((province) {
                                return DropdownMenuItem<String>(
                                  value: province['code'],
                                  child: Text(
                                    province['name'],
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Municipality
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('City/Municipality *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: context.bc.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.bc.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMunicipality,
                              hint: Text(
                                _selectedProvince == null ? 'Select province' : '— City —',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isExpanded: true,
                              onChanged: _selectedProvince == null ? null : (value) {
                                setState(() {
                                  _selectedMunicipality = value;
                                  _selectedMunicipalityName = _municipalities.firstWhere((m) => m['code'] == value)['name'];
                                });
                                if (value != null) _loadBarangays(value);
                              },
                              items: _municipalities.map<DropdownMenuItem<String>>((municipality) {
                                return DropdownMenuItem<String>(
                                  value: municipality['code'],
                                  child: Text(
                                    municipality['name'],
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barangay and ZIP Row
              Row(
                children: [
                  // Barangay
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Barangay *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: context.bc.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.bc.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBarangay,
                              hint: Text(
                                _selectedMunicipality == null ? 'Select city first' : '— Barangay —',
                                style: const TextStyle(fontSize: 11),
                              ),
                              isExpanded: true,
                              onChanged: _selectedMunicipality == null ? null : (value) {
                                setState(() {
                                  _selectedBarangay = value;
                                  _selectedBarangayName = _barangays.firstWhere((b) => b['code'] == value)['name'];
                                });
                              },
                              items: _barangays.map<DropdownMenuItem<String>>((barangay) {
                                return DropdownMenuItem<String>(
                                  value: barangay['code'],
                                  child: Text(
                                    barangay['name'],
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ZIP Code
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ZIP Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _zipController,
                          decoration: InputDecoration(
                            hintText: 'ZIP',
                            hintStyle: const TextStyle(fontSize: 11),
                            filled: true,
                            fillColor: context.bc.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // House Number
              const Text('House / Unit Number *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _houseNumberController,
                decoration: InputDecoration(
                  hintText: 'Enter house/unit number',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: context.bc.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Please enter house/unit number' : null,
              ),
              const SizedBox(height: 20),

              // Street
              const Text('Street / Subdivision *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(
                  hintText: 'Enter street name or subdivision',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: context.bc.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'Please enter street name' : null,
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default address', style: TextStyle(fontSize: 14)),
                value: _isDefault,
                activeThumbColor: const Color(0xFFfa4e1c),
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFfa4e1c),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Save Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}