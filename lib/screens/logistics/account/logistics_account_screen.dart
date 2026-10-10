import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

class LogisticsAccountScreen extends StatefulWidget {
  const LogisticsAccountScreen({super.key});

  @override
  State<LogisticsAccountScreen> createState() => _LogisticsAccountScreenState();
}

class _LogisticsAccountScreenState extends State<LogisticsAccountScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPasswords = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final user = await LogisticsService.updateAccount(_name.text.trim(), _email.text.trim());
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(user);
      showSnack(context, 'Account details updated.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      final message = await LogisticsService.updatePassword(
        _currentPassword.text,
        _newPassword.text,
        _confirmPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      showSnack(context, message);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  InputDecoration _decoration(String label, {bool password = false}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      isDense: true,
      suffixIcon: password
          ? IconButton(
              icon: Icon(_showPasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPasswords = !_showPasswords),
            )
          : null,
    );
  }

  Widget _saveButton(String label, bool busy, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: LogisticsColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Account Management'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Profile Details',
            child: Form(
              key: _profileForm,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: _decoration('Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration('Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _saveButton('Save Changes', _savingProfile, _saveProfile),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Change Password',
            child: Form(
              key: _passwordForm,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: !_showPasswords,
                    decoration: _decoration('Current Password', password: true),
                    validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: !_showPasswords,
                    decoration: _decoration('New Password', password: true),
                    validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: !_showPasswords,
                    decoration: _decoration('Confirm New Password', password: true),
                    validator: (v) => v != _newPassword.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 16),
                  _saveButton('Update Password', _savingPassword, _savePassword),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
