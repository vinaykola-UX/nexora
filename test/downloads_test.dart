import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/downloads/domain/download_item.dart';
import 'package:nexora/features/downloads/data/downloads_repository.dart';

void main() {
  group('DownloadItem Domain Model Tests', () {
    final testDate = DateTime(2026, 9, 18, 14, 30);

    test('formats file size correctly across units', () {
      final itemBytes = DownloadItem(
        id: '1',
        title: 'Small text',
        fileName: 'readme.txt',
        filePath: 'C:\\Downloads\\readme.txt',
        fileSizeBytes: 512,
        downloadedAt: testDate,
        subject: 'General',
      );
      expect(itemBytes.formattedSize, equals('512 B'));

      final itemKb = itemBytes.copyWith(fileSizeBytes: 1024 * 45); // 45 KB
      expect(itemKb.formattedSize, equals('45.0 KB'));

      final itemMb = itemBytes.copyWith(fileSizeBytes: (1024 * 1024 * 3.5).toInt()); // 3.5 MB
      expect(itemMb.formattedSize, equals('3.5 MB'));

      final itemGb = itemBytes.copyWith(fileSizeBytes: (1024 * 1024 * 1024 * 1.5).toInt()); // 1.5 GB
      expect(itemGb.formattedSize, equals('1.50 GB'));
    });

    test('detects file extension and file types accurately', () {
      final pdfItem = DownloadItem(
        id: 'pdf-1',
        title: 'Unit 1 Notes',
        fileName: 'Unit_1_Notes.pdf',
        filePath: 'C:\\Downloads\\Unit_1_Notes.pdf',
        fileSizeBytes: 1000,
        downloadedAt: testDate,
        subject: 'Data Structures',
      );
      expect(pdfItem.extension, equals('.pdf'));
      expect(pdfItem.isPdf, isTrue);
      expect(pdfItem.isText, isFalse);
      expect(pdfItem.isDoc, isFalse);

      final docItem = pdfItem.copyWith(fileName: 'Assignment.docx');
      expect(docItem.extension, equals('.docx'));
      expect(docItem.isDoc, isTrue);
      expect(docItem.isPdf, isFalse);
    });

    test('serializes to and from JSON correctly (roundtrip)', () {
      final original = DownloadItem(
        id: 'roundtrip-1',
        title: 'DBMS Notes',
        fileName: 'dbms_u1.pdf',
        filePath: 'C:\\test\\dbms_u1.pdf',
        fileSizeBytes: 2048000,
        downloadedAt: testDate,
        subject: 'DBMS',
        unit: 1,
        category: DownloadCategory.notes,
        downloadUrl: 'https://example.com/dbms.pdf',
      );

      final json = original.toJson();
      final restored = DownloadItem.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.fileName, equals(original.fileName));
      expect(restored.filePath, equals(original.filePath));
      expect(restored.fileSizeBytes, equals(original.fileSizeBytes));
      expect(restored.subject, equals(original.subject));
      expect(restored.unit, equals(original.unit));
      expect(restored.category, equals(original.category));
      expect(restored.downloadUrl, equals(original.downloadUrl));
    });
  });

  group('DownloadsRepository Filter & Calculation Tests', () {
    late DownloadsRepository repo;
    final testDate = DateTime(2026, 9, 18);

    final items = [
      DownloadItem(
        id: '1',
        title: 'Data Structures Unit 1 Notes',
        fileName: 'DS_U1.pdf',
        filePath: 'C:\\DS_U1.pdf',
        fileSizeBytes: 2000000, // ~2 MB
        downloadedAt: testDate,
        subject: 'Data Structures',
        unit: 1,
        category: DownloadCategory.notes,
      ),
      DownloadItem(
        id: '2',
        title: 'DBMS R20 Syllabus',
        fileName: 'DBMS_Syllabus.pdf',
        filePath: 'C:\\DBMS_Syllabus.pdf',
        fileSizeBytes: 1000000, // ~1 MB
        downloadedAt: testDate,
        subject: 'Database Systems',
        category: DownloadCategory.syllabus,
      ),
      DownloadItem(
        id: '3',
        title: 'Operating Systems Previous Year Paper',
        fileName: 'OS_Mid1.pdf',
        filePath: 'C:\\OS_Mid1.pdf',
        fileSizeBytes: 3000000, // ~3 MB
        downloadedAt: testDate,
        subject: 'Operating Systems',
        unit: 2,
        category: DownloadCategory.questionPaper,
      ),
    ];

    setUp(() {
      repo = DownloadsRepository();
    });

    test('calculates total size in bytes and formats accurately', () {
      final total = repo.calculateTotalSizeBytes(items);
      expect(total, equals(6000000));
      expect(repo.formatTotalSize(total), equals('5.7 MB'));
    });

    test('filters items by category', () {
      final notes = repo.filterItems(items, category: DownloadCategory.notes);
      expect(notes.length, equals(1));
      expect(notes.first.id, equals('1'));

      final syllabus = repo.filterItems(items, category: DownloadCategory.syllabus);
      expect(syllabus.length, equals(1));
      expect(syllabus.first.id, equals('2'));

      final all = repo.filterItems(items, category: DownloadCategory.all);
      expect(all.length, equals(3));
    });

    test('filters items by query (title search)', () {
      final results = repo.filterItems(items, query: 'syllabus');
      expect(results.length, equals(1));
      expect(results.first.id, equals('2'));
    });

    test('filters items by query (subject search)', () {
      final results = repo.filterItems(items, query: 'Operating Systems');
      expect(results.length, equals(1));
      expect(results.first.id, equals('3'));
    });

    test('filters items by query (unit search)', () {
      final results = repo.filterItems(items, query: 'Unit 1');
      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));
    });

    test('filters items with both category and query combined', () {
      final results = repo.filterItems(
        items,
        category: DownloadCategory.notes,
        query: 'Structures',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('1'));

      final noMatch = repo.filterItems(
        items,
        category: DownloadCategory.syllabus,
        query: 'Structures',
      );
      expect(noMatch, isEmpty);
    });

    test('handles empty query gracefully', () {
      final results = repo.filterItems(items, query: '   ');
      expect(results.length, equals(3));
    });
  });
}
