import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../services/faculty_materials_service.dart';

/// Faculty Study Materials management screen.
///
/// Displays all materials uploaded/linked by the authenticated faculty member
/// with deduplication status, student view counts, and analytics access.
class FacultyMaterialsScreen extends ConsumerStatefulWidget {
  const FacultyMaterialsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FacultyMaterialsScreen> createState() =>
      _FacultyMaterialsScreenState();
}

class _FacultyMaterialsScreenState
    extends ConsumerState<FacultyMaterialsScreen> {
  List<dynamic> _materials = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMaterials());
  }

  Future<String?> _getToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = await _getToken();
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required. Please sign in again.';
      });
      return;
    }

    final service = ref.read(facultyMaterialsServiceProvider);
    final result = await service.getMaterials(firebaseToken: token);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _materials = (result['materials'] as List?) ?? [];
        } else {
          _errorMessage = result['error']?.toString() ?? 'Failed to load materials.';
        }
      });
    }
  }

  Future<void> _deleteMaterial(int shareId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Material'),
        content: Text(
          'Remove "$title" from your materials? If no other lecturers reference it, the canonical copy will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(NexoraColors.error),
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = await _getToken();
    if (token == null) return;

    final service = ref.read(facultyMaterialsServiceProvider);
    final result = await service.deleteMaterial(
      firebaseToken: token,
      shareId: shareId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? result['message'] ?? 'Material unlinked.'
                : result['error'] ?? 'Failed to delete.',
          ),
          backgroundColor: result['success'] == true
              ? const Color(NexoraColors.success)
              : const Color(NexoraColors.error),
        ),
      );
      if (result['success'] == true) {
        unawaited(_loadMaterials());
      }
    }
  }

  Future<void> _showStudentFlow(int canonicalDocId, String title) async {
    final token = await _getToken();
    if (token == null) return;

    final service = ref.read(facultyMaterialsServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(NexoraColors.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StudentFlowSheet(
        canonicalDocId: canonicalDocId,
        title: title,
        token: token,
        service: service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        title: const Text(
          'Study Materials',
          style: TextStyle(
            color: Color(NexoraColors.text),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(NexoraColors.surface),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(NexoraColors.text)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMaterials,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(NexoraColors.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NexoraSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: const Color(NexoraColors.error)),
                        const SizedBox(height: NexoraSpacing.md),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(NexoraColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: NexoraSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: _loadMaterials,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(NexoraColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _materials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.library_books_outlined,
                              size: 64,
                              color: const Color(NexoraColors.textMuted)),
                          const SizedBox(height: NexoraSpacing.md),
                          const Text(
                            'No study materials uploaded yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(NexoraColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: NexoraSpacing.sm),
                          const Text(
                            'Upload materials via the web dashboard\nto start tracking student engagement.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(NexoraColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMaterials,
                      color: const Color(NexoraColors.primary),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(NexoraSpacing.md),
                        itemCount: _materials.length,
                        itemBuilder: (ctx, index) {
                          final mat = _materials[index] as Map<String, dynamic>;
                          return _MaterialCard(
                            material: mat,
                            onDelete: () => _deleteMaterial(
                              mat['share_id'] as int,
                              mat['title']?.toString() ?? 'Untitled',
                            ),
                            onViewStudents: () => _showStudentFlow(
                              mat['canonical_doc_id'] as int,
                              mat['title']?.toString() ?? 'Untitled',
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Material Card Widget
// ---------------------------------------------------------------------------

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> material;
  final VoidCallback onDelete;
  final VoidCallback onViewStudents;

  const _MaterialCard({
    required this.material,
    required this.onDelete,
    required this.onViewStudents,
  });

  @override
  Widget build(BuildContext context) {
    final title = material['title']?.toString() ?? 'Untitled';
    final subjectCode = material['subject_code']?.toString() ?? '';
    final subjectName = material['subject_name']?.toString() ?? subjectCode;
    final unit = material['unit'] ?? 1;
    final version = material['version']?.toString() ?? '1.0';
    final totalChunks = material['total_chunks'] ?? 0;
    final totalViews = material['total_views'] ?? 0;
    final totalDownloads = material['total_downloads'] ?? 0;
    final totalShares = material['total_shares'] ?? 1;
    final isPrimaryAuthor = material['is_primary_author'] == 1;
    final fileSizeBytes = material['file_size_bytes'] ?? 0;

    String sizeStr;
    if (fileSizeBytes > 1024 * 1024) {
      sizeStr = '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (fileSizeBytes > 1024) {
      sizeStr = '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    } else {
      sizeStr = '$fileSizeBytes B';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: NexoraSpacing.md),
      color: const Color(NexoraColors.surface),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(NexoraSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Subject
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.primary).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subjectCode,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(NexoraColors.primaryDark),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Unit $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(NexoraColors.textMuted),
                  ),
                ),
                const Spacer(),
                if (isPrimaryAuthor)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(NexoraColors.successLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Author',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(NexoraColors.success),
                      ),
                    ),
                  ),
                if (!isPrimaryAuthor)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(NexoraColors.infoLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Linked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(NexoraColors.info),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NexoraSpacing.sm),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(NexoraColors.text),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$subjectName  •  v$version  •  $sizeStr  •  $totalChunks chunks',
              style: const TextStyle(
                fontSize: 12,
                color: Color(NexoraColors.textMuted),
              ),
            ),

            const SizedBox(height: NexoraSpacing.md),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.visibility_outlined,
                  label: '$totalViews views',
                  color: const Color(NexoraColors.info),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.download_outlined,
                  label: '$totalDownloads downloads',
                  color: const Color(NexoraColors.success),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.people_outline,
                  label: '$totalShares faculty',
                  color: const Color(NexoraColors.primary),
                ),
              ],
            ),

            const SizedBox(height: NexoraSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: NexoraSpacing.sm),

            // Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: onViewStudents,
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Student Flow'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(NexoraColors.primary),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.link_off, size: 20),
                  tooltip: 'Unlink material',
                  color: const Color(NexoraColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Chip
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Student Flow Bottom Sheet
// ---------------------------------------------------------------------------

class _StudentFlowSheet extends StatefulWidget {
  final int canonicalDocId;
  final String title;
  final String token;
  final FacultyMaterialsService service;

  const _StudentFlowSheet({
    required this.canonicalDocId,
    required this.title,
    required this.token,
    required this.service,
  });

  @override
  State<_StudentFlowSheet> createState() => _StudentFlowSheetState();
}

class _StudentFlowSheetState extends State<_StudentFlowSheet> {
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStudentFlow());
  }

  Future<void> _loadStudentFlow() async {
    final result = await widget.service.getStudentFlow(
      firebaseToken: widget.token,
      canonicalDocId: widget.canonicalDocId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _students = (result['students'] as List?) ?? [];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NexoraSpacing.xl,
          vertical: NexoraSpacing.lg,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.divider),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: NexoraSpacing.lg),

            // Title
            Text(
              'Student Access Flow',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(NexoraColors.text),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 13,
                color: Color(NexoraColors.textMuted),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: NexoraSpacing.md),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(NexoraSpacing.xl),
                  child: CircularProgressIndicator(
                    color: Color(NexoraColors.primary),
                  ),
                ),
              )
            else if (_students.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(NexoraSpacing.xl),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: Color(NexoraColors.textMuted)),
                      SizedBox(height: NexoraSpacing.sm),
                      Text(
                        'No student interactions yet',
                        style: TextStyle(
                          color: Color(NexoraColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Summary bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.primary).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(
                      value: '${_students.length}',
                      label: 'Students',
                    ),
                    _SummaryItem(
                      value: _students.fold<int>(0, (sum, s) =>
                          sum + ((s['total_views'] as num?)?.toInt() ?? 0)).toString(),
                      label: 'Views',
                    ),
                    _SummaryItem(
                      value: _students.fold<int>(0, (sum, s) =>
                          sum + ((s['total_downloads'] as num?)?.toInt() ?? 0)).toString(),
                      label: 'Downloads',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),

              // Student list
              Expanded(
                child: ListView.separated(
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final s = _students[index] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(NexoraColors.primary)
                            .withOpacity(0.15),
                        child: Text(
                          (s['student_roll']?.toString() ?? '?')
                              .substring(
                                  (s['student_roll']?.toString().length ?? 1) -
                                      2),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(NexoraColors.primaryDark),
                          ),
                        ),
                      ),
                      title: Text(
                        s['student_name']?.toString() ??
                            s['student_roll']?.toString() ??
                            'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${s['student_roll'] ?? ''} • ${s['branch'] ?? ''} ${s['section'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(NexoraColors.textMuted),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${s['total_views'] ?? 0} views',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(NexoraColors.info),
                            ),
                          ),
                          Text(
                            '${s['total_downloads'] ?? 0} DLs',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(NexoraColors.success),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(NexoraColors.primary),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(NexoraColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
