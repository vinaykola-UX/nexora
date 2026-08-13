import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_widgets.dart';

/// Profile screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      appBar: AppBar(
        title: Text('Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(NexoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    NexoraAvatar(
                      initials: 'JS',
                      size: 100,
                      onTap: () {
                        // TODO: Change profile picture
                      },
                    ),
                    SizedBox(height: NexoraSpacing.md),
                    Text(
                      'John Smith',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    SizedBox(height: NexoraSpacing.sm),
                    Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.textSecondary),
                      ),
                    ),
                    SizedBox(height: NexoraSpacing.md),
                    NexoraOutlineButton(
                      label: 'Change Profile Photo',
                      onPressed: () {
                        // TODO: Pick image
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Profile sections
              _buildSectionTitle('Personal Information'),
              _buildProfileItem(
                label: 'Email',
                value: 'john.smith@college.edu',
              ),
              _buildProfileItem(
                label: 'Full Name',
                value: 'John Smith',
                isEditable: true,
              ),
              _buildProfileItem(
                label: 'Role',
                value: 'Student',
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Account & Security
              _buildSectionTitle('Account & Security'),
              _buildProfileButton(
                label: 'Change Password',
                icon: Icons.lock,
                onTap: () {
                  // TODO: Navigate to change password
                },
              ),
              _buildProfileButton(
                label: 'Privacy Settings',
                icon: Icons.privacy_tip,
                onTap: () {
                  // TODO: Navigate to privacy settings
                },
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Preferences
              _buildSectionTitle('Preferences'),
              _buildProfileButton(
                label: 'Notifications',
                icon: Icons.notifications,
                onTap: () {
                  // TODO: Navigate to notifications
                },
              ),
              _buildProfileButton(
                label: 'Language',
                icon: Icons.language,
                onTap: () {
                  // TODO: Navigate to language settings
                },
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Logout
              NexoraOutlineButton(
                label: 'Logout',
                onPressed: () {
                  _showLogoutConfirmation(context);
                },
                borderColor: Color(NexoraColors.error),
                textColor: Color(NexoraColors.error),
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        SizedBox(height: NexoraSpacing.md),
      ],
    );
  }

  Widget _buildProfileItem({
    required String label,
    required String value,
    bool isEditable = false,
  }) {
    return NexoraCard(
      margin: EdgeInsets.only(bottom: NexoraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(NexoraColors.textMuted),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: NexoraSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(NexoraColors.text),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isEditable)
                Icon(
                  Icons.edit,
                  color: Color(NexoraColors.primary),
                  size: 20,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NexoraCard(
        margin: EdgeInsets.only(bottom: NexoraSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Color(NexoraColors.primary),
                  size: 24,
                ),
                SizedBox(width: NexoraSpacing.lg),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(NexoraColors.text),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.arrow_forward,
              color: Color(NexoraColors.textMuted),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Handle logout
              Navigator.pop(context);
            },
            child: Text(
              'Logout',
              style: TextStyle(color: Color(NexoraColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
