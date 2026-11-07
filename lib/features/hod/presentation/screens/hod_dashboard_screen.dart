import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/hod_models.dart';
import '../../data/hod_repository.dart';
import '../widgets/broadcast_notice_dialog.dart';
import '../widgets/faculty_card.dart';
import '../widgets/faculty_detail_sheet.dart';

/// HOD Dashboard Screen for monitoring department-wise faculty profiles,
/// Nexora app knowledge telemetry, and college academic data.
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
  FacultyStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showFacultyDetail(FacultyProfile faculty) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FacultyDetailSheet(faculty: faculty),
    );
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
            senderName: 'Dr. K. Srinivas Rao (HOD - $departmentCode)',
            priority: priority,
            targetAudience: audience,
          );
          ref.invalidate(departmentNoticesProvider(departmentCode));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notice broadcast successfully to department!'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDept = ref.watch(selectedDepartmentProvider);
    final summaryAsync = ref.watch(departmentSummaryProvider(selectedDept));
    final facultyAsync = ref.watch(departmentFacultyProvider(selectedDept));
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
          children: [
            const Text(
              'HOD Department Portal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            Text(
              'BVC Engineering College • $selectedDept',
              style: const TextStyle(
                fontSize: 12,
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
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexoraSpacing.xl,
                    vertical: NexoraSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Department Selector Horizontal Chips
                      _buildDepartmentSelector(selectedDept),

                      const SizedBox(height: NexoraSpacing.lg),

                      // KPI Overview Cards
                      summaryAsync.when(
                        data: (summary) => _buildKpiGrid(summary),
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Text('Error loading stats: $err'),
                      ),

                      const SizedBox(height: NexoraSpacing.md),
                    ],
                  ),
                ),
              ),

              // Pinned Tab Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(NexoraColors.primaryDark),
                    unselectedLabelColor: const Color(NexoraColors.textSecondary),
                    indicatorColor: const Color(NexoraColors.primary),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.people_outline, size: 20),
                        text: 'Faculty Profiles',
                      ),
                      Tab(
                        icon: Icon(Icons.analytics_outlined, size: 20),
                        text: 'App & AI Telemetry',
                      ),
                      Tab(
                        icon: Icon(Icons.school_outlined, size: 20),
                        text: 'College Academics',
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Faculty Directory
              _buildFacultyDirectoryTab(facultyAsync),

              // Tab 2: App & AI Telemetry
              _buildAppTelemetryTab(summaryAsync),

              // Tab 3: College & Academics
              _buildCollegeAcademicsTab(summaryAsync, noticesAsync, selectedDept),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Department Selector Horizontal Scroll
  // ---------------------------------------------------------------------------
  Widget _buildDepartmentSelector(String currentDept) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Select Department',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
            Text(
              'Autonomous Regulations',
              style: TextStyle(
                fontSize: 11,
                color: Color(NexoraColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: HodRepository.departments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final dept = HodRepository.departments[index];
              final code = dept['code']!;
              final isSelected = code == currentDept;

              return ChoiceChip(
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
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(NexoraColors.primary)
                        : const Color(NexoraColors.border),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Overview Cards Grid
  // ---------------------------------------------------------------------------
  Widget _buildKpiGrid(DepartmentSummary summary) {
    return Container(
      padding: const EdgeInsets.all(NexoraSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(NexoraColors.border).withOpacity(0.8),
        ),
      ),
      child: Column(
        children: [
          // Department Head & Student Strength
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.primaryLight).withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(NexoraColors.primaryDark),
                  size: 24,
                ),
              ),
              const SizedBox(width: NexoraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.hodName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    Text(
                      'HOD • ${summary.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(NexoraColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoraSpacing.md),
          const Divider(color: Color(NexoraColors.divider), height: 1),
          const SizedBox(height: NexoraSpacing.md),

          // 4 Metric Quadrants
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '${summary.totalFaculty}',
                  'Total Faculty',
                  '${summary.activeFacultyToday} active today',
                  Icons.badge_outlined,
                  const Color(0xFF6366F1),
                ),
              ),
              Container(width: 1, height: 44, color: const Color(NexoraColors.divider)),
              Expanded(
                child: _buildMetricItem(
                  '${summary.totalStudents}',
                  'Enrolled Students',
                  'Across 4 Years',
                  Icons.groups_outlined,
                  const Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoraSpacing.md),
          const Divider(color: Color(NexoraColors.divider), height: 1),
          const SizedBox(height: NexoraSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '${summary.totalAppMaterials}',
                  'App Study Notes',
                  '100% Dedup verified',
                  Icons.cloud_done_outlined,
                  const Color(0xFF16A34A),
                ),
              ),
              Container(width: 1, height: 44, color: const Color(NexoraColors.divider)),
              Expanded(
                child: _buildMetricItem(
                  '${summary.aiQueriesHandled}',
                  'AI Queries Solved',
                  '${summary.totalStudentInteractions} total reads',
                  Icons.psychology_outlined,
                  const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String value,
    String label,
    String subtext,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(NexoraColors.text),
            ),
          ),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 10,
              color: Color(NexoraColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Faculty Profiles Directory
  // ---------------------------------------------------------------------------
  Widget _buildFacultyDirectoryTab(
    AsyncValue<List<FacultyProfile>> facultyAsync,
  ) {
    return facultyAsync.when(
      data: (facultyList) {
        // Filter by search query
        var filtered = facultyList.where((f) {
          final query = _searchQuery.toLowerCase();
          final matchesQuery = f.name.toLowerCase().contains(query) ||
              f.designation.toLowerCase().contains(query) ||
              f.subjects.any((s) => s.name.toLowerCase().contains(query));
          final matchesStatus =
              _statusFilter == null || f.status == _statusFilter;
          return matchesQuery && matchesStatus;
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.md,
          ),
          children: [
            // Search Input Field
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search faculty by name, designation, or subject...',
                hintStyle: const TextStyle(
                  color: Color(NexoraColors.textMuted),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(NexoraColors.textSecondary),
                  size: 20,
                ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(NexoraColors.border)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(NexoraColors.border).withOpacity(0.8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: NexoraSpacing.sm),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('All Statuses', null),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Available', FacultyStatus.active),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('In Class', FacultyStatus.inClass),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('In Meeting', FacultyStatus.inMeeting),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('On Leave', FacultyStatus.onLeave),
                ],
              ),
            ),

            const SizedBox(height: NexoraSpacing.md),

            // Results Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} Faculty Members',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                  ),
                ),
                const Text(
                  'Tap card for full profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(NexoraColors.textMuted),
                  ),
                ),
              ],
            ),

            const SizedBox(height: NexoraSpacing.sm),

            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Color(NexoraColors.textMuted),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No faculty match the criteria',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(NexoraColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((faculty) {
                return FacultyCard(
                  faculty: faculty,
                  onTap: () => _showFacultyDetail(faculty),
                );
              }).toList(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load faculty: $err')),
    );
  }

  Widget _buildStatusFilterChip(String label, FacultyStatus? status) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: const Color(NexoraColors.primary).withOpacity(0.15),
      backgroundColor: const Color(NexoraColors.surface),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? const Color(NexoraColors.primaryDark)
            : const Color(NexoraColors.textSecondary),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? const Color(NexoraColors.primary)
              : const Color(NexoraColors.border),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: App & AI Telemetry
  // ---------------------------------------------------------------------------
  Widget _buildAppTelemetryTab(AsyncValue<DepartmentSummary> summaryAsync) {
    return summaryAsync.when(
      data: (summary) {
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.md,
          ),
          children: [
            // App Adoption & Anti-Spam Card
            Container(
              padding: const EdgeInsets.all(NexoraSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(NexoraColors.surface),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(NexoraColors.border).withOpacity(0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.insights_outlined,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nexora AI Knowledge Health',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(NexoraColors.text),
                              ),
                            ),
                            Text(
                              '${(summary.facultyAdoptionRate * 100).toInt()}% Faculty App Adoption',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NexoraSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: summary.facultyAdoptionRate,
                      minHeight: 8,
                      backgroundColor: const Color(NexoraColors.inputBackground),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(height: NexoraSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniBadge('Anti-Spam Dedup', '100% Verified', const Color(0xFF16A34A)),
                      _buildMiniBadge('Vector Chunks', '1,240 Chunks', const Color(0xFF7C3AED)),
                      _buildMiniBadge('Student Views', '${summary.totalStudentInteractions}', const Color(0xFFEA580C)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: NexoraSpacing.lg),

            // AI Concept Bottlenecks (Where students struggle)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Concept Bottlenecks (AI)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI Insights',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Topics students query most frequently in this department with doubt assistance',
              style: TextStyle(
                fontSize: 12,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
            const SizedBox(height: NexoraSpacing.md),

            ...summary.topConceptBottlenecks.map((bottleneck) {
              return Container(
                margin: const EdgeInsets.only(bottom: NexoraSpacing.sm),
                padding: const EdgeInsets.all(NexoraSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(NexoraColors.border).withOpacity(0.8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bottleneck.concept,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(NexoraColors.text),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bottleneck.difficultyLevel == 'High'
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${bottleneck.difficultyLevel} Difficulty',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: bottleneck.difficultyLevel == 'High'
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bottleneck.subjectName} (${bottleneck.subjectCode}) • ${bottleneck.studentQueryCount} AI queries',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(NexoraColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(NexoraColors.inputBackground),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Color(NexoraColors.primaryDark),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recommendation: ${bottleneck.recommendedAction}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(NexoraColors.text),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: NexoraSpacing.md),

            // Link to Faculty Materials Management
            ElevatedButton.icon(
              onPressed: () => context.push(RoutePaths.facultyMaterials),
              icon: const Icon(Icons.folder_shared_outlined, size: 18),
              label: const Text('Manage Study Materials & Student Flow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(NexoraColors.surface),
                foregroundColor: const Color(NexoraColors.primaryDark),
                elevation: 0,
                side: const BorderSide(color: Color(NexoraColors.primary)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildMiniBadge(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(NexoraColors.textMuted),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: College & Academics
  // ---------------------------------------------------------------------------
  Widget _buildCollegeAcademicsTab(
    AsyncValue<DepartmentSummary> summaryAsync,
    AsyncValue<List<DepartmentNotice>> noticesAsync,
    String departmentCode,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: NexoraSpacing.xl,
        vertical: NexoraSpacing.md,
      ),
      children: [
        // Syllabus Progress Summary Card
        Container(
          padding: const EdgeInsets.all(NexoraSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(NexoraColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(NexoraColors.border).withOpacity(0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Department Syllabus Coverage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Semester syllabus completion across all B.Tech batches',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),
              _buildBatchProgressRow('4th B.Tech (Final Year)', 0.92),
              const SizedBox(height: 10),
              _buildBatchProgressRow('3rd B.Tech (CADS / OS / CN)', 0.84),
              const SizedBox(height: 10),
              _buildBatchProgressRow('2nd B.Tech (DBMS / Java)', 0.76),
              const SizedBox(height: 10),
              _buildBatchProgressRow('1st B.Tech (C & Data Structures)', 0.68),
            ],
          ),
        ),

        const SizedBox(height: NexoraSpacing.lg),

        // Class & Section Strength Breakdown
        Container(
          padding: const EdgeInsets.all(NexoraSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(NexoraColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(NexoraColors.border).withOpacity(0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section Strength & Classroom Allocation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSectionStrengthPill('CSE-A', '68 Students', 'Room 301'),
                  _buildSectionStrengthPill('CSE-B', '66 Students', 'Room 302'),
                  _buildSectionStrengthPill('CSE-C', '64 Students', 'Room 303'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: NexoraSpacing.lg),

        // Department Notices Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Department Notices & Circulars',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showBroadcastDialog(departmentCode),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('New Notice'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(NexoraColors.primaryDark),
              ),
            ),
          ],
        ),

        noticesAsync.when(
          data: (notices) {
            return Column(
              children: notices.map((notice) {
                return Container(
                  margin: const EdgeInsets.only(bottom: NexoraSpacing.sm),
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(NexoraColors.border).withOpacity(0.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: notice.priority.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notice.priority.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: notice.priority.color,
                              ),
                            ),
                          ),
                          Text(
                            notice.targetAudience,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(NexoraColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(NexoraColors.text),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(NexoraColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Posted by ${notice.senderName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(NexoraColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading notices: $err'),
        ),
      ],
    );
  }

  Widget _buildBatchProgressRow(String batch, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              batch,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(NexoraColors.text),
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.primaryDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(NexoraColors.inputBackground),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.8
                  ? const Color(0xFF16A34A)
                  : const Color(NexoraColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionStrengthPill(String section, String count, String room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.inputBackground),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Text(
            section,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(NexoraColors.text),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: const TextStyle(
              fontSize: 11,
              color: Color(NexoraColors.textSecondary),
            ),
          ),
          Text(
            room,
            style: const TextStyle(
              fontSize: 10,
              color: Color(NexoraColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper delegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(NexoraColors.background),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

