import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../app/router/app_router.dart';
import '../../data/auth_service.dart';

/// Verify-Email screen — shown after sign-up (or login with unverified account).
///
/// Displays the target email, a 60-second cooldown resend button,
/// and a "I have verified — Continue" button that reloads and checks
/// [User.emailVerified] before granting access.
class VerifyEmailScreen extends StatefulWidget {
  /// The email address the verification link was sent to.
  final String email;

  const VerifyEmailScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();

  // Resend cooldown
  static const int _cooldownSeconds = 60;
  int _secondsRemaining = 0;
  Timer? _cooldownTimer;

  // UI state
  bool _isCheckingVerification = false;
  bool _isResending = false;
  String? _notVerifiedError;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Resend logic
  // ---------------------------------------------------------------------------

  Future<void> _onResend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _notVerifiedError = null;
    });

    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      _startCooldown();
      _showSnackBar(
        'Verification email resent. Please check your inbox.',
        isError: false,
      );
    } on NexoraAuthException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnackBar('Failed to resend. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _secondsRemaining = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Verification check
  // ---------------------------------------------------------------------------

  Future<void> _onContinue() async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
      _notVerifiedError = null;
    });

    try {
      // Reload the user to get the latest emailVerified flag from Firebase
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Session expired — send back to login
        if (mounted) context.go(RoutePaths.login);
        return;
      }

      await user.reload();
      // After reload, re-fetch the user instance since reload() mutates in place
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // Verified — proceed to Terms screen
        context.go(RoutePaths.terms);
      } else {
        setState(() {
          _notVerifiedError =
              'Email not verified yet. Check your inbox and click the link, then try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notVerifiedError = 'Could not check verification status. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out / back to login
  // ---------------------------------------------------------------------------

  Future<void> _onSignOut() async {
    try {
      await _authService.signOut();
    } catch (_) {}
    if (mounted) context.go(RoutePaths.login);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(NexoraColors.error)
            : const Color(NexoraColors.success),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String get _resendLabel {
    if (_secondsRemaining > 0) return 'Resend in ${_secondsRemaining}s';
    return 'Resend verification email';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool resendDisabled = _secondsRemaining > 0 || _isResending;

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

              // -- Icon ------------------------------------------------------
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.surface),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(NexoraColors.border),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(NexoraColors.gray5).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 40,
                    color: Color(NexoraColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxxl),

              // -- Heading ---------------------------------------------------
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.sm),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(NexoraColors.textSecondary),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'We sent a verification link to\n',
                    ),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Color(NexoraColors.text),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '\nPlease verify before continuing.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // -- Info card -------------------------------------------------
              Container(
                padding: const EdgeInsets.all(NexoraSpacing.lg),
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.infoLight),
                  borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
                  border: Border.all(
                    color: const Color(NexoraColors.info).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(NexoraColors.info),
                    ),
                    SizedBox(width: NexoraSpacing.sm),
                    Expanded(
                      child: Text(
                        "Didn't receive it? Check your spam folder. If you still don't see it, tap 'Resend' below.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(NexoraColors.text),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxxl),

              // -- "I've verified" — primary CTA -----------------------------
              NexoraButton(
                label: "I've verified — Continue",
                onPressed: _onContinue,
                isLoading: _isCheckingVerification,
                isEnabled: !_isCheckingVerification,
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

              // -- Not-verified inline error ---------------------------------
              if (_notVerifiedError != null) ...[
                const SizedBox(height: NexoraSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexoraSpacing.lg,
                    vertical: NexoraSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.errorLight),
                    borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
                    border: Border.all(
                      color: const Color(NexoraColors.error).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Color(NexoraColors.error),
                      ),
                      const SizedBox(width: NexoraSpacing.sm),
                      Expanded(
                        child: Text(
                          _notVerifiedError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(NexoraColors.error),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: NexoraSpacing.lg),

              // -- Resend — secondary button ---------------------------------
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: resendDisabled ? null : _onResend,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: resendDisabled
                          ? const Color(NexoraColors.border)
                          : const Color(NexoraColors.text),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    backgroundColor: const Color(NexoraColors.surface),
                    disabledForegroundColor: const Color(NexoraColors.textMuted),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(NexoraColors.text),
                            ),
                          ),
                        )
                      : Text(
                          _resendLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: resendDisabled
                                ? const Color(NexoraColors.textMuted)
                                : const Color(NexoraColors.text),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxxl),

              // -- Sign out link ---------------------------------------------
              Center(
                child: GestureDetector(
                  onTap: _onSignOut,
                  child: const Text(
                    'Use a different account',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(NexoraColors.textSecondary),
                      decoration: TextDecoration.underline,
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
