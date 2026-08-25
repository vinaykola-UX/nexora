import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../app/router/app_router.dart';
import '../../data/auth_service.dart';

/// Login screen — Google-only authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;
  final AuthService _authService = AuthService();

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

              // Login with Google Pill Button
              NexoraOutlineButton(
                label: 'Login with Google',
                onPressed: _onGoogleLogin,
                isLoading: _isGoogleLoading,
                isEnabled: !_isGoogleLoading,
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
