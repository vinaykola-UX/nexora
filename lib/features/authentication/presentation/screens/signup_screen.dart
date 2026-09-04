import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_textfield.dart';
import '../../../../app/router/route_paths.dart';
import '../../data/auth_service.dart';

/// Sign-up screen - email/password registration restricted to @bvcgroup.in
class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // Inline error strings - shown without requiring full form submission
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    // Validate email domain as soon as the field loses focus
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _validateEmailField(_emailController.text);
      }
    });
    // Validate confirm-password on blur
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus) {
        _validateConfirmPassword(_confirmPasswordController.text);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  void _validateEmailField(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _emailError = 'Please enter your college email.';
      } else if (!AuthService.isAllowedDomain(value)) {
        _emailError = 'Only @bvcgroup.in email addresses are allowed.';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePasswordField(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Please enter a password.';
      } else if (value.length < 6) {
        _passwordError = 'Password must be at least 6 characters.';
      } else {
        _passwordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match.';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  bool _isFormValid() {
    return _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Sign-up action
  // ---------------------------------------------------------------------------

  Future<void> _onSignUp() async {
    // Run all validations before submitting
    _validateEmailField(_emailController.text);
    _validatePasswordField(_passwordController.text);
    _validateConfirmPassword(_confirmPasswordController.text);

    if (!_isFormValid()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUpWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      // Navigate to verify-email screen, passing email as extra
      context.go(RoutePaths.verifyEmail, extra: user.email ?? _emailController.text.trim());
    } on NexoraAuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('An unexpected error occurred. Please try again.');
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: NexoraSpacing.xl),

                // Header
                const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xs),
                const Text(
                  'Use your BVC college email to sign up',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(NexoraColors.textSecondary),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: NexoraSpacing.xxxl),

                // College Email
                NexoraTextField(
                  label: 'College email',
                  hint: 'you@bvcgroup.in',
                  controller: _emailController,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.email_outlined,
                  errorText: _emailError,
                  onChanged: (val) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                ),
                const SizedBox(height: NexoraSpacing.lg),

                // Password
                NexoraTextField(
                  label: 'Password',
                  hint: 'At least 6 characters',
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: Icons.visibility_outlined,
                  errorText: _passwordError,
                  onChanged: (val) {
                    if (_passwordError != null) _validatePasswordField(val);
                  },
                ),
                const SizedBox(height: NexoraSpacing.lg),

                // Confirm Password
                NexoraTextField(
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  focusNode: _confirmFocus,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: Icons.visibility_outlined,
                  errorText: _confirmPasswordError,
                  onChanged: (val) {
                    if (_confirmPasswordError != null) _validateConfirmPassword(val);
                  },
                ),
                const SizedBox(height: NexoraSpacing.xxxl),

                // Sign Up Button
                NexoraButton(
                  label: 'Create account',
                  onPressed: _onSignUp,
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
                const SizedBox(height: NexoraSpacing.xxl),

                // Footer
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(RoutePaths.login),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: Color(NexoraColors.textSecondary),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: Color(NexoraColors.text),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NexoraSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

