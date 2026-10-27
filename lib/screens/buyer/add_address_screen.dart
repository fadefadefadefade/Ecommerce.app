import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config/api_config.dart';
import '../../theme/buyer_colors.dart';
import '../../services/buyer_api.dart';
import '../../services/location.dart';
import '../../services/psgc_service.dart';
import '../../widgets/buyer_kit.dart';

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

  // The map pin (the website's "Pin location"): optional, saved with the address.
  double? _lat;
  double? _lng;
  String? _pinned;
  bool _locating = false;
  // The website's "Pin your location": an OpenStreetMap map, a place search, tap to pin.
  static const _phCenter = LatLng(12.8797, 121.7740);
  final _map = MapController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _places = [];
  String? _searchNote;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    if (a != null) {
      _fullNameController.text = a['full_name'] ?? '';
      _phoneController.text = localPhone(a['phone']);
      _zipController.text = a['zip'] ?? '';
      _selectedLabel = a['label'] ?? 'Home';
      _isDefault = a['is_default'] == true || a['is_default'] == 1;
      // address_line is saved as "house, street"
      _lat = a['latitude'] == null ? null : (a['latitude'] as num).toDouble();
      _lng = a['longitude'] == null ? null : (a['longitude'] as num).toDouble();
      if (_lat != null) _pinned = 'Pinned on the map';
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
    _search.dispose();
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
      'region': relocated ? _selectedRegionName : a?['region'],
      'label': _selectedLabel,
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address_line': [house, street].where((s) => s.isNotEmpty).join(', '),
      'barangay': relocated ? _selectedBarangayName : a?['barangay'],
      'city': city,
      'province': relocated ? (_selectedProvinceName ?? _selectedRegionName) : a?['province'],
      'province_code': relocated ? _selectedProvince : a?['province_code'],
      'municipality_code': relocated ? _selectedMunicipality : a?['municipality_code'],
      'barangay_code': relocated ? _selectedBarangay : a?['barangay_code'],
      'zip': _zipController.text.trim(),
      'is_default': _isDefault,
      if (_lat != null && _lng != null) 'latitude': _lat,
      if (_lat != null && _lng != null) 'longitude': _lng,
    };

    setState(() => _isSaving = true);
    // The website's address rules and messages (AddressController).
    final r = _isEdit ? await BuyerApi.updateAddress(a!['id'], body) : await BuyerApi.addAddress(body);
    if (!mounted) return;
    setState(() => _isSaving = false);
    showResult(context, r);
    if (r.ok) Navigator.pop(context, true);
  }

  /// The phone's location as the map pin; the website's /api/geo/reverse fills the region, province, city,
  /// barangay, street and ZIP it can find there (the buyer checks them before saving).
  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final loc = await PhoneLocation.current();
    if (!mounted) return;
    if (!loc.ok) {
      setState(() => _locating = false);
      return showError(context, loc.problem ?? 'Could not get your location.');
    }
    await _pinAt(loc.lat!, loc.lng!);
  }

  /// Places matching a typed search (the website's /api/geo/search).
  Future<void> _findPlace() async {
    final q = _search.text.trim();
    if (q.length < 3 || _searching) return;
    setState(() {
      _searching = true;
      _searchNote = 'Searching…';
      _places = [];
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.webUrl}/api/geo/search?q=${Uri.encodeQueryComponent(q)}'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      final list = res.statusCode == 200 ? (jsonDecode(res.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : null;
      if (!mounted) return;
      setState(() {
        _places = list ?? [];
        _searchNote = list == null ? 'Search is unavailable right now.' : (list.isEmpty ? 'No places found. Try another name, or tap the map.' : null);
      });
    } catch (_) {
      if (mounted) setState(() => _searchNote = 'Search is unavailable right now.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Pin a spot: the map moves there and the website's /api/geo/reverse fills the region, province, city,
  /// barangay, street and ZIP it can find (the buyer checks them before saving).
  Future<void> _pinAt(double lat, double lng) async {
    setState(() {
      _locating = true;
      _lat = lat;
      _lng = lng;
      _places = [];
      _searchNote = null;
    });
    try {
      _map.move(LatLng(lat, lng), _map.camera.zoom < 16 ? 17 : _map.camera.zoom);
    } catch (_) {}
    final loc = (lat: lat, lng: lng);
    Map<String, dynamic> geo = {};
    try {
      final res = await http.get(Uri.parse('${ApiConfig.webUrl}/api/geo/reverse?lat=${loc.lat}&lon=${loc.lng}'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      geo = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() => _locating = false);
        return showError(context, '${geo['message'] ?? 'We couldn\'t find an address there.'}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _locating = false);
      return showError(context, 'Could not look up the address. Fill it in below.');
    }
    if (!mounted) return;
    setState(() {
      _lat = loc.lat;
      _lng = loc.lng;
      _pinned = '${geo['display'] ?? 'Pinned at your location'}';
      if (_streetController.text.trim().isEmpty && geo['street'] != null) _streetController.text = '${geo['street']}';
      if (geo['zip'] != null) _zipController.text = '${geo['zip']}';
    });

    String? code(dynamic item) => item is Map ? '${item['code'] ?? ''}' : null;
    bool has(List<Map<String, dynamic>> list, String? c) => c != null && c.isNotEmpty && list.any((x) => '${x['code']}' == c);

    final region = code(geo['region']);
    if (has(_regions, region)) {
      setState(() {
        _selectedRegion = region;
        _selectedRegionName = _regions.firstWhere((r) => '${r['code']}' == region)['name'];
      });
      await _loadProvinces(region!);
      final province = code(geo['province']);
      if (has(_provinces, province)) {
        setState(() {
          _selectedProvince = province;
          _selectedProvinceName = _provinces.firstWhere((p) => '${p['code']}' == province)['name'];
        });
        await _loadMunicipalities(province!);
      }
      final city = code(geo['city']);
      if (has(_municipalities, city)) {
        setState(() {
          _selectedMunicipality = city;
          _selectedMunicipalityName = _municipalities.firstWhere((m) => '${m['code']}' == city)['name'];
        });
        await _loadBarangays(city!);
        final brgy = code(geo['barangay']);
        if (has(_barangays, brgy)) {
          setState(() {
            _selectedBarangay = brgy;
            _selectedBarangayName = _barangays.firstWhere((b) => '${b['code']}' == brgy)['name'];
          });
        }
      }
    }
    if (mounted) setState(() => _locating = false);
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
      if (provinces.isEmpty) {
        // NCR: no province level — its cities sit directly under the region.
        setState(() {
          _provinces = [];
          _selectedProvince = null;
          _selectedProvinceName = null;
        });
        await _loadMunicipalities(regionCode);
        return;
      }
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
                inputFormatters: phoneFormatters,
                decoration: InputDecoration(
                  hintText: '09XXXXXXXXX',
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

              // Pin your location (optional): search a place, tap the map, or use the phone's location.
              Row(children: [
                const Text('Pin your location ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('(optional)', style: TextStyle(fontSize: 12, color: context.bc.muted)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _findPlace(),
                    decoration: InputDecoration(
                      hintText: 'Search a place, e.g. SM Calamba',
                      isDense: true,
                      filled: true,
                      fillColor: context.bc.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _searching ? null : _findPlace, child: const Text('Search')),
              ]),
              if (_searchNote != null)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(_searchNote!, style: TextStyle(fontSize: 12, color: context.bc.muted))),
              for (final pl in _places)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined, color: Color(0xFFfa4e1c)),
                  title: Text('${pl['label']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  onTap: () => _pinAt((pl['lat'] as num).toDouble(), (pl['lon'] as num).toDouble()),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : _phCenter,
                      initialZoom: _lat != null ? 17 : 5,
                      onTap: (_, point) => _locating ? null : _pinAt(point.latitude, point.longitude),
                    ),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.alvy_app'),
                      if (_lat != null && _lng != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: LatLng(_lat!, _lng!),
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            // Drag the pin to the house; letting go looks up the address there.
                            child: GestureDetector(
                              onPanUpdate: _locating
                                  ? null
                                  : (d) {
                                      final cam = _map.camera;
                                      final to = cam.screenOffsetToLatLng(cam.latLngToScreenOffset(LatLng(_lat!, _lng!)) + d.delta);
                                      setState(() {
                                        _lat = to.latitude;
                                        _lng = to.longitude;
                                      });
                                    },
                              onPanEnd: _locating ? null : (_) => _pinAt(_lat!, _lng!),
                              child: const Icon(Icons.location_pin, size: 40, color: Color(0xFFfa4e1c)),
                            ),
                          ),
                        ]),
                      const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text("Tap the map or drag the pin to your house. We'll fill in the address below for you.", style: TextStyle(fontSize: 12, color: context.bc.muted)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, color: Color(0xFFfa4e1c)),
                label: Text(_lat == null ? 'Use my current location' : 'Update the pin to my location'),
              ),
              if (_pinned != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('📍 $_pinned', style: TextStyle(fontSize: 12, color: context.bc.muted)),
                ),
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
                        const Text('ZIP Code *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _zipController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'ZIP code is required';
                          if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Enter a 4-digit ZIP code';
                          return null;
                        },
                          decoration: InputDecoration(
                            counterText: '',
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