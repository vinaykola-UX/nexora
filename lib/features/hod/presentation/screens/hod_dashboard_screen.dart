import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/hod_models.dart';
import '../../../profile/data/student_profile_repository.dart';
import '../../data/hod_repository.dart';
import '../widgets/broadcast_notice_dialog.dart';

/// HOD Dashboard Screen: Department-wise HOD Directory & College Governance Portal.
///
/// Restricted to Head of Department (HOD) and Administrator roles only.
/// Displays department-wise HOD cards with official contact information,
/// faculty/student supervision statistics, and department broadcast announcements.
class HodDashboardScreen extends ConsumerStatefulWidget {
  const HodDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HodDashboardScreen> createState() => _HodDashboardScreenState();
}

class _HodDashboardScreenState extends ConsumerState<HodDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 2 tabs: Department HODs & Academic Telemetry/Notices (NO faculty profiles or student list)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showBroadcastDialog(String departmentCode) {
    showDialog(
      context: context,
      builder: (ctx) => BroadcastNoticeDialog(
        departmentCode: departmentCode,
        onBroadcast: (title, desc, priority, audience) async {
          final repo = ref.read(hodRepositoryProvider);
          await repo.postNotice(
            title: title,
            description: desc,
            senderName: 'HOD - $departmentCode',
            priority: priority,
            targetAudience: audience,
          );
          ref.invalidate(departmentNoticesProvider(departmentCode));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Notice broadcast successfully to $departmentCode!'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentStudentProfileProvider);
    final profile = profileAsync.value;

    // Strict Access Control: Only HOD and Admin are allowed
    final isAuthorized = profile != null && (profile.isAdmin || profile.isHod);

    // If profile is still loading, show a clean indicator
    if (profileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(NexoraColors.background),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Unauthorized access fallback
    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(NexoraColors.background),
        appBar: AppBar(
          backgroundColor: const Color(NexoraColors.surface),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(NexoraColors.text)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'HOD Department Portal',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NexoraSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person_outlined, size: 36, color: Color(0xFFC62828)),
                ),
                const SizedBox(height: NexoraSpacing.lg),
                const Text(
                  'Access Restricted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                ),
                const SizedBox(height: NexoraSpacing.sm),
                const Text(
                  'The HOD Department Portal is restricted to Department Heads and College Administrators. Student and faculty general logins are not authorized to view governance records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(NexoraColors.textSecondary), height: 1.5),
                ),
                const SizedBox(height: NexoraSpacing.xl),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Return to Main App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedDept = ref.watch(selectedDepartmentProvider);
    final summaryAsync = ref.watch(departmentSummaryProvider(selectedDept));
    final noticesAsync = ref.watch(departmentNoticesProvider(selectedDept));

    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.surface),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(NexoraColors.text)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'HOD Department Portal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            Text(
              'BVC Engineering College • Department-Wise HOD Governance',
              style: TextStyle(
                fontSize: 11,
                color: Color(NexoraColors.textSecondary),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Color(NexoraColors.primaryDark)),
            tooltip: 'Broadcast Notice',
            onPressed: () => _showBroadcastDialog(selectedDept),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(NexoraColors.primaryDark),
          unselectedLabelColor: const Color(NexoraColors.textSecondary),
          indicatorColor: const Color(NexoraColors.primary),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
          tabs: const [
            Tab(
              icon: Icon(Icons.account_balance_outlined, size: 18),
              text: 'Department HODs',
            ),
            Tab(
              icon: Icon(Icons.insights_outlined, size: 18),
              text: 'Academics & Telemetry',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Department-Wise HOD Directory (ONLY HODs, NO faculty profiles)
            _buildDepartmentHodsTab(),

            // Tab 2: High-Level Department Telemetry & Notices
            _buildAcademicsTelemetryTab(summaryAsync, noticesAsync, selectedDept),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Department-Wise HOD Directory
  // ---------------------------------------------------------------------------
  Widget _buildDepartmentHodsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: NexoraSpacing.xl,
        vertical: NexoraSpacing.md,
      ),
      children: [
        // Governance Header Banner
        Container(
          padding: const EdgeInsets.all(NexoraSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(NexoraColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.8)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.primaryLight).withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(NexoraColors.primaryDark),
                  size: 26,
                ),
              ),
              const SizedBox(width: NexoraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'College Department Heads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Department-wise HOD monitoring, official contacts & supervision counts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(NexoraColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: NexoraSpacing.md),

        // Search Field
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search department or HOD name...',
            hintStyle: const TextStyle(color: Color(NexoraColors.textMuted), fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 20, color: Color(NexoraColors.textSecondary)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(NexoraColors.surface),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(NexoraColors.border)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(NexoraColors.border).withOpacity(0.8)),
            ),
          ),
        ),

        const SizedBox(height: NexoraSpacing.md),

        // Department-wise HOD Cards List
        ...HodRepository.departments.map((deptMap) {
          final code = deptMap['code']!;
          final name = deptMap['name']!;

          if (_searchQuery.isNotEmpty &&
              !code.toLowerCase().contains(_searchQuery) &&
              !name.toLowerCase().contains(_searchQuery)) {
            return const SizedBox.shrink();
          }

          final summaryFuture = ref.watch(departmentSummaryProvider(code));
          return summaryFuture.when(
            data: (summary) => _buildDepartmentHodCard(summary),
            loading: () => Container(
              margin: const EdgeInsets.only(bottom: NexoraSpacing.md),
              padding: const EdgeInsets.all(NexoraSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(NexoraColors.surface),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text('Loading $code HOD details...'),
                ],
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          );
        }).toList(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Department-Wise HOD Card
  // ---------------------------------------------------------------------------
  Widget _buildDepartmentHodCard(DepartmentSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: NexoraSpacing.md),
      padding: const EdgeInsets.all(NexoraSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department Badge & Active HOD Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(NexoraColors.primary).withOpacity(0.3)),
                ),
                child: Text(
                  summary.code,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.primaryDark),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, size: 12, color: Color(0xFF2E7D32)),
                    SizedBox(width: 4),
                    Text(
                      'Verified HOD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: NexoraSpacing.sm),

          // Department Title
          Text(
            summary.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(NexoraColors.text),
            ),
          ),

          const SizedBox(height: NexoraSpacing.md),
          const Divider(color: Color(NexoraColors.divider), height: 1),
          const SizedBox(height: NexoraSpacing.md),

          // HOD Profile Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(NexoraColors.primaryDark),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    summary.hodName
                        .replaceAll('Dr. ', '')
                        .replaceAll('Prof. ', '')
                        .trim()
                        .split(' ')
                        .map((s) => s.isNotEmpty ? s[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.hodName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.designation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(NexoraColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 13, color: Color(NexoraColors.textMuted)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary.hodEmail,
                            style: const TextStyle(fontSize: 11.5, color: Color(NexoraColors.primaryDark)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 13, color: Color(NexoraColors.textMuted)),
                        const SizedBox(width: 4),
                        Text(
                          summary.phone,
                          style: const TextStyle(fontSize: 11.5, color: Color(NexoraColors.textSecondary)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.meeting_room_outlined, size: 13, color: Color(NexoraColors.textMuted)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            summary.cabin,
                            style: const TextStyle(fontSize: 11.5, color: Color(NexoraColors.textMuted)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: NexoraSpacing.md),

          // Department Supervised Metrics Row (Total Faculty & Enrolled Students)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(NexoraColors.background),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${summary.totalFaculty} Faculty',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                          ),
                          Text(
                            '${summary.activeFacultyToday} active today',
                            style: const TextStyle(fontSize: 10, color: Color(NexoraColors.textMuted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: const Color(NexoraColors.divider)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.groups_outlined, size: 16, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${summary.totalStudents} Students',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                            ),
                            const Text(
                              'Enrolled across years',
                              style: TextStyle(fontSize: 10, color: Color(NexoraColors.textMuted)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: NexoraSpacing.sm),

          // Quick Action: Broadcast Notice Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: summary.hodEmail));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ${summary.hodEmail} to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Email', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showBroadcastDialog(summary.code),
                icon: const Icon(Icons.campaign_outlined, size: 15),
                label: const Text('Broadcast Notice', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: High-Level Department Telemetry & Academics
  // ---------------------------------------------------------------------------
  Widget _buildAcademicsTelemetryTab(
    AsyncValue<DepartmentSummary> summaryAsync,
    AsyncValue<List<DepartmentNotice>> noticesAsync,
    String selectedDept,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: NexoraSpacing.xl,
        vertical: NexoraSpacing.md,
      ),
      children: [
        // Department Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HodRepository.departments.map((dept) {
              final code = dept['code']!;
              final isSelected = code == selectedDept;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(code),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(selectedDepartmentProvider.notifier).state = code;
                    }
                  },
                  selectedColor: const Color(NexoraColors.primary),
                  backgroundColor: const Color(NexoraColors.surface),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(NexoraColors.text),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: NexoraSpacing.md),

        // AI Knowledge Health Card
        summaryAsync.when(
          data: (summary) => Container(
            padding: const EdgeInsets.all(NexoraSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(NexoraColors.surface),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: Color(NexoraColors.primaryDark), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      '${summary.code} AI & Academic Telemetry',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                    ),
                  ],
                ),
                const SizedBox(height: NexoraSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatPill('App Notes', '${summary.totalAppMaterials}', const Color(0xFF16A34A)),
                    _buildStatPill('AI Queries', '${summary.aiQueriesHandled}', const Color(0xFF8B5CF6)),
                    _buildStatPill('Syllabus', '${(summary.averageSyllabusProgress * 100).toInt()}%', const Color(0xFF0284C7)),
                  ],
                ),
                const SizedBox(height: NexoraSpacing.md),
                const Text(
                  'Top Student Concept Bottlenecks (RAG Insights)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                ),
                const SizedBox(height: 6),
                ...summary.topConceptBottlenecks.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_right_rounded, size: 18, color: Color(NexoraColors.textSecondary)),
                      Expanded(
                        child: Text(
                          '${b.concept} (${b.difficultyLevel})',
                          style: const TextStyle(fontSize: 12, color: Color(NexoraColors.textSecondary)),
                        ),
                      ),
                      Text('${b.studentQueryCount} queries', style: const TextStyle(fontSize: 11, color: Color(NexoraColors.textMuted))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: NexoraSpacing.lg),

        // Department Notices Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Department Notices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(NexoraColors.primaryDark)),
              onPressed: () => _showBroadcastDialog(selectedDept),
            ),
          ],
        ),

        const SizedBox(height: NexoraSpacing.sm),

        noticesAsync.when(
          data: (notices) {
            if (notices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No active notices for this department.', style: TextStyle(color: Color(NexoraColors.textMuted)))),
              );
            }
            return Column(
              children: notices.map((n) {
                return Container(
                  margin: const EdgeInsets.only(bottom: NexoraSpacing.sm),
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                            ),
                          ),
                          Text(
                            n.priority.displayName,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: n.priority.color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.description,
                        style: const TextStyle(fontSize: 12, color: Color(NexoraColors.textSecondary)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'By ${n.senderName} • Target: ${n.targetAudience}',
                        style: const TextStyle(fontSize: 10, color: Color(NexoraColors.textMuted)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading notices: $e'),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(NexoraColors.textMuted))),
        ],
      ),
    );
  }
}
