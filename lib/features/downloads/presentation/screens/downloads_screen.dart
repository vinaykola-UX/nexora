import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../data/downloads_repository.dart';
import '../../domain/download_item.dart';

/// Screen displaying downloaded academic materials and offline files with Windows desktop integration
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DownloadCategory _selectedCategory = DownloadCategory.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(DownloadCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _handleOpenFile(DownloadItem item) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final success = await repo.openFile(item);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${item.fileName}. File may not be downloaded to local disk yet.'),
          backgroundColor: const Color(NexoraColors.text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleShowInExplorer(DownloadItem item) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final success = await repo.showInExplorer(item);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File location: ${item.filePath}'),
          backgroundColor: const Color(NexoraColors.text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _confirmDelete(DownloadItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Download',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${item.fileName}" from offline storage? You can re-download it from Nexora AI at any time.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(NexoraColors.textSecondary),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(NexoraColors.textSecondary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(downloadListProvider.notifier).deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${item.fileName}"'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(downloadListProvider);
    final repo = ref.read(downloadsRepositoryProvider);
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(NexoraColors.text),
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Downloads & Offline',
          style: TextStyle(
            color: Color(NexoraColors.text),
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          itemsAsync.when(
            data: (items) {
              final totalSize = repo.formatTotalSize(repo.calculateTotalSizeBytes(items));
              return Container(
                margin: const EdgeInsets.only(right: NexoraSpacing.lg),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(NexoraColors.border)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storage_rounded,
                      size: 14,
                      color: Color(NexoraColors.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      totalSize,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NexoraSpacing.xl,
                vertical: NexoraSpacing.sm,
              ),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(NexoraColors.border)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 14, color: Color(NexoraColors.text)),
                  decoration: InputDecoration(
                    hintText: 'Search downloaded notes, syllabus, papers...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(NexoraColors.textMuted)),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(NexoraColors.textSecondary),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: const Color(NexoraColors.textSecondary),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.xl),
                children: DownloadCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category.label),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(NexoraColors.text),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(NexoraColors.primary),
                      backgroundColor: const Color(NexoraColors.surface),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(NexoraColors.primary)
                              : const Color(NexoraColors.border),
                        ),
                      ),
                      onSelected: (_) => _onCategorySelected(category),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: NexoraSpacing.sm),

            // Download Items List
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Color(NexoraColors.primary),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load downloads: $err',
                    style: const TextStyle(color: Color(NexoraColors.error)),
                  ),
                ),
                data: (items) {
                  final filtered = repo.filterItems(
                    items,
                    category: _selectedCategory,
                    query: _searchQuery,
                  );

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.xxl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(NexoraColors.surface),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(NexoraColors.border)),
                              ),
                              child: const Icon(
                                Icons.folder_open_rounded,
                                size: 34,
                                color: Color(NexoraColors.textMuted),
                              ),
                            ),
                            const SizedBox(height: NexoraSpacing.lg),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching offline materials'
                                  : 'No downloaded files yet',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(NexoraColors.text),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with a different subject name or clear filters.'
                                  : 'Academic notes, question papers, and syllabi downloaded in chat or via RAG will appear here for offline use.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(NexoraColors.textSecondary),
                                height: 1.4,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: NexoraSpacing.lg),
                              OutlinedButton(
                                onPressed: _clearSearch,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(NexoraColors.primary),
                                  side: const BorderSide(color: Color(NexoraColors.primary)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                                child: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NexoraSpacing.xl,
                      vertical: NexoraSpacing.sm,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildDownloadCard(item, isWindows);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard(DownloadItem item, bool isWindows) {
    return Container(
      padding: const EdgeInsets.all(NexoraSpacing.md),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // File Type Icon Badge
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.isPdf
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                item.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.description_rounded,
                color: item.isPdf
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF1976D2),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: NexoraSpacing.md),

          // File Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.subject,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(NexoraColors.primaryDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.unit != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: Color(NexoraColors.textMuted)),
                      ),
                      Text(
                        'Unit ${item.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(NexoraColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.formattedSize,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(NexoraColors.textMuted),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: Color(NexoraColors.textMuted)),
                    ),
                    Text(
                      item.formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(NexoraColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Open File Button
              IconButton(
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: Color(NexoraColors.primary),
                  size: 20,
                ),
                tooltip: 'Open File',
                onPressed: () => _handleOpenFile(item),
              ),

              // Windows-Specific "Show in Folder" action
              if (isWindows) ...[
                IconButton(
                  icon: const Icon(
                    Icons.folder_outlined,
                    color: Color(NexoraColors.textSecondary),
                    size: 20,
                  ),
                  tooltip: 'Show in File Explorer',
                  onPressed: () => _handleShowInExplorer(item),
                ),
              ],

              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F),
                  size: 19,
                ),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
