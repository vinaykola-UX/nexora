import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_textfield.dart';
import '../../data/student_profile_repository.dart';

/// Connect BVC Student Portal Screen
///
/// Replaces manual branch & section selection with automated official BVC portal authentication.
/// Flow:
/// 1. Student enters official roll number (e.g. 25221A0568)
/// 2. Automatic uppercase normalization
/// 3. Authenticates against https://www.bvcecautonomous.com/SBLogin.aspx
/// 4. Retrieves official student information (Name, Branch, Course, Batch, etc.)
/// 5. Shows BVC STUDENT VERIFIED card
/// 6. Continue navigates to Terms & Conditions -> Home
class ClassSetupScreen extends StatefulWidget {
  const ClassSetupScreen({Key? key}) : super(key: key);

  @override
  State<ClassSetupScreen> createState() => _ClassSetupScreenState();
}

class _ClassSetupScreenState extends State<ClassSetupScreen> {
  final _rollController = TextEditingController();
  final _rollFocus = FocusNode();
  final StudentProfileRepository _repository = StudentProfileRepository();

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _verifiedProfile;

  @override
  void initState() {
    super.initState();
    // Pre-fill roll number from logged-in user email if available
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      final emailPrefix = currentUser.email!.split('@').first.trim();
      final rollPattern = RegExp(r'^[0-9]{2}[0-9A-Za-z]{2}[0-9A-Za-z][0-9A-Za-z0-9]{4,5}$');
      if (rollPattern.hasMatch(emailPrefix)) {
        _rollController.text = emailPrefix.toUpperCase();
      }
    }
  }

  @override
  void dispose() {
    _rollController.dispose();
    _rollFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Action: Connect with Official BVC Portal
  // ---------------------------------------------------------------------------

  Future<void> _onConnectBvc() async {
    final rawRoll = _rollController.text.trim();
    if (rawRoll.isEmpty) {
      setState(() => _errorMessage = 'Please enter your official BVC roll number.');
      return;
    }

    final normalizedRoll = rawRoll.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final rollPattern = RegExp(r'^[0-9]{2}[0-9A-Z]{2}[0-9A-Z][0-9A-Z0-9]{4,5}$');
    if (!rollPattern.hasMatch(normalizedRoll)) {
      setState(() => _errorMessage = 'Invalid roll number format. Example: 25221A0568');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verifiedData = await _repository.connectBvcStudent(normalizedRoll);
      if (!mounted) return;

      setState(() {
        _verifiedProfile = verifiedData;
        _isLoading = false;
      });
    } on NexoraProfileException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected connection error occurred. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Continue to Terms & Conditions
  // ---------------------------------------------------------------------------

  void _onContinueToTerms() {
    context.go(RoutePaths.terms);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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

              // Back button if editing or returning
              if (Navigator.of(context).canPop())
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(NexoraColors.surface),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(NexoraColors.border)),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(NexoraColors.text),
                    ),
                  ),
                ),

              const SizedBox(height: NexoraSpacing.lg),

              // -- Headline & Subtitle --------------------------------------
              const Text(
                'Connect to BVC',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Connect your BVC student account using your official BVC student portal credentials.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // -- Error Banner ---------------------------------------------
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.errorLight).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(NexoraColors.error).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Color(NexoraColors.error), size: 20),
                      const SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(NexoraColors.error),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NexoraSpacing.lg),
              ],

              // -- Pre-Verification Form vs Verified Card --------------------
              if (_verifiedProfile == null) ...[
                // Roll Number Input
                NexoraTextField(
                  label: 'Roll Number',
                  hint: 'e.g. 25221A0568',
                  controller: _rollController,
                  focusNode: _rollFocus,
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (val) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                const SizedBox(height: NexoraSpacing.sm),
                const Text(
                  'Your roll number will be normalized to uppercase automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(NexoraColors.textMuted),
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xl),

                // Official Portal Info Note
                Container(
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(NexoraColors.border)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 20,
                        color: Color(NexoraColors.primary),
                      ),
                      SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: Text(
                          'Nexora verifies directly with the official BVC Autonomous Student Portal (bvcecautonomous.com). '
                          'Your portal password is used only for authentication and is never permanently stored.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(NexoraColors.textSecondary),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xxl),

                // Connect BVC Button
                NexoraButton(
                  label: 'Connect BVC',
                  onPressed: _onConnectBvc,
                  isLoading: _isLoading,
                  isEnabled: !_isLoading,
                  width: double.infinity,
                  height: 54,
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  borderRadius: 100,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                // =============================================================
                // Verified Official Student Card
                // =============================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(NexoraSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(NexoraColors.success).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with green verified badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(NexoraColors.success).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(NexoraColors.success),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: NexoraSpacing.sm),
                          const Expanded(
                            child: Text(
                              'BVC STUDENT VERIFIED',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(NexoraColors.success),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NexoraSpacing.md),
                      const Divider(color: Color(NexoraColors.divider)),
                      const SizedBox(height: NexoraSpacing.sm),

                      // Verified Fields from Official Portal
                      _buildProfileRow('Roll Number', _verifiedProfile!['rollNumber'] ?? ''),
                      _buildProfileRow('Student Name', _verifiedProfile!['name'] ?? ''),
                      _buildProfileRow('Branch', _verifiedProfile!['branch'] ?? ''),
                      _buildProfileRow('Course', _verifiedProfile!['course'] ?? 'B.Tech'),
                      if (_verifiedProfile!['semester'] != null)
                        _buildProfileRow('Semester', 'Semester ${_verifiedProfile!['semester']}'),
                      if (_verifiedProfile!['batch'] != null)
                        _buildProfileRow('Batch', _verifiedProfile!['batch'] ?? ''),
                      _buildProfileRow('College', _verifiedProfile!['college'] ?? 'BVC Engineering College'),
                    ],
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xxl),

                // Continue Button
                NexoraButton(
                  label: 'Continue to Terms',
                  onPressed: _onContinueToTerms,
                  width: double.infinity,
                  height: 54,
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  borderRadius: 100,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],

              const SizedBox(height: NexoraSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(NexoraColors.textSecondary),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: NexoraSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(NexoraColors.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
