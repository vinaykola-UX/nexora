import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/download_item.dart';

/// Riverpod provider for DownloadsRepository
final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) {
  return DownloadsRepository();
});

/// Riverpod StateNotifier for managing the live list of downloaded items
final downloadListProvider = StateNotifierProvider<DownloadListNotifier, AsyncValue<List<DownloadItem>>>((ref) {
  final repo = ref.watch(downloadsRepositoryProvider);
  return DownloadListNotifier(repo);
});

class DownloadListNotifier extends StateNotifier<AsyncValue<List<DownloadItem>>> {
  final DownloadsRepository _repository;

  DownloadListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadItems();
  }

  Future<void> loadItems() async {
    try {
      final items = await _repository.getItems();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteItem(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((i) => i.id != id).toList());
    await _repository.deleteItem(id);
  }

  Future<void> addItem(DownloadItem item) async {
    final current = state.valueOrNull ?? [];
    final updated = [item, ...current.where((i) => i.id != item.id)];
    state = AsyncValue.data(updated);
    await _repository.saveItem(item);
  }
}

/// Repository managing downloaded academic files & desktop folder actions
class DownloadsRepository {
  static const String _storageKey = 'nexora_downloaded_items_v1';

  /// Initial sample items for BVC Engineering College students
  static final List<DownloadItem> _defaultSeedItems = [
    DownloadItem(
      id: 'bvc-ds-u1',
      title: 'Data Structures & Algorithms — Unit 1 Notes',
      fileName: 'Data_Structures_Unit_1_BVC.pdf',
      filePath: 'C:\\Users\\Admin\\Downloads\\Data_Structures_Unit_1_BVC.pdf',
      fileSizeBytes: 2450000, // 2.4 MB
      downloadedAt: DateTime.now().subtract(const Duration(hours: 3)),
      subject: 'Data Structures',
      unit: 1,
      category: DownloadCategory.notes,
    ),
    DownloadItem(
      id: 'bvc-dbms-syl',
      title: 'DBMS R20 Regulation Official Syllabus',
      fileName: 'DBMS_R20_Syllabus_BVC.pdf',
      filePath: 'C:\\Users\\Admin\\Downloads\\DBMS_R20_Syllabus_BVC.pdf',
      fileSizeBytes: 890000, // 890 KB
      downloadedAt: DateTime.now().subtract(const Duration(days: 1)),
      subject: 'Database Management Systems',
      category: DownloadCategory.syllabus,
    ),
    DownloadItem(
      id: 'bvc-os-qp-2025',
      title: 'Operating Systems Previous Year Mid-1 Question Bank',
      fileName: 'OS_Mid1_Question_Bank_2025.pdf',
      filePath: 'C:\\Users\\Admin\\Downloads\\OS_Mid1_Question_Bank_2025.pdf',
      fileSizeBytes: 1420000, // 1.4 MB
      downloadedAt: DateTime.now().subtract(const Duration(days: 2)),
      subject: 'Operating Systems',
      unit: 2,
      category: DownloadCategory.questionPaper,
    ),
    DownloadItem(
      id: 'bvc-results-sem4',
      title: 'Semester Grade Memo — B.Tech 2-2 Regular',
      fileName: 'Grade_Memo_Sem4_BVC.pdf',
      filePath: 'C:\\Users\\Admin\\Downloads\\Grade_Memo_Sem4_BVC.pdf',
      fileSizeBytes: 620000, // 620 KB
      downloadedAt: DateTime.now().subtract(const Duration(days: 4)),
      subject: 'Academic Examination',
      category: DownloadCategory.results,
    ),
  ];

  /// Get list of downloaded files (loads from SharedPreferences or populates defaults)
  Future<List<DownloadItem>> getItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> raw = jsonDecode(jsonString);
        return raw.map((m) => DownloadItem.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[DownloadsRepository] Error loading items: $e');
    }

    // Seed defaults on initial launch
    await _saveItemsToPrefs(_defaultSeedItems);
    return _defaultSeedItems;
  }

  /// Save single item
  Future<void> saveItem(DownloadItem item) async {
    final current = await getItems();
    final updated = [item, ...current.where((i) => i.id != item.id)];
    await _saveItemsToPrefs(updated);
  }

  /// Delete item by ID
  Future<void> deleteItem(String id) async {
    final current = await getItems();
    final updated = current.where((i) => i.id != id).toList();
    await _saveItemsToPrefs(updated);
  }

  /// Internal persist
  Future<void> _saveItemsToPrefs(List<DownloadItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('[DownloadsRepository] Error persisting items: $e');
    }
  }

  /// Opens the downloaded file using the platform's default application
  Future<bool> openFile(DownloadItem item) async {
    try {
      // 1. Windows Desktop specific execution
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final file = File(item.filePath);
        if (await file.exists()) {
          final result = await Process.run('cmd', ['/c', 'start', '', item.filePath]);
          return result.exitCode == 0;
        }
      }

      // 2. Mobile or URL fallback via url_launcher
      if (item.downloadUrl != null && item.downloadUrl!.isNotEmpty) {
        final uri = Uri.parse(item.downloadUrl!);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      final fileUri = Uri.file(item.filePath);
      if (await canLaunchUrl(fileUri)) {
        return await launchUrl(fileUri);
      }
      return false;
    } catch (e) {
      debugPrint('[DownloadsRepository] Error opening file: $e');
      return false;
    }
  }

  /// Reveals the downloaded file in Windows File Explorer
  Future<bool> showInExplorer(DownloadItem item) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        // Windows File Explorer with file pre-selected
        final result = await Process.run('explorer.exe', ['/select,', item.filePath]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      debugPrint('[DownloadsRepository] Error showing file in explorer: $e');
      return false;
    }
  }

  /// Filters items by category and search text query
  List<DownloadItem> filterItems(
    List<DownloadItem> items, {
    DownloadCategory category = DownloadCategory.all,
    String query = '',
  }) {
    final trimmed = query.trim().toLowerCase();

    return items.where((item) {
      // 1. Category check
      if (category != DownloadCategory.all && item.category != category) {
        return false;
      }

      // 2. Query check
      if (trimmed.isEmpty) return true;

      final titleMatch = item.title.toLowerCase().contains(trimmed);
      final subjectMatch = item.subject.toLowerCase().contains(trimmed);
      final fileMatch = item.fileName.toLowerCase().contains(trimmed);
      final unitMatch = item.unit != null && 'unit ${item.unit}'.contains(trimmed);

      return titleMatch || subjectMatch || fileMatch || unitMatch;
    }).toList();
  }

  /// Computes total storage consumed in bytes
  int calculateTotalSizeBytes(List<DownloadItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.fileSizeBytes);
  }

  /// Format size for summary display (e.g. "5.4 MB")
  String formatTotalSize(int totalBytes) {
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
