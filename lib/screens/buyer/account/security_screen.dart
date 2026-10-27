import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/buyer_api.dart';
import '../../../services/rider_api.dart';
import '../../../services/seller_api.dart';
import '../../../widgets/buyer_kit.dart' show showResult, phoneFormatters;
import '../../../widgets/password_code_dialog.dart';
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
  String _via = 'email';

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
    // The website's password change: the seller panel's for sellers, the profile's for everyone else.
    final user = context.read<AuthProvider>().user;
    final r = user?.isSeller == true
        ? await SellerApi.changePassword(_current.text, _new.text, _confirm.text, via: _via)
        : user?.isCourier == true
            ? await RiderApi.changePassword(_current.text, _new.text, _confirm.text, via: _via)
            : await BuyerApi.changePassword(_current.text, _new.text, _confirm.text, via: _via);
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.ok) {
      _current.clear();
      _new.clear();
      _confirm.clear();
      FocusScope.of(context).unfocus();
    }
    // The website emails a code first; the new password is used once it is entered.
    if (passwordCodeSent(r)) {
      await confirmPasswordCode(context, message: r.message);
    } else {
      showResult(context, r);
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
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Your new password needs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                  ),
                  const SizedBox(height: 4),
                  for (final (ok, rule) in [
                    (_new.text.length >= 8, 'At least 8 characters'),
                    (RegExp(r'[A-Z]').hasMatch(_new.text), 'An uppercase letter'),
                    (RegExp(r'[a-z]').hasMatch(_new.text), 'A lowercase letter'),
                    (RegExp(r'\d').hasMatch(_new.text), 'A number'),
                    (RegExp(r'[^A-Za-z0-9]').hasMatch(_new.text), 'A symbol (e.g. ! @ #)'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 15, color: ok ? const Color(0xFF059669) : c.muted),
                        const SizedBox(width: 6),
                        Text(rule, style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF059669) : c.muted)),
                      ]),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Example: Mamimili@2027', style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: !_show,
                    style: TextStyle(color: c.text),
                    decoration: _decoration(context, 'Confirm new password'),
                    validator: (v) => v != _new.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 12),
                  PasswordCodeChoice(onChanged: (v) => _via = v),
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
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Email / phone change with a code is on the buyer's security page; sellers and couriers change them on their account page.
          if (user?.isSeller != true && user?.isCourier != true) ...[
            const SizedBox(height: 12),
            const _ContactChangeCard(),
          ],
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
}


/// The website's email / phone change on Accounts & Security: a 6-digit code confirms the new one.
class _ContactChangeCard extends StatefulWidget {
  const _ContactChangeCard();

  @override
  State<_ContactChangeCard> createState() => _ContactChangeCardState();
}

class _ContactChangeCardState extends State<_ContactChangeCard> {
  Map<String, dynamic>? me;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.profile();
    if (mounted && r.ok) setState(() => me = Map<String, dynamic>.from(r.body['user']));
  }

  Future<void> _run(Future<ApiResponse> Function() call) async {
    setState(() => busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r.ok && r.body['user'] != null) me = Map<String, dynamic>.from(r.body['user']);
    });
    showResult(context, r);
    if (r.ok && r.body['user'] != null) context.read<AuthProvider>().updateUser(Map<String, dynamic>.from(r.body['user']));
  }

  Future<void> _change(String what) async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(what == 'email' ? 'New email address' : 'New phone number'),
        content: TextField(
          controller: c,
          keyboardType: what == 'email' ? TextInputType.emailAddress : TextInputType.phone,
          inputFormatters: what == 'email' ? null : phoneFormatters,
          decoration: InputDecoration(hintText: what == 'email' ? 'name@example.com' : '09XXXXXXXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Send code')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _run(() => what == 'email' ? BuyerApi.changeEmail(value) : BuyerApi.changePhone(value));
  }

  Future<void> _verify() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter the 6-digit code'),
        content: TextField(controller: c, keyboardType: TextInputType.number, maxLength: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    await _run(() => BuyerApi.verifyContact(code));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final pending = me?['pending_email'] ?? me?['pending_phone'];
    return AccountCard(
      title: 'Email & Phone',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email'),
          subtitle: Text(me?['email'] ?? '', style: TextStyle(color: c.textSecondary)),
          trailing: TextButton(onPressed: busy ? null : () => _change('email'), child: const Text('Change')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Phone'),
          subtitle: Text(me?['phone'] ?? '—', style: TextStyle(color: c.textSecondary)),
          trailing: TextButton(onPressed: busy ? null : () => _change('phone'), child: const Text('Change')),
        ),
        if (pending != null) ...[
          Text('Waiting for the code to confirm: $pending', style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309))),
          Wrap(spacing: 8, children: [
            ElevatedButton(onPressed: busy ? null : _verify, child: const Text('Enter code')),
            TextButton(onPressed: busy ? null : () => _run(BuyerApi.resendContact), child: const Text('Resend')),
            TextButton(onPressed: busy ? null : () => _run(BuyerApi.cancelContact), child: const Text('Cancel change')),
          ]),
        ],
      ]),
    );
  }
}
