// Big camera photos are made smaller before upload; small files and PDFs are sent as they are.
import 'dart:io';
import 'dart:math';

import 'package:alvy_app/services/upload_shrink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('shrink'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a 4000×3000 camera photo becomes 1600 px wide and much smaller', () async {
    final rnd = Random(1);
    final photo = img.Image(width: 4000, height: 3000);
    for (final p in photo) {
      p.setRgb(rnd.nextInt(256), (p.x * 255) ~/ 4000, (p.y * 255) ~/ 3000);   // noisy, like a real photo
    }
    final file = File('${dir.path}/id_front.jpg')..writeAsBytesSync(img.encodeJpg(photo, quality: 95));

    final out = await UploadShrink.forUpload(file.path, tempDir: dir);
    expect(out, isNot(file.path));
    expect(out, endsWith('id_front.jpg'));
    final small = img.decodeJpg(File(out).readAsBytesSync())!;
    expect([small.width, small.height], [1600, 1200]);
    expect(File(out).lengthSync(), lessThan(file.lengthSync() ~/ 3));
    // ignore: avoid_print
    print('shrunk ${file.lengthSync() ~/ 1024} KB -> ${File(out).lengthSync() ~/ 1024} KB');
  });

  test('small images and PDFs are sent as they are', () async {
    final small = File('${dir.path}/logo.png')..writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 200)));
    final pdf = File('${dir.path}/permit.pdf')..writeAsBytesSync(List.filled(2 * 1024 * 1024, 37));
    expect(await UploadShrink.forUpload(small.path, tempDir: dir), small.path);
    expect(await UploadShrink.forUpload(pdf.path, tempDir: dir), pdf.path);
  });
}
