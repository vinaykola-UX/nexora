import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../models/staff_account_model.dart';
import '../../../profile/data/student_profile_repository.dart';
import '../../data/admin_repository.dart';

/// Admin Dashboard Screen for creating and managing HOD and Faculty accounts.
///
/// Strictly restricted to Administrator role.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDeptFilter;

  static const List<String> kDepartments = [
    'CSE',
    'CSM',
    'CAD',
    'ECE',
    'IT',
    'EEE',
    'MECH',
    'CIVIL',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddAccountDialog({String initialRole = 'hod'}) {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final designationController = TextEditingController();
    final phoneController = TextEditingController();
    final cabinController = TextEditingController();
    final qualController = TextEditingController();

    String currentRole = initialRole;
    String currentDept = 'CSE';
    bool sendInvite = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(NexoraColors.surface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.primary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: Color(NexoraColors.primaryDark), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentRole == 'hod' ? 'Create HOD Account' : 'Create Faculty Account',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Toggle
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Head of Department (HOD)'),
                            selected: currentRole == 'hod',
                            onSelected: (val) {
                              if (val) setDialogState(() => currentRole = 'hod');
                            },
                            selectedColor: const Color(NexoraColors.primary),
                            labelStyle: TextStyle(
                              color: currentRole == 'hod' ? Colors.white : const Color(NexoraColors.text),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Faculty'),
                            selected: currentRole == 'faculty',
                            onSelected: (val) {
                              if (val) setDialogState(() => currentRole = 'faculty');
                            },
                            selectedColor: const Color(NexoraColors.primary),
                            labelStyle: TextStyle(
                              color: currentRole == 'faculty' ? Colors.white : const Color(NexoraColors.text),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Department Dropdown
                      const Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: currentDept,
                        items: kDepartments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => currentDept = val);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(NexoraColors.background),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Full Name
                      const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Dr. K. Srinivas Rao',
                          filled: true,
                          fillColor: const Color(NexoraColors.background),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Email Field
                      const Text('College Email (@bvcgroup.in)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: currentRole == 'hod' ? 'hod.cse@bvcgroup.in' : 'faculty@bvcgroup.in',
                          filled: true,
                          fillColor: const Color(NexoraColors.background),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter email';
                          if (!v.trim().toLowerCase().endsWith('@bvcgroup.in')) {
                            return 'Email must belong to @bvcgroup.in';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Designation
                      const Text('Designation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: designationController,
                        decoration: InputDecoration(
                          hintText: currentRole == 'hod' ? 'Head of Department & Professor' : 'Assistant Professor',
                          filled: true,
                          fillColor: const Color(NexoraColors.background),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Phone & Cabin
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: phoneController,
                                  decoration: InputDecoration(
                                    hintText: '+91 ...',
                                    filled: true,
                                    fillColor: const Color(NexoraColors.background),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cabin / Room', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: cabinController,
                                  decoration: InputDecoration(
                                    hintText: 'Room 301',
                                    filled: true,
                                    fillColor: const Color(NexoraColors.background),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Qualification
                      const Text('Qualification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: qualController,
                        decoration: InputDecoration(
                          hintText: 'Ph.D. (IIT), M.Tech',
                          filled: true,
                          fillColor: const Color(NexoraColors.background),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: NexoraSpacing.md),

                      // Invitation Checkbox
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: sendInvite,
                              activeColor: const Color(0xFF0284C7),
                              onChanged: (val) {
                                setDialogState(() => sendInvite = val ?? true);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Send invitation email',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                  ),
                                  Text(
                                    'User receives an invitation link to set their own password securely.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);

                        final repo = ref.read(adminRepositoryProvider);
                        try {
                          await repo.createAccount(
                            email: emailController.text.trim(),
                            fullName: nameController.text.trim(),
                            role: currentRole,
                            department: currentDept,
                            designation: designationController.text.trim().isNotEmpty
                                ? designationController.text.trim()
                                : null,
                            phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                            cabin: cabinController.text.trim().isNotEmpty ? cabinController.text.trim() : null,
                            qualification: qualController.text.trim().isNotEmpty ? qualController.text.trim() : null,
                            sendInvitation: sendInvite,
                          );

                          ref.invalidate(staffAccountsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${currentRole.toUpperCase()} account created for ${emailController.text}!' +
                                      (sendInvite ? ' Invitation email dispatched.' : ''),
                                ),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e'), backgroundColor: const Color(NexoraColors.error)),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentStudentProfileProvider);
    final profile = profileAsync.value;

    // Strict role check: Only Admin can access this console
    if (profileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Color(NexoraColors.background),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null || !profile.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(NexoraColors.background),
        appBar: AppBar(
          backgroundColor: const Color(NexoraColors.surface),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(NexoraColors.text)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold, color: Color(NexoraColors.text))),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(NexoraSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_rounded, size: 54, color: Color(0xFFC62828)),
                const SizedBox(height: NexoraSpacing.lg),
                const Text('Administrator Access Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: NexoraSpacing.sm),
                const Text(
                  'Only registered institution administrators can manage HOD and Faculty accounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(NexoraColors.textSecondary)),
                ),
                const SizedBox(height: NexoraSpacing.xl),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF171717), foregroundColor: Colors.white),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              'Admin Account Console',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
            ),
            Text(
              'BVC Engineering College • HOD & Faculty Management',
              style: TextStyle(fontSize: 11, color: Color(NexoraColors.textSecondary)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined, color: Color(NexoraColors.primaryDark)),
            tooltip: 'View HOD Portal',
            onPressed: () => context.push(RoutePaths.hod),
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
            Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Department HODs'),
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Faculty Accounts'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(initialRole: _tabController.index == 0 ? 'hod' : 'faculty'),
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: HOD Accounts
            _buildAccountsList(role: 'hod'),

            // Tab 2: Faculty Accounts
            _buildAccountsList(role: 'faculty'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList({required String role}) {
    final accountsAsync = ref.watch(staffAccountsProvider((role: role, department: _selectedDeptFilter)));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.xl, vertical: NexoraSpacing.md),
      children: [
        // Department Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Departments'),
                selected: _selectedDeptFilter == null,
                onSelected: (val) {
                  if (val) setState(() => _selectedDeptFilter = null);
                },
                selectedColor: const Color(NexoraColors.primary),
                labelStyle: TextStyle(
                  color: _selectedDeptFilter == null ? Colors.white : const Color(NexoraColors.text),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              ...kDepartments.map((dept) {
                final isSel = _selectedDeptFilter == dept;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(dept),
                    selected: isSel,
                    onSelected: (val) {
                      setState(() => _selectedDeptFilter = val ? dept : null);
                    },
                    selectedColor: const Color(NexoraColors.primary),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(NexoraColors.text),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        const SizedBox(height: NexoraSpacing.md),

        accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline, size: 48, color: Color(NexoraColors.textMuted)),
                      const SizedBox(height: 12),
                      Text(
                        'No ${role.toUpperCase()} accounts found.',
                        style: const TextStyle(fontSize: 14, color: Color(NexoraColors.textSecondary)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddAccountDialog(initialRole: role),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Add New ${role.toUpperCase()}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF171717),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: accounts.map((acc) {
                return Container(
                  margin: const EdgeInsets.only(bottom: NexoraSpacing.sm),
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(NexoraColors.border).withOpacity(0.7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: acc.isHod
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFE0F2FE),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            acc.department,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: acc.isHod ? const Color(0xFFB45309) : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    acc.fullName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(NexoraColors.text)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    acc.role.toUpperCase(),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc.designation ?? (acc.isHod ? 'Head of Department' : 'Faculty Member'),
                              style: const TextStyle(fontSize: 12, color: Color(NexoraColors.textSecondary)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc.email,
                              style: const TextStyle(fontSize: 11.5, color: Color(NexoraColors.primaryDark)),
                            ),
                            if (acc.phone != null || acc.cabin != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${acc.phone ?? ''} ${acc.cabin != null ? '• Cabin: ${acc.cabin}' : ''}',
                                style: const TextStyle(fontSize: 11, color: Color(NexoraColors.textMuted)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(NexoraColors.error)),
                        tooltip: 'Deactivate',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Deactivate Account?'),
                              content: Text('Are you sure you want to deactivate ${acc.fullName} (${acc.email})?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(NexoraColors.error), foregroundColor: Colors.white),
                                  child: const Text('Deactivate'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(adminRepositoryProvider).deactivateAccount(acc.id);
                            ref.invalidate(staffAccountsProvider);
                          }
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Text('Error loading accounts: $e')),
        ),
      ],
    );
  }
}
