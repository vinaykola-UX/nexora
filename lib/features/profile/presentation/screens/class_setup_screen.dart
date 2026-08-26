import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/app/router/app_router.dart';
import 'package:nexora/core/constants/student_identity_helper.dart';
import 'package:nexora/core/theme/colors.dart';
import 'package:nexora/core/theme/spacing.dart';
import 'package:nexora/core/widgets/nexora_button.dart';
import 'package:nexora/features/profile/data/student_profile_repository.dart';

/// One-time Class and Section setup screen.
/// Automatically extracts Roll Number, Batch, and Academic Year from the student email.
/// Asks the student only for Class (Branch) and Section.
class ClassSetupScreen extends StatefulWidget {
  const ClassSetupScreen({Key? key}) : super(key: key);

  @override
  State<ClassSetupScreen> createState() => _ClassSetupScreenState();
}

class _ClassSetupScreenState extends State<ClassSetupScreen> {
  final StudentProfileRepository _repository = StudentProfileRepository();

  StudentIdentity? _identity;
  String? _selectedBranchCode;
  String? _selectedSection;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _extractIdentity();
  }

  void _extractIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final id = StudentIdentityHelper.extractFromEmail(user.email);
      setState(() {
        _identity = id;
        if (id == null) {
          _errorMessage =
              'Could not extract student identity from ${user.email}. Please ensure you are logged in with your @bvcgroup.in email.';
        }
      });
    } else {
      setState(() {
        _errorMessage = 'No authenticated student found. Please sign in again.';
      });
    }
  }

  void _showConfirmationDialog() {
    if (_selectedBranchCode == null || _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select both your Class/Branch and Section.'),
          backgroundColor: const Color(NexoraColors.error),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final branch = kBvcBranches.firstWhere(
      (b) => b.code == _selectedBranchCode,
      orElse: () => BvcBranch(code: _selectedBranchCode!, name: ''),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(NexoraColors.warning), size: 28),
            SizedBox(width: NexoraSpacing.sm),
            Text(
              'Confirm Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure these details are correct?',
              style: TextStyle(
                fontSize: 14,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
            const SizedBox(height: NexoraSpacing.md),
            Container(
              padding: const EdgeInsets.all(NexoraSpacing.md),
              decoration: BoxDecoration(
                color: const Color(NexoraColors.background),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(NexoraColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmRow('Roll Number:', _identity?.rollNumber ?? 'N/A'),
                  const SizedBox(height: 6),
                  _buildConfirmRow('Academic Year:', _identity?.academicYearLabel ?? 'N/A'),
                  const SizedBox(height: 6),
                  _buildConfirmRow('Class / Branch:', '${branch.code} (${branch.name})'),
                  const SizedBox(height: 6),
                  _buildConfirmRow('Section:', _selectedSection!),
                ],
              ),
            ),
            const SizedBox(height: NexoraSpacing.md),
            const Text(
              'You cannot change these details later.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(NexoraColors.error),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: NexoraSpacing.lg,
          vertical: NexoraSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(NexoraColors.textSecondary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _saveProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF171717),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              'Confirm & Continue',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(NexoraColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(NexoraColors.text),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showError('No authenticated user session found.');
      return;
    }

    if (_selectedBranchCode == null || _selectedSection == null) {
      _showError('Please select both Class and Section.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _repository.completeProfileSetup(
        uid: user.uid,
        email: user.email!,
        studentClass: _selectedBranchCode!,
        section: _selectedSection!,
      );

      if (!mounted) return;

      // Navigate to Terms screen (or main chat)
      context.go(RoutePaths.terms);
    } on NexoraProfileException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(NexoraColors.error),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
              const SizedBox(height: NexoraSpacing.lg),

              // Header
              const Text(
                'Student Profile Setup',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Your academic identity is automatically verified from your college email.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // Error State banner if email extraction failed
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(NexoraSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.errorLight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(NexoraColors.error).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(NexoraColors.error), size: 20),
                      const SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 13, color: Color(NexoraColors.error)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: NexoraSpacing.lg),
              ],

              // -- Read-Only Identity Card -----------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(NexoraSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(NexoraColors.border),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Verified Identity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(NexoraColors.text),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(NexoraColors.divider), height: 20),
                    _buildIdentityDetailRow('Roll Number', _identity?.rollNumber ?? '—'),
                    const SizedBox(height: 8),
                    _buildIdentityDetailRow('Batch', '${_identity?.batchCode ?? '—'} Batch'),
                    const SizedBox(height: 8),
                    _buildIdentityDetailRow('Current Year', _identity?.academicYearLabel ?? '—'),
                    const SizedBox(height: 8),
                    _buildIdentityDetailRow('College', _identity?.college ?? 'BVC Engineering College'),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // -- Class / Branch Selection ----------------------------------
              const Text(
                'Select Your Class / Branch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Select your department from the official BVC branch list',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),

              // Branch dropdown selector with clean styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.lg, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedBranchCode != null
                        ? const Color(NexoraColors.primary)
                        : const Color(NexoraColors.border),
                    width: _selectedBranchCode != null ? 1.5 : 1.0,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranchCode,
                    hint: const Text(
                      'Choose Branch (e.g. CSE, CSM, ECE...)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.textMuted),
                      ),
                    ),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(NexoraColors.text)),
                    items: kBvcBranches.map((branch) {
                      return DropdownMenuItem<String>(
                        value: branch.code,
                        child: Text(
                          '${branch.code} — ${branch.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(NexoraColors.text),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedBranchCode = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // -- Section Selection -----------------------------------------
              const Text(
                'Select Your Section',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Choose your assigned classroom section',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),

              // Section Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kBvcSections.map((section) {
                  final isSelected = _selectedSection == section;
                  return ChoiceChip(
                    label: Text(
                      section,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(NexoraColors.text),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF171717),
                    backgroundColor: const Color(NexoraColors.surface),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF171717) : const Color(NexoraColors.border),
                        width: 1,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedSection = selected ? section : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // -- Permanent Warning Card ------------------------------------
              Container(
                padding: const EdgeInsets.all(NexoraSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.errorLight).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(NexoraColors.error).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(NexoraColors.error),
                      size: 20,
                    ),
                    SizedBox(width: NexoraSpacing.sm),
                    Expanded(
                      child: Text(
                        'Please make sure your Class and Section are correct. These details cannot be changed later.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(NexoraColors.error),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxxl),

              // -- Continue Button -------------------------------------------
              NexoraButton(
                label: 'Continue',
                onPressed: _showConfirmationDialog,
                isLoading: _isLoading,
                isEnabled: !_isLoading &&
                    _identity != null &&
                    _selectedBranchCode != null &&
                    _selectedSection != null,
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
              const SizedBox(height: NexoraSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityDetailRow(String label, String value) {
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(NexoraColors.text),
          ),
        ),
      ],
    );
  }
}
