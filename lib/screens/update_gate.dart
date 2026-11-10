import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update.dart';
import '../theme/app_theme.dart';
import '../theme/buyer_colors.dart';

/// Checks for a newer build as the app opens. The app shows right away; if this phone is on an
/// older build, the update screen replaces it and there is no way past it except updating.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  AppRelease? _release;

  @override
  void initState() {
    super.initState();
    AppUpdate.check().then((r) {
      if (r == null) {
        AppUpdate.cleanup();   // up to date: the APK of the last update is no longer needed
      } else if (mounted) {
        setState(() => _release = r);
      }
    });
  }

  @override
  Widget build(BuildContext context) => _release == null ? widget.child : _UpdateRequiredScreen(release: _release!);
}

class _UpdateRequiredScreen extends StatefulWidget {
  final AppRelease release;
  const _UpdateRequiredScreen({required this.release});
  @override
  State<_UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<_UpdateRequiredScreen> {
  bool _busy = false;
  double _progress = 0;
  String? _message;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    try {
      final path = await AppUpdate.download(widget.release, (p) {
        if (mounted) setState(() => _progress = p);
      });
      final opened = await AppUpdate.install(path);
      if (mounted && !opened) _message = 'Allow ALVY to install apps on the screen that opened, then come back and tap Update again.';
    } catch (_) {
      if (mounted) _message = 'The update could not be downloaded. Check your internet and try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final size = widget.release.size;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(color: Color(0xFFFFE4DC), shape: BoxShape.circle),
                      child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Update required', textAlign: TextAlign.center, style: Alvy.display(size: 24, color: c.text, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'A new version of ALVY${widget.release.version.isEmpty ? '' : ' (${widget.release.version})'} is ready. Update to keep using the app. Your account and data stay as they are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (_busy) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: _progress > 0 ? _progress : null, minHeight: 8, color: Alvy.orange, backgroundColor: c.subtle),
                    ),
                    const SizedBox(height: 8),
                    Text('Downloading… ${(_progress * 100).round()}%', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                  ] else
                    FilledButton(
                      onPressed: _update,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: Text(size > 0 ? 'Update (${(size / 1048576).round()} MB)' : 'Update'),
                    ),
                  if (!_busy) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(AppUpdate.websiteUrl), mode: LaunchMode.externalApplication),
                      child: const Text('Or get it from the website'),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: Alvy.dangerText, fontSize: 13)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
