import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/device_features_api.dart';

void main() {
  group('DeviceFeaturesApi utilities', () {
    test('sanitizeFilename removes unsafe chars', () {
      final sanitized = DeviceFeaturesApi.sanitizeFilename('my*file نام?.pdf');
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
      expect(sanitized.endsWith('.pdf'), isTrue);
    });

    test('validateUploadFile rejects oversized file', () async {
      final tempDir = await Directory.systemTemp.createTemp('upload_test_');
      final file = File('${tempDir.path}/big.pdf');
      final bytes = List<int>.filled(DeviceFeaturesApi.maxUploadBytes + 1, 1);
      await file.writeAsBytes(bytes);

      final error = DeviceFeaturesApi.validateUploadFile(file, {'pdf'});
      expect(error, isNotNull);
      expect(error, 'حجم الملف أكبر من 10MB.');

      await tempDir.delete(recursive: true);
    });
  });
}
