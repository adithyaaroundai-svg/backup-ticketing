import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/features/developer_crm/core/crm_storage_service.dart';
import 'package:ticketing_system/features/developer_crm/domain/entities/user.dart';
import 'package:ticketing_system/features/developer_crm/presentation/widgets/attachment_picker_section.dart';
import 'package:ticketing_system/features/developer_crm/presentation/widgets/task_form_dialog.dart';

void main() {
  group('CrmStorageService helpers', () {
    test('sanitizeFileName cleans unsafe characters and blanks', () {
      expect(CrmStorageService.sanitizeFileName('   '), 'attachment');
      expect(
        CrmStorageService.sanitizeFileName('report #1 (final).pdf'),
        'report__1__final_.pdf',
      );
      expect(
        CrmStorageService.sanitizeFileName('invoice_2026-11.xlsx'),
        'invoice_2026-11.xlsx',
      );
    });

    test('buildStoragePath places files under crm_files/ without collisions', () {
      final p1 = CrmStorageService.buildStoragePath('backup.zip');
      final p2 = CrmStorageService.buildStoragePath('backup.zip');
      expect(p1, startsWith('crm_files/'));
      expect(p1, endsWith('_backup.zip'));
      expect(p1, isNot(equals(p2)));
    });

    test('getMimeType resolves common extensions and handles extensionless names', () {
      expect(CrmStorageService.getMimeType('README'), 'application/octet-stream');
      expect(CrmStorageService.getMimeType('trailing.'), 'application/octet-stream');
      expect(CrmStorageService.getMimeType('archive.zip'), 'application/zip');
      expect(CrmStorageService.getMimeType('manual.PDF'), 'application/pdf');
      expect(
        CrmStorageService.getMimeType('sheet.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(
        CrmStorageService.getMimeType('doc.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    });

    test('isLegacyUnmigratedPath detects bare legacy UUID filenames only', () {
      expect(
        CrmStorageService.isLegacyUnmigratedPath('d7bef719-b58d-4d89-bca6-4e1696ff166c.docx'),
        isTrue,
      );
      expect(CrmStorageService.isLegacyUnmigratedPath('crm_files/123_doc.docx'), isFalse);
      expect(CrmStorageService.isLegacyUnmigratedPath('https://cdn.example.com/a.pdf'), isFalse);
      expect(CrmStorageService.isLegacyUnmigratedPath(''), isFalse);
      expect(CrmStorageService.isLegacyUnmigratedPath(null), isFalse);
    });

    test('resolveBucketAndPath normalizes bucket and object prefixes', () {
      expect(
        CrmStorageService.resolveBucketAndPath('crm_files/123_a.pdf'),
        (bucket: 'chat_attachments', path: 'crm_files/123_a.pdf'),
      );
      expect(
        CrmStorageService.resolveBucketAndPath('/uploads/crm_files/123_a.pdf'),
        (bucket: 'chat_attachments', path: 'crm_files/123_a.pdf'),
      );
      expect(
        CrmStorageService.resolveBucketAndPath('chat_attachments/crm_files/123_a.pdf'),
        (bucket: 'chat_attachments', path: 'crm_files/123_a.pdf'),
      );
      expect(
        CrmStorageService.resolveBucketAndPath('dev_crm_files/legacy.xlsx'),
        (bucket: 'dev_crm_files', path: 'legacy.xlsx'),
      );
      expect(CrmStorageService.resolveBucketAndPath('https://example.com/x.pdf'), isNull);
      expect(CrmStorageService.resolveBucketAndPath('   '), isNull);
    });

    test('buildDownloadUrl appends download query parameter cleanly', () {
      final url = CrmStorageService.buildDownloadUrl(
        'crm_files/1700_spec.pdf',
        filename: 'Project Spec.pdf',
        resolvePublicUrl: (bucket, path) =>
            'https://example.supabase.co/storage/v1/object/public/$bucket/$path',
      );
      expect(
        url,
        'https://example.supabase.co/storage/v1/object/public/chat_attachments/crm_files/1700_spec.pdf?download=Project+Spec.pdf',
      );

      final alreadyParam = CrmStorageService.buildDownloadUrl(
        'https://example.com/file.zip?download=orig.zip',
        filename: 'other.zip',
        resolvePublicUrl: (_, __) => '',
      );
      expect(alreadyParam, 'https://example.com/file.zip?download=orig.zip');
    });

    test('mapUploadError translates 413 into actionable CrmStorageException', () {
      final ex = CrmStorageService.mapUploadError(
        Exception('StorageException(message: Payload too large, statusCode: 413)'),
        'huge.zip',
        120 * 1024 * 1024,
      );
      expect(ex, isA<CrmStorageException>());
      expect(ex.statusCode, 413);
      expect(ex.message, contains('huge.zip'));
      expect(ex.message, contains('50 MB'));
    });
  });

  group('Attachment widgets and TaskFormDialog upload lifecycle', () {
    test('hasInvalidCrmAttachments flags 0 B files', () {
      expect(
        hasInvalidCrmAttachments([
          PlatformFile(name: 'valid.pdf', size: 1024),
          PlatformFile(name: 'empty.txt', size: 0),
        ]),
        isTrue,
      );
      expect(
        hasInvalidCrmAttachments([
          PlatformFile(name: 'valid.pdf', size: 1024),
        ]),
        isFalse,
      );
    });

    test('formatCrmUploadProgressLabel formats single and multi-file labels', () {
      expect(
        formatCrmUploadProgressLabel(0, 1, 0.42, 'report.pdf'),
        'Uploading report.pdf (42%)...',
      );
      expect(
        formatCrmUploadProgressLabel(1, 3, 0.75, 'archive.zip'),
        'Uploading 2/3 (75%): archive.zip',
      );
    });

    testWidgets('PendingAttachmentList shows warnings and supports remove/clear', (tester) async {
      final files = [
        PlatformFile(name: 'normal.pdf', size: 2048),
        PlatformFile(name: 'too_big.zip', size: 60 * 1024 * 1024),
        PlatformFile(name: 'empty.txt', size: 0),
      ];
      int? removedIndex;
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingAttachmentList(
              files: files,
              onRemove: (i) => removedIndex = i,
              onClearAll: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('3 files selected'), findsOneWidget);
      expect(find.text('normal.pdf'), findsOneWidget);
      expect(find.textContaining('Exceeds 50 MB limit'), findsOneWidget);
      expect(find.textContaining('Empty or unreadable file'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      expect(cleared, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      expect(removedIndex, 0);
    });

    testWidgets('TaskFormDialog keeps form open with error on failed submit and closes on retry',
        (tester) async {
      var attempt = 0;
      TaskFormResult? dialogResult;
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  dialogResult = await showTaskFormDialog(
                    context,
                    users: [UserRef(id: 1, name: 'Sharika')],
                    onSubmit: (result, onProgress) async {
                      attempt++;
                      onProgress(0, 1, 0.5, 'spec.pdf');
                      if (attempt == 1) {
                        throw CrmStorageException('Upload failed: simulated 413');
                      }
                      await completer.future;
                    },
                  );
                },
                child: const Text('Open Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Implement TUS chunking');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Dialog must stay open with inline error and preserved text
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Upload failed: simulated 413'), findsOneWidget);
      expect(find.text('Implement TUS chunking'), findsOneWidget);

      // Retry -> remains open with progress banner while in-flight
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Uploading spec.pdf (50%)...'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Add task'), findsNothing);
      expect(dialogResult, isNotNull);
      expect(dialogResult!.description, 'Implement TUS chunking');
    });
  });
}

