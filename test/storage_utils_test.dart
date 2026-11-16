import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/core/utils/storage_utils.dart';

void main() {
  group('storage_utils formatChatFileSize & limits', () {
    test('formats byte sizes up to multi-GB correctly', () {
      expect(formatChatFileSize(0), '0 B');
      expect(formatChatFileSize(500), '500 B');
      expect(formatChatFileSize(1024), '1.0 KB');
      expect(formatChatFileSize(50 * 1024 * 1024), '50.0 MB');
      expect(formatChatFileSize(3272728868), '3.05 GB');
      expect(formatChatFileSize(5 * 1024 * 1024 * 1024), '5.00 GB');
    });

    test('max direct chat attachment limit is set to 50 MB', () {
      expect(kMaxChatAttachmentSize, equals(50 * 1024 * 1024));
    });

    test('sanitizeStorageFileName cleans unsafe characters and spaces', () {
      final sanitized = sanitizeStorageFileName('Topgrain orderx #1.7z');
      expect(sanitized, contains('Topgrain_orderx_1.7z'));
      expect(sanitized, isNot(contains('#')));
      expect(sanitized, isNot(contains(' ')));
    });

    test('getMimeType identifies 7z and archives', () {
      expect(getMimeType('7z'), 'application/x-7z-compressed');
      expect(getMimeType('zip'), 'application/zip');
      expect(getMimeType('pdf'), 'application/pdf');
    });
  });
}

