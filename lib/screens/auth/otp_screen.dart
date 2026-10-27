import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// "Verify Your Account": the 6-digit code emailed at sign-up (the web's /login/verify page).
class OtpScreen extends StatefulWidget {
  final String otpToken;
  final String message;
  final String? maskedEmail;
  final int cooldown;

  const OtpScreen({super.key, required this.otpToken, required this.message, this.maskedEmail, this.cooldown = 0});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  late String _otpToken = widget.otpToken;
  late String _info = widget.message;
  String? _error;
  bool _busy = false;
  int _wait = 0;
  Timer? _timer;

  static const _orange = Color(0xFFfa4e1c);

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.cooldown);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final result = await auth.verifyOtp(_otpToken, _code.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isError) {
      setState(() => _error = result.message);
      return;
    }
    if (result.ok) {
      // Signed in (e.g. a seller applicant): the app opens their part.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    // Email confirmed, account waits for approval: back to login with the web's message.
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email verified'),
        content: Text(result.message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<AuthProvider>().resendOtp(_otpToken);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isError) {
      setState(() => _error = result.message);
    } else {
      setState(() {
        _otpToken = result.otpToken ?? _otpToken;
        _info = result.message;
        _code.clear();
      });
      _startCooldown(result.cooldown);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF002B4D)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 48, color: _orange),
                  const SizedBox(height: 16),
                  const Text('Verify Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF002B4D))),
                  const SizedBox(height: 6),
                  const Text('Enter the 6-digit code we emailed you',
                      textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B90AA))),
                  const SizedBox(height: 16),
                  if (_info.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                      child: Text(_info, style: const TextStyle(color: Color(0xFF065F46), fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  if (widget.maskedEmail != null)
                    Text('Sent to ${widget.maskedEmail}. The code expires in 10 minutes.',
                        textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5a4d45), fontSize: 13)),
                  const SizedBox(height: 20),
                  const Text('Verification Code', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF002B4D))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      errorText: _error,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _busy ? null : _verify(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _verify,
                      style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Didn't get the code?", style: TextStyle(color: Color(0xFF6B90AA))),
                      TextButton(
                        onPressed: _busy || _wait > 0 ? null : _resend,
                        child: Text(_wait > 0 ? 'Resend code (in ${_wait}s)' : 'Resend code'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Wrong account? Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
