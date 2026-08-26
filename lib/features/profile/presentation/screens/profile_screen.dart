import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../authentication/data/auth_service.dart';
import '../../data/student_profile_repository.dart';

/// Profile screen displaying user details and settings
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of Nexora AI?',
          style: TextStyle(
            fontSize: 14,
            color: Color(NexoraColors.textSecondary),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: NexoraSpacing.lg,
          vertical: NexoraSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(NexoraColors.textSecondary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: NexoraSpacing.lg,
                vertical: NexoraSpacing.sm,
              ),
              elevation: 0,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) {
        context.go(RoutePaths.login);
      }
    }
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(NexoraColors.textSecondary),
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF171717),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              elevation: 0,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentStudentProfileProvider);

    final displayEmail = user?.email ?? 'student@bvcgroup.in';
    final initials = displayEmail.isNotEmpty
        ? displayEmail.substring(0, displayEmail.length >= 2 ? 2 : 1).toUpperCase()
        : 'ST';

    final studentProfile = profileAsync.value;
    final rollNumber = studentProfile?.rollNumber ?? (user?.email != null ? user!.email!.split('@').first.toUpperCase() : '�');
    final academicYearLabel = studentProfile?.academicYearLabel ?? 'B.Tech Student';
    final studentClass = studentProfile?.studentClass;
    final section = studentProfile?.section;

    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NexoraSpacing.md),

              // Title Header
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Student credentials & settings',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(NexoraColors.textSecondary),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // User Info Card matching Figma Warm Light
              Container(
                padding: const EdgeInsets.all(NexoraSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(NexoraColors.border).withOpacity(0.8),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar Initials
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(NexoraColors.primary),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: NexoraSpacing.lg),

                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rollNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(NexoraColors.text),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(NexoraColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Badges Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Student',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(NexoraColors.background),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(NexoraColors.border)),
                                ),
                                child: Text(
                                  academicYearLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(NexoraColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.lg),

              // Academic Details Card (Read-Only)
              if (studentProfile != null) ...[
                Container(
                  padding: const EdgeInsets.all(NexoraSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(NexoraColors.border).withOpacity(0.8),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Academic Information',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(NexoraColors.text),
                        ),
                      ),
                      const Divider(color: Color(NexoraColors.divider), height: 20),
                      _buildDetailRow('Roll Number', studentProfile.rollNumber),
                      const SizedBox(height: 8),
                      _buildDetailRow('Batch', '${studentProfile.batchCode} Batch'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Academic Year', studentProfile.academicYearLabel),
                      const SizedBox(height: 8),
                      _buildDetailRow('Class / Branch', studentClass ?? '�'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Section', section ?? '�'),
                      const SizedBox(height: 8),
                      _buildDetailRow('College', studentProfile.college),
                    ],
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xl),
              ],

              // Menu Settings Rows
              _buildMenuSection([
                _buildMenuItem(
                  title: 'Change password',
                  icon: Icons.lock_outline,
                  onTap: () {
                    _showInfoDialog(
                      'Change Password',
                      'Password management is linked with your BVC College student portal credentials.',
                    );
                  },
                ),
                _buildMenuItem(
                  title: 'Privacy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => context.push(RoutePaths.terms),
                ),
                _buildMenuItem(
                  title: 'Notifications',
                  icon: Icons.notifications_none_outlined,
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeThumbColor: const Color(NexoraColors.primary),
                    onChanged: (val) {
                      setState(() {
                        _notificationsEnabled = val;
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      _notificationsEnabled = !_notificationsEnabled;
                    });
                  },
                ),
                _buildMenuItem(
                  title: 'Theme',
                  icon: Icons.palette_outlined,
                  subtitle: 'Warm Light',
                  onTap: () {
                    _showInfoDialog(
                      'Theme',
                      'Nexora is currently using the Nexora Warm Light design system.',
                    );
                  },
                ),
                _buildMenuItem(
                  title: 'App info',
                  icon: Icons.info_outline,
                  subtitle: 'v1.0.0+1',
                  onTap: () {
                    _showInfoDialog(
                      'About Nexora AI',
                      'Nexora AI v1.0.0\nBVC Engineering College Odalarevu\nContact: bvccollageai@gmail.com',
                    );
                  },
                  isLast: true,
                ),
              ]),
              const SizedBox(height: NexoraSpacing.xxl),

              // Logout Action
              Center(
                child: TextButton.icon(
                  onPressed: _showLogoutConfirmation,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFD32F2F),
                    size: 20,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NexoraSpacing.xl,
                      vertical: NexoraSpacing.md,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(NexoraColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(NexoraColors.text),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(NexoraColors.border).withOpacity(0.8),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: const Color(NexoraColors.text), size: 22),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(NexoraColors.text),
            ),
          ),
          trailing: trailing ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(NexoraColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(NexoraColors.textSecondary),
                  ),
                ],
              ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: 2,
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: NexoraSpacing.lg,
            endIndent: NexoraSpacing.lg,
            color: Color(NexoraColors.divider),
          ),
      ],
    );
  }
}

