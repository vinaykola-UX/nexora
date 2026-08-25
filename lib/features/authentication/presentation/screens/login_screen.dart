import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_textfield.dart';
import '../../../../app/router/app_router.dart';
import '../../data/auth_service.dart';

/// Login screen matching Figma Mobile UI
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    setState(() {
      _isLoading = true;
    });

    // Simulate login & navigate to terms
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        context.go(RoutePaths.terms);
      }
    });
  }

  Future<void> _onGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // Successful login with valid @bvcgroup.in domain
        context.go(RoutePaths.terms);
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

              // Headline & Subtitle
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

              // Email / Roll Number field
              NexoraTextField(
                label: 'Email / Roll Number',
                hint: 'Enter your college email or roll number',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.alternate_email,
              ),
              const SizedBox(height: NexoraSpacing.lg),

              // Password field
              NexoraTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outline,
                suffixIcon: _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixIconTap: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: NexoraSpacing.sm),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset link sent to your email'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Color(0xFFD32F2F), // Reddish accent per Figma
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // Primary Login Action - Black Pill Button
              NexoraButton(
                label: 'LOG IN',
                onPressed: _onLogin,
                isLoading: _isLoading,
                width: double.infinity,
                height: 54,
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                borderRadius: 100,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // "OR" Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: const Color(NexoraColors.divider),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: NexoraSpacing.md),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(NexoraColors.textMuted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: const Color(NexoraColors.divider),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // Login with Google Pill Button
              NexoraOutlineButton(
                label: 'Login with Google',
                onPressed: _onGoogleLogin,
                isLoading: _isGoogleLoading,
                isEnabled: !_isGoogleLoading && !_isLoading,
                width: double.infinity,
                height: 54,
                borderRadius: 100,
                backgroundColor: const Color(NexoraColors.surface),
                borderColor: const Color(NexoraColors.border),
                textColor: const Color(NexoraColors.text),
                leadingIcon: Icons.g_mobiledata_rounded,
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // Footer: Sign up link
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Navigate to sign up or show message
                  },
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
