import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Login → Server: which ALVY website the app talks to. Lets a real phone use the computer's server
/// (USB with `adb reverse`, or Wi-Fi) or the live site, without building the app again.
Future<void> showServerSettings(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ServerDialog());
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();
  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _url = TextEditingController(text: ApiConfig.webUrl);
  String? _result;
  bool? _ok;
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  String get _typed {
    var u = _url.text.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u.isEmpty || u.startsWith('http') ? u : 'http://$u';
  }

  /// The website's health check (/up) answers when the server can be reached.
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    String msg;
    var ok = false;
    try {
      final res = await http.get(Uri.parse('$_typed/up')).timeout(const Duration(seconds: 8));
      ok = res.statusCode == 200;
      msg = ok ? 'Connected to ALVY.' : 'The server answered with ${res.statusCode}. Is this the ALVY website?';
    } on TimeoutException {
      msg = 'No answer in 8 seconds. Check the address, and that the phone can reach the computer.';
    } catch (e) {
      msg = 'Can\'t reach it: $e';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = ok;
      _result = msg;
    });
  }

  Future<void> _save(String url) async {
    final used = await ApiConfig.setServer(url);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server: $used')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'ALVY website address', hintText: 'http://192.168.1.10:8000', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text(
            'Live site: https://alvy.trade\n'
            'Phone on USB: run "adb reverse tcp:8000 tcp:8000" on the computer, then use http://127.0.0.1:8000\n'
            'Phone on Wi-Fi: the computer\'s IP, e.g. http://192.168.1.10:8000 (start the site with php artisan serve --host=0.0.0.0)\n'
            'Emulator: http://10.0.2.2:8000',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B90AA)),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Text(_result!, style: TextStyle(color: _ok == true ? const Color(0xFF15803D) : const Color(0xFFDC2626))),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _save(''),
            child: const Text('Use the built-in address (${ApiConfig.defaultUrl})', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _testing ? null : _test, child: Text(_testing ? 'Testing…' : 'Test')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFfa4e1c)),
          onPressed: () => _save(_typed),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
