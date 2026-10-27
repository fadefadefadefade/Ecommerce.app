import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scan a waybill with the camera (flashlight toggle) or type the tracking number. Returns the tracking number.
Future<String?> scanWaybill(BuildContext context, {String title = 'Scan waybill'}) {
  return Navigator.push<String>(context, MaterialPageRoute(builder: (_) => _WaybillScanner(title: title)));
}

class _WaybillScanner extends StatefulWidget {
  final String title;
  const _WaybillScanner({required this.title});
  @override
  State<_WaybillScanner> createState() => _WaybillScannerState();
}

class _WaybillScannerState extends State<_WaybillScanner> {
  final _camera = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _typed = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _camera.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _finish(String value) {
    final v = value.trim().toUpperCase();
    if (_done || v.isEmpty) return;
    _done = true;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _camera,
          builder: (_, s, __) => IconButton(
            tooltip: 'Flashlight',
            icon: Icon(s.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off),
            onPressed: _camera.toggleTorch,
          ),
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: MobileScanner(
            controller: _camera,
            onDetect: (capture) {
              final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (code != null) _finish(code);
            },
            errorBuilder: (ctx, error) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Camera access is off. Allow it in Settings › Apps › ALVY › Permissions, or type the tracking number below.'
                    : 'The camera could not start. Type the tracking number below.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Or type the tracking number', isDense: true, border: OutlineInputBorder()),
                  onSubmitted: _finish,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _finish(_typed.text), child: const Text('Use')),
            ]),
          ),
        ),
      ]),
    );
  }
}
