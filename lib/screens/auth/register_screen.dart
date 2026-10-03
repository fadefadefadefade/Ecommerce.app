import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/api_service.dart';
import '../../services/psgc_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  // Personal Information
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNoController = TextEditingController();
  DateTime? _selectedBirthday;
  String? _selectedSex;
  File? _validIdFile;
  final ImagePicker _picker = ImagePicker();

  // Address - PSGC Data
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _municipalities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  String? _selectedRegionCode;
  String? _selectedRegionName;
  String? _selectedProvinceCode;
  String? _selectedProvinceName;
  String? _selectedMunicipalityCode;
  String? _selectedMunicipalityName;
  String? _selectedBarangayName;
  
  bool _loadingProvinces = false;
  bool _loadingMunicipalities = false;
  bool _loadingBarangays = false;
  // Address
  final _zipCodeController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _streetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  void _loadRegions() async {
    final regions = await PsgcService.getRegions();
    setState(() {
      _regions = regions;
    });
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _contactNoController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFfa4e1c),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your birthday'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final age = _calculateAge(_selectedBirthday!);

      final result = await ApiService.post('/register', body: {
        'last_name': _lastNameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'middle_initial': _middleInitialController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'sex': _selectedSex!,
        'email': _emailController.text.trim(),
        'contact_no': _contactNoController.text.trim(),
        'birthday': DateFormat('yyyy-MM-dd').format(_selectedBirthday!),
        'age': age.toString(),
        'region': _selectedRegionName ?? '',
        'province': _selectedProvinceName ?? '',
        'municipality': _selectedMunicipalityName ?? '',
        'barangay': _selectedBarangayName ?? '',
        'zip_code': _zipCodeController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'street': _streetController.text.trim(),
      });

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Registration Successful'),
              content: const Text(
                'Your registration has been submitted successfully. '
                'Your account is currently pending administrator approval. '
                'Please wait for an email regarding your registration status.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registration failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbeee8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFfa4e1c),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'ALVY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Join ALVY for faster checkout and order history',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8a7a70),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Personal Information Section
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _middleInitialController,
                        label: 'Middle Initial',
                        maxLength: 5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 16),

                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  obscure: _obscureConfirmPassword,
                  onToggle: () =>
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Sex',
                        value: _selectedSex,
                        items: const ['Male', 'Female'],
                        onChanged: (value) => setState(() => _selectedSex = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _contactNoController,
                        label: 'Contact No.',
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField(
                        label: 'Birthday',
                        date: _selectedBirthday,
                        onTap: _selectBirthday,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_selectedBirthday != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE6D9CF)),
                    ),
                    child: Text(
                      'Age: ${_calculateAge(_selectedBirthday!)} years old',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF222222),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Address Section
                _buildSectionTitle('Address'),
                const SizedBox(height: 8),
                const Text(
                  'Select your region, province, city/municipality, then barangay',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8a7a70),
                  ),
                ),
                const SizedBox(height: 16),

                // Region Dropdown
                _buildPsgcDropdown(
                  label: 'Region',
                  value: _selectedRegionCode,
                  items: _regions,
                  onChanged: (value) async {
                    setState(() {
                      _selectedRegionCode = value;
                      _selectedRegionName = _regions
                          .firstWhere((r) => r['code'] == value)['name'];
                      _selectedProvinceCode = null;
                      _selectedProvinceName = null;
                      _selectedMunicipalityCode = null;
                      _selectedMunicipalityName = null;
                      _selectedBarangayName = null;
                      _provinces = [];
                      _municipalities = [];
                      _barangays = [];
                      _loadingProvinces = true;
                    });
                    
                    final provinces = await PsgcService.getProvincesByRegion(value!);
                    setState(() {
                      _provinces = provinces;
                      _loadingProvinces = false;
                    });
                  },
                  hint: '— Select Region —',
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildPsgcDropdown(
                        label: 'Province',
                        value: _selectedProvinceCode,
                        items: _provinces,
                        onChanged: _selectedRegionCode == null
                            ? null
                            : (value) async {
                                setState(() {
                                  _selectedProvinceCode = value;
                                  _selectedProvinceName = _provinces
                                      .firstWhere((p) => p['code'] == value)['name'];
                                  _selectedMunicipalityCode = null;
                                  _selectedMunicipalityName = null;
                                  _selectedBarangayName = null;
                                  _municipalities = [];
                                  _barangays = [];
                                  _loadingMunicipalities = true;
                                });
                                
                                final municipalities =
                                    await PsgcService.getMunicipalities(value!);
                                setState(() {
                                  _municipalities = municipalities;
                                  _loadingMunicipalities = false;
                                });
                              },
                        hint: _selectedRegionCode == null
                            ? '— Select Region first —'
                            : '— Select Province —',
                        isLoading: _loadingProvinces,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPsgcDropdown(
                        label: 'Municipality/City',
                        value: _selectedMunicipalityCode,
                        items: _municipalities,
                        onChanged: _selectedProvinceCode == null
                            ? null
                            : (value) async {
                                setState(() {
                                  _selectedMunicipalityCode = value;
                                  _selectedMunicipalityName = _municipalities
                                      .firstWhere((m) => m['code'] == value)['name'];
                                  _selectedBarangayName = null;
                                  _barangays = [];
                                  _loadingBarangays = true;
                                });
                                
                                final barangays =
                                    await PsgcService.getBarangays(value!);
                                setState(() {
                                  _barangays = barangays;
                                  _loadingBarangays = false;
                                });
                              },
                        hint: _selectedProvinceCode == null
                            ? '— Select Province first —'
                            : '— Select Municipality —',
                        isLoading: _loadingMunicipalities,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildPsgcDropdown(
                        label: 'Barangay',
                        value: _selectedBarangayName,
                        items: _barangays,
                        onChanged: _selectedMunicipalityCode == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedBarangayName = _barangays
                                      .firstWhere((b) => b['name'] == value)['name'];
                                });
                              },
                        hint: _selectedMunicipalityCode == null
                            ? '— Select Municipality first —'
                            : '— Select Barangay —',
                        isLoading: _loadingBarangays,
                        useNameAsValue: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _zipCodeController,
                        label: 'ZIP Code',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _houseNumberController,
                  label: 'House / Unit Number',
                  isRequired: true,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _streetController,
                  label: 'Street / Subdivision',
                  isRequired: true,
                ),
                const SizedBox(height: 24),

                // Valid ID Upload
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        text: 'Upload Valid ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6b90aa),
                        ),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final XFile? image =
                            await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            _validIdFile = File(image.path);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFDCC2)),
                        ),
                        child: _validIdFile == null
                            ? const Row(
                                children: [
                                  Icon(Icons.upload_file, color: Color(0xFF6b90aa)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Tap to select file',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF8a7a70),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF10B981)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _validIdFile!.path.split('/').last,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF222222),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _validIdFile = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'JPG, JPEG, PNG, or PDF. Max 5MB.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8a7a70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Terms and Conditions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                      activeColor: const Color(0xFFfa4e1c),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'I agree to the terms and conditions',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFfa4e1c),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8a7a70),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF222222),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6b90aa),
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: isRequired
              ? (value) => value == null || value.isEmpty ? 'Required field' : null
              : null,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            text: 'Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6b90aa),
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF6b90aa),
              ),
              onPressed: onToggle,
            ),
          ),
          validator: validator ??
              (value) {
                if (value == null || value.isEmpty) return 'Required field';
                if (value.length < 8) return 'Minimum 8 characters';
                return null;
              },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6b90aa),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Required field' : null,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6b90aa),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFDCC2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? DateFormat('MMM dd, yyyy').format(date)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: date != null
                        ? const Color(0xFF222222)
                        : const Color(0xFF8a7a70),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6b90aa)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


  Widget _buildPsgcDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<String?>? onChanged,
    required String hint,
    bool isLoading = false,
    bool useNameAsValue = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6b90aa),
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        isLoading
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFDCC2)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFfa4e1c),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8a7a70),
                      ),
                    ),
                  ],
                ),
              )
            : DropdownButtonFormField<String>(
                value: value,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFFDCC2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFfa4e1c), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  hintText: hint,
                ),
                items: items.isEmpty
                    ? []
                    : items
                        .map((item) => DropdownMenuItem<String>(
                              value: useNameAsValue ? item['name'] : item['code'],
                              child: Text(
                                item['name'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ))
                        .toList(),
                onChanged: onChanged,
                validator: (value) => value == null ? 'Required field' : null,
              ),
      ],
    );
  }
