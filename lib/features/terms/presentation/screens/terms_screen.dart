import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_sparkle_icon.dart';
import '../../../../app/router/app_router.dart';

/// Terms and Privacy screen matching Figma Mobile UI
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _hasAgreed = true;

  void _onContinue() {
    context.go(RoutePaths.startChat);
  }

  void _showTermsDialog(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(NexoraColors.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(NexoraSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.lg),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(NexoraColors.textSecondary),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),
              NexoraButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(context),
                width: double.infinity,
                height: 50,
                borderRadius: 100,
                backgroundColor: const Color(0xFF171717),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      body: SafeArea(
        child: Padding(
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
                'Welcome to Nexora AI',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Terms of service & privacy',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(NexoraColors.textSecondary),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // Centered Sparkle "N" Mark Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const NexoraSparkleIcon(size: 88, borderRadius: 24),
                ),
              ),
              const SizedBox(height: NexoraSpacing.xxl),

              // Section Heading & Description
              const Text(
                'Start your AI journey',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: NexoraSpacing.sm),
              const Text(
                'Before you start using Nexora, please accept our Terms of Service & Privacy Policy.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // Terms of Service Row Card
              _buildPolicyTile(
                title: 'Terms of Service',
                onTap: () {
                  _showTermsDialog(
                    'Terms of Service',
                    'By using Nexora AI at BVC Engineering College, you agree to abide by academic integrity standards. '
                    'Nexora is designed as an educational assistant and reference tool. '
                    'Do not use this system for unauthorized examination assistance or activities violating college regulations.\n\n'
                    'All queries are processed to ensure safe, college-aligned responses.',
                  );
                },
              ),
              const SizedBox(height: NexoraSpacing.md),

              // Privacy Policy Row Card
              _buildPolicyTile(
                title: 'Privacy Policy',
                onTap: () {
                  _showTermsDialog(
                    'Privacy Policy',
                    'Nexora AI values student and faculty privacy. We collect minimal interaction data solely to improve academic assistance quality.\n\n'
                    'Your personal credentials and roll number are protected. Academic records and chat history are encrypted and retained in accordance with college data governance policies.',
                  );
                },
              ),
              const Spacer(),

              // Agreement Note
              Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(NexoraColors.textMuted),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: NexoraSpacing.md),

              // Black Pill Continue Button
              NexoraButton(
                label: 'Continue',
                onPressed: _onContinue,
                isEnabled: _hasAgreed,
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
              const SizedBox(height: NexoraSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NexoraSpacing.lg,
          vertical: NexoraSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: const Color(NexoraColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(NexoraColors.border).withOpacity(0.8),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(NexoraColors.text),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(NexoraColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
