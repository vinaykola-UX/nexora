import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_textfield.dart';
import '../../../profile/data/student_profile_repository.dart';
import '../../../../core/constants/student_identity_helper.dart';
import '../../../../services/nexora_api_service.dart';
import '../../data/auth_service.dart';

/// Login screen - supports both email/password and Google Sign-In.
///
/// Google Sign-In code is left fully intact; email/password is the primary flow.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers & focus nodes
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();

  final AuthService _authService = AuthService();
  final StudentProfileRepository _profileRepository = StudentProfileRepository();

  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus && _emailController.text.trim().isNotEmpty) {
        _validateEmailField(_emailController.text);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateEmailField(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _emailError = 'Please enter your email.';
      } else if (!AuthService.isAllowedDomain(value)) {
        _emailError = 'Only @bvcgroup.in email addresses are allowed.';
      } else {
        _emailError = null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Email / Password Sign-In
  // ---------------------------------------------------------------------------

  Future<void> _onEmailSignIn() async {
    _validateEmailField(_emailController.text);

    if (_emailError != null) return;
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    if (_isEmailLoading) return;

    setState(() => _isEmailLoading = true);

    try {
      final user = await _authService.signInWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      final isDemoFaculty = user.email?.trim().toLowerCase() == 'vinaybvcec@bvcgroup.in';
      if (!user.emailVerified && !isDemoFaculty) {
        // Redirect to verify-email screen - do NOT grant access yet
        context.go(RoutePaths.verifyEmail, extra: user.email ?? '');
        return;
      }

      // Check if user is a faculty/staff member (e.g. vinaybvcec@bvcgroup.in)
      if (StudentIdentityHelper.isFacultyEmail(user.email)) {
        try {
          // Verify with official BVC Odalarevu website & establish faculty profile
          final api = NexoraApiService();
          await api.verifyFacultyOfficial(user.email!);
          await _profileRepository.setupFacultyProfile(
            uid: user.uid,
            email: user.email!,
            fullName: user.displayName,
          );
        } catch (_) {}

        if (!mounted) return;
        context.go(RoutePaths.terms);
        return;
      }

      // Check whether one-time profile setup was completed for student
      final isComplete = await _profileRepository.isProfileComplete(user.uid);
      if (!mounted) return;

      if (isComplete) {
        context.go(RoutePaths.terms);
      } else {
        context.go(RoutePaths.classSetup);
      }
    } on NexoraAuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Forgot Password
  // ---------------------------------------------------------------------------

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above, then tap "Forgot password?"');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: const Color(NexoraColors.success),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on NexoraAuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Failed to send reset email. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In (unchanged logic - left in place per spec)
  // ---------------------------------------------------------------------------

  Future<void> _onGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        if (StudentIdentityHelper.isFacultyEmail(user.email)) {
          try {
            final api = NexoraApiService();
            await api.verifyFacultyOfficial(user.email!);
            await _profileRepository.setupFacultyProfile(
              uid: user.uid,
              email: user.email!,
              fullName: user.displayName,
            );
          } catch (_) {}

          if (!mounted) return;
          context.go(RoutePaths.terms);
          return;
        }

        final isComplete = await _profileRepository.isProfileComplete(user.uid);
        if (!mounted) return;

        if (isComplete) {
          context.go(RoutePaths.terms);
        } else {
          context.go(RoutePaths.classSetup);
        }
      }
      // If user is null, user cancelled Google Sign-In dialog
    } on NexoraAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(NexoraColors.error),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An error occurred during sign in. Please try again.'),
            backgroundColor: const Color(NexoraColors.error),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NexoraSpacing.xl),

              // -- Headline & Subtitle --------------------------------------
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Login with your college account',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(NexoraColors.textSecondary),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxxl),

              // -- Email field ----------------------------------------------
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
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: NexoraSpacing.lg),

              // -- Password field -------------------------------------------
              NexoraTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline,
                suffixIcon: Icons.visibility_outlined,
              ),
              const SizedBox(height: NexoraSpacing.sm),

              // -- Forgot password link -------------------------------------
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _onForgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(NexoraColors.textSecondary),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // -- Sign In Button -------------------------------------------
              NexoraButton(
                label: 'Sign in',
                onPressed: _onEmailSignIn,
                isLoading: _isEmailLoading,
                isEnabled: !_isEmailLoading && !_isGoogleLoading,
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

              // -- Divider ---------------------------------------------------
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(NexoraColors.divider))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.md),
                    child: Text(
                      'or',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(NexoraColors.textMuted),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(NexoraColors.divider))),
                ],
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // -- Login with Google Pill Button (unchanged) -----------------
              NexoraOutlineButton(
                label: 'Login with Google',
                onPressed: _onGoogleLogin,
                isLoading: _isGoogleLoading,
                isEnabled: !_isGoogleLoading && !_isEmailLoading,
                width: double.infinity,
                height: 54,
                borderRadius: 100,
                backgroundColor: const Color(NexoraColors.surface),
                borderColor: const Color(NexoraColors.border),
                textColor: const Color(NexoraColors.text),
                leadingIcon: Icons.g_mobiledata_rounded,
              ),
              const SizedBox(height: NexoraSpacing.md),

              // -- Quick Demo Faculty Auto-fill Button -----------------------
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _emailController.text = 'vinaybvcec@bvcgroup.in';
                      _passwordController.text = 'thala777';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Faculty credentials filled: vinaybvcec@bvcgroup.in'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.school_outlined, size: 16, color: Color(NexoraColors.primaryDark)),
                  label: const Text(
                    'Quick Test: Faculty (vinaybvcec • thala777)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(NexoraColors.primaryDark),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // -- Footer: Sign up link -------------------------------------
              Center(
                child: GestureDetector(
                  onTap: () => context.go(RoutePaths.signup),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(
                        color: Color(NexoraColors.textSecondary),
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign up',
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
    );
  }
}






