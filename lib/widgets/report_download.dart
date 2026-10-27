import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import 'buyer_kit.dart';

/// The formats a report downloads in (the website's Download PDF / Export XLSX / Export CSV).
const reportFormats = [
  ('pdf', 'PDF', Icons.picture_as_pdf_outlined),
  ('xlsx', 'Excel', Icons.grid_on_outlined),
  ('csv', 'CSV', Icons.description_outlined),
];

/// PDF / Excel / CSV buttons under a report.
class ReportDownloadButtons extends StatelessWidget {
  final bool busy;
  final ValueChanged<String> onDownload;
  const ReportDownloadButtons({super.key, required this.busy, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Download this report', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyMedium?.color)),
        const SizedBox(height: 6),
        Row(children: [
          for (final (i, f) in reportFormats.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: f.$1 == 'pdf'
                  ? FilledButton.icon(
                      onPressed: busy ? null : () => onDownload(f.$1),
                      style: FilledButton.styleFrom(backgroundColor: kOrange),
                      icon: Icon(f.$3, size: 18),
                      label: Text(f.$2))
                  : OutlinedButton.icon(onPressed: busy ? null : () => onDownload(f.$1), icon: Icon(f.$3, size: 18), label: Text(f.$2)),
            ),
          ],
        ]),
        if (busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(color: kOrange)),
      ]),
    );
  }
}

/// Saves a downloaded report in the phone's Download folder (the app's own folder if that isn't allowed),
/// then offers View (PDF) and Share.
Future<void> saveReportDownload(BuildContext context, ApiDownload f) async {
  if (!f.ok) return showResult(context, f.error!);
  try {
    final file = await _write(f.filename, f.bytes);
    if (!context.mounted) return;
    final where = file.path.contains('${Platform.pathSeparator}Download') ? 'Downloads' : 'the app\'s files';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF15803D)),
              const SizedBox(width: 8),
              Expanded(child: Text('Saved to $where', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 4),
            Text(f.filename, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 14),
            Row(children: [
              if (f.filename.toLowerCase().endsWith('.pdf')) ...[
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kOrange),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View / Print'),
                    onPressed: () {
                      Navigator.pop(sheet);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => _PdfView(f.filename, Uint8List.fromList(f.bytes))));
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: f.filename));
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) showError(context, 'Could not save the file: $e');
  }
}

/// Download/ on Android (an app may add its own files there); otherwise the app's documents folder.
Future<File> _write(String filename, List<int> bytes) async {
  final downloads = Platform.isAndroid ? Directory('/storage/emulated/0/Download') : await getDownloadsDirectory();
  final dirs = <Directory>[
    if (downloads != null) downloads,
    await getApplicationDocumentsDirectory(),
  ];
  Object? lastError;
  for (final dir in dirs) {
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(await _freeName(dir, filename));
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? 'no folder to save in';
}

/// "report.pdf", then "report (1).pdf", … so an earlier download is not overwritten.
Future<String> _freeName(Directory dir, String filename) async {
  final dot = filename.lastIndexOf('.');
  final base = dot > 0 ? filename.substring(0, dot) : filename;
  final ext = dot > 0 ? filename.substring(dot) : '';
  var path = '${dir.path}${Platform.pathSeparator}$filename';
  for (var i = 1; await File(path).exists(); i++) {
    path = '${dir.path}${Platform.pathSeparator}$base ($i)$ext';
  }
  return path;
}

class _PdfView extends StatelessWidget {
  final String name;
  final Uint8List bytes;
  const _PdfView(this.name, this.bytes);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name, overflow: TextOverflow.ellipsis), foregroundColor: Colors.white),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: name,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
