import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
    const orange = Color(0xFFFA4E1C);
    return Scaffold(
      backgroundColor: Alvy.page,
      appBar: AppBar(title: const Text('Forgot password'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
            child: const Icon(Icons.lock_reset, size: 44, color: Alvy.orange),
          ),
        ),
        const SizedBox(height: 18),
        Text('Reset your password', textAlign: TextAlign.center, style: Alvy.display(size: 24, color: Alvy.text, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text("Enter the email of your ALVY account. We'll send you a link to choose a new password.",
            textAlign: TextAlign.center, style: TextStyle(color: Alvy.textSub, height: 1.4)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Alvy.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x0F2A1A10), blurRadius: 14, offset: Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Email Address', style: TextStyle(fontWeight: FontWeight.w600, color: Alvy.text)),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: _sent == null,
          decoration: InputDecoration(
            hintText: 'example@gmail.com',
            prefixIcon: const Icon(Icons.mail_outline),
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 16),
        if (_sent != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Alvy.successSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(_sent!, style: TextStyle(color: Alvy.successText)),
          ),
          const SizedBox(height: 12),
          Text('Open the link in the email on this phone, choose your new password, then come back and log in.',
              style: TextStyle(color: Alvy.textSub, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Back to login', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ] else
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: orange),
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send reset link', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_user_outlined, size: 16, color: Alvy.textMuted),
          const SizedBox(width: 6),
          Text('Your account is protected by ALVY', style: TextStyle(color: Alvy.textMuted, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
