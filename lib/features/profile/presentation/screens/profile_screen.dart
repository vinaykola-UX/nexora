import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../app/router/app_router.dart';

/// Profile screen matching Figma Mobile UI
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to log out of your college account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(NexoraColors.textSecondary)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(RoutePaths.login);
            },
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Color(NexoraColors.error),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(NexoraColors.text)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NexoraSpacing.xs),

              // "MANAGE ACCOUNT" Subheader
              const Text(
                'MANAGE ACCOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(NexoraColors.textMuted),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),

              // User Info Card per Figma
              Container(
                padding: const EdgeInsets.all(NexoraSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(NexoraColors.border).withOpacity(0.8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Circular Avatar Placeholder (Tan/Beige Circle per Figma)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4C5B3), // Warm tan beige
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'VK',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A3B2C),
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
                          const Text(
                            'Vinay Kola',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(NexoraColors.text),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'vinaykola@bvc.edu.in',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(NexoraColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Student Tag Badge
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // Menu Settings Rows matching Figma
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
                    activeColor: const Color(NexoraColors.primary),
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

              // Logout Action in Red per Figma
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
