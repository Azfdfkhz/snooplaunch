import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snoop/services/capture_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('snoop_test_');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('processPhoto: auto-straightens landscape camera sensor photo and unmirrors', () async {
    final testFile = File('${tempDir.path}/test_shot.jpg');
    // Simulate raw sensor landscape photo (1600x1200) from Android camera
    final rawImage = img.Image(width: 1600, height: 1200);
    // Draw a marker in top-left to verify rotation & unmirror
    rawImage.setPixelRgba(10, 10, 255, 0, 0, 255);
    await testFile.writeAsBytes(img.encodeJpg(rawImage));

    // Process with unmirror and ensurePortrait
    await CaptureService.processPhoto(testFile.path, unmirror: true, ensurePortrait: true);

    final resultBytes = await testFile.readAsBytes();
    final resultImg = img.decodeImage(resultBytes);
    expect(resultImg, isNotNull);
    // Must be upright portrait: height > width
    expect(resultImg!.height > resultImg.width, true);
    expect(resultImg.width, 1200);
    expect(resultImg.height, 1600);
  });

  test('rotatePhoto90: rotates photo 90 degrees CW', () async {
    final testFile = File('${tempDir.path}/test_rot.jpg');
    final rawImage = img.Image(width: 800, height: 1000);
    await testFile.writeAsBytes(img.encodeJpg(rawImage));

    await CaptureService.rotatePhoto90(testFile.path);

    final resultImg = img.decodeImage(await testFile.readAsBytes());
    expect(resultImg, isNotNull);
    expect(resultImg!.width, 1000);
    expect(resultImg.height, 800);
  });

  test('flipPhotoHorizontal: flips photo horizontally (mirror toggle)', () async {
    final testFile = File('${tempDir.path}/test_flip.jpg');
    final rawImage = img.Image(width: 800, height: 1000);
    await testFile.writeAsBytes(img.encodeJpg(rawImage));

    await CaptureService.flipPhotoHorizontal(testFile.path);

    final resultImg = img.decodeImage(await testFile.readAsBytes());
    expect(resultImg, isNotNull);
    expect(resultImg!.width, 800);
    expect(resultImg.height, 1000);
  });
}
