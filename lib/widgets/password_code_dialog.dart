import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import 'buyer_kit.dart';

/// The website sends a 6-digit code (email or text) when a password is changed; the new password is used only after
/// the code is entered (the current one keeps working until then). Shown after a password request that
/// answered code_sent (or password_code_pending). Returns true when the password was changed.
Future<bool> confirmPasswordCode(BuildContext context, {String? message}) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordCodeDialog(message: message),
  );
  return changed == true;
}

/// Where a password-change code can go: email always; a text message when the website has SMS set up and
/// the account has a mobile number (GET /account/password/code → sms: "0917*****67").
class PasswordCodeChoice extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const PasswordCodeChoice({super.key, required this.onChanged});

  @override
  State<PasswordCodeChoice> createState() => _PasswordCodeChoiceState();
}

class _PasswordCodeChoiceState extends State<PasswordCodeChoice> {
  String? _email;
  String? _sms;
  String _via = 'email';

  @override
  void initState() {
    super.initState();
    ApiClient.get('/account/password/code').then((r) {
      if (!mounted || !r.ok) return;
      setState(() {
        _email = r.body['email'] as String?;
        _sms = r.body['sms'] as String?;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sms == null) return const SizedBox.shrink();   // email only
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Send the confirmation code to', style: TextStyle(fontWeight: FontWeight.w600)),
        RadioGroup<String>(
          groupValue: _via,
          onChanged: (v) {
            setState(() => _via = v ?? 'email');
            widget.onChanged(_via);
          },
          child: Column(children: [
            RadioListTile<String>(value: 'email', dense: true, contentPadding: EdgeInsets.zero, activeColor: kOrange,
                title: Text('Email${_email != null ? ' · $_email' : ''}')),
            RadioListTile<String>(value: 'sms', dense: true, contentPadding: EdgeInsets.zero, activeColor: kOrange,
                title: Text('Text message · $_sms')),
          ]),
        ),
      ]),
    );
  }
}

/// Whether a password answer means a code was sent.
bool passwordCodeSent(ApiResponse r) => r.ok && (r.body['code_sent'] == true || r.body['password_code_pending'] == true);

class _PasswordCodeDialog extends StatefulWidget {
  final String? message;
  const _PasswordCodeDialog({this.message});

  @override
  State<_PasswordCodeDialog> createState() => _PasswordCodeDialogState();
}

class _PasswordCodeDialogState extends State<_PasswordCodeDialog> {
  final _code = TextEditingController();
  String? _error;
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code we sent you.');
      return;
    }
    setState(() => _busy = true);
    final r = await ApiClient.post('/account/password/verify', {'code': _code.text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      Navigator.pop(context, true);
      showResult(context, r);
      return;
    }
    setState(() {
      _error = r.fieldErrors['code'] ?? r.message;
      _note = null;
    });
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    final r = await ApiClient.post('/account/password/resend');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = r.ok ? null : r.message;
      _note = r.ok ? (r.message.isNotEmpty ? r.message : 'A new code was sent.') : null;
    });
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    final r = await ApiClient.post('/account/password/cancel');
    if (!mounted) return;
    Navigator.pop(context, false);
    showResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your new password'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.message ?? 'We sent you a 6-digit code.', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Your current password keeps working until you enter the code.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 20, letterSpacing: 6),
          decoration: InputDecoration(hintText: '6-digit code', errorText: _error, errorMaxLines: 3, counterText: '', border: const OutlineInputBorder()),
          onSubmitted: (_) => _verify(),
        ),
        if (_note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_note!, style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)))),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _busy ? null : _resend, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Send a new code')),
        ),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel change')),
        FilledButton(
          onPressed: _busy ? null : _verify,
          style: FilledButton.styleFrom(backgroundColor: kOrange),
          child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm'),
        ),
      ],
    );
  }
}
