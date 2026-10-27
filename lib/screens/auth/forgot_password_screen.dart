import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';

/// The website's "Forgot password?": ALVY emails a one-time reset link; the link opens the website's page to choose
/// a new password. The answer is the same whether or not the email has an account.
class ForgotPasswordScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordScreen({super.key, this.email = ''});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  String? _error;
  String? _sent;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await BuyerApi.forgotPassword(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _sent = r.message;
      } else {
        _error = r.fieldErrors['email'] ?? r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFfa4e1c);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F3),
      appBar: AppBar( title: const Text('Forgot password'), elevation: 0),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Reset your password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF002B4D))),
        const SizedBox(height: 6),
        const Text("Enter the email of your ALVY account. We'll send you a link to choose a new password.",
            style: TextStyle(color: Color(0xFF4A7A94))),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: _sent == null,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: _error,
            errorMaxLines: 3,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 16),
        if (_sent != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7F3D0))),
            child: Text(_sent!, style: const TextStyle(color: Color(0xFF065F46))),
          ),
          const SizedBox(height: 12),
          const Text('Open the link in the email on this phone, choose your new password, then come back and log in.',
              style: TextStyle(color: Color(0xFF4A7A94), fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to login')),
        ] else
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: orange),
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send reset link', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}
