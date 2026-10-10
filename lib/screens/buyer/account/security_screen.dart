import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/buyer_colors.dart';
import 'account_ui.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = ApiService.unwrap(await ApiService.put('/profile/password', {
        'current_password': _current.text,
        'password': _new.text,
        'password_confirmation': _confirm.text,
      }));
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _confirm.clear();
      FocusScope.of(context).unfocus();
      showAccountSnack(context, data['message'] ?? 'Password changed successfully.');
    } catch (e) {
      if (mounted) showAccountSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final c = context.bc;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.muted),
      filled: true,
      fillColor: c.subtle,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      suffixIcon: IconButton(
        icon: Icon(_show ? Icons.visibility_off : Icons.visibility, color: c.muted),
        onPressed: () => setState(() => _show = !_show),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final user = context.watch<AuthProvider>().user;
    final strength = _strength(_new.text);

    return Scaffold(
      backgroundColor: c.background,
      appBar: accountAppBar('Security'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          AccountCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BuyerPalette.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: BuyerPalette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in as', style: TextStyle(fontSize: 12, color: c.muted)),
                      Text(user?.email ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AccountCard(
            title: 'Change Password',
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _current,
                    obscureText: !_show,
                    style: TextStyle(color: c.text),
                    decoration: _decoration(context, 'Current password'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _new,
                    obscureText: !_show,
                    style: TextStyle(color: c.text),
                    decoration: _decoration(context, 'New password'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.length < 8) return 'Use at least 8 characters';
                      if (v == _current.text) return 'New password must be different';
                      return null;
                    },
                  ),
                  if (_new.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength.$1,
                        minHeight: 6,
                        backgroundColor: c.border,
                        color: strength.$3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Strength: ${strength.$2}', style: TextStyle(fontSize: 12, color: strength.$3)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: !_show,
                    style: TextStyle(color: c.text),
                    decoration: _decoration(context, 'Confirm new password'),
                    validator: (v) => v != _new.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BuyerPalette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AccountCard(
            title: 'Tips',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                'Use at least 8 characters with a mix of letters, numbers and symbols.',
                'Don\'t reuse a password from another site.',
                'Changing your password signs you out of your other devices.',
              ]
                  .map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: BuyerPalette.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: c.textSecondary))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// (progress 0-1, label, color)
  (double, String, Color) _strength(String p) {
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    if (score <= 2) return (0.33, 'Weak', const Color(0xFFC62828));
    if (score <= 3) return (0.66, 'Medium', const Color(0xFFEF6C00));
    return (1.0, 'Strong', const Color(0xFF2E7D32));
  }
}
