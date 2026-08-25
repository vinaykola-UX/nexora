import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';

/// Terms & Privacy screen
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;

  bool get _canProceed => _agreeToTerms && _agreeToPrivacy;

  void _continue() {
    if (!_canProceed) return;

    // TODO: Navigate to the next step.
    // Add navigation here when the next screen is ready.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(NexoraSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms of Service & Privacy Policy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    SizedBox(height: NexoraSpacing.lg),

                    Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    SizedBox(height: NexoraSpacing.md),

                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
                      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
                      'nisi ut aliquip ex ea commodo consequat.\n\n'
                      'Duis aute irure dolor in reprehenderit in voluptate velit esse '
                      'cillum dolore eu fugiat nulla pariatur.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.textSecondary),
                        height: 1.6,
                      ),
                    ),

                    SizedBox(height: NexoraSpacing.xl),

                    Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    SizedBox(height: NexoraSpacing.md),

                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
                      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
                      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
                      'nisi ut aliquip ex ea commodo consequat.\n\n'
                      'Duis aute irure dolor in reprehenderit in voluptate velit esse '
                      'cillum dolore eu fugiat nulla pariatur.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.textSecondary),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(NexoraSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
                    title: Text(
                      'I agree to the Terms of Service',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),

                  SizedBox(height: NexoraSpacing.md),

                  CheckboxListTile(
                    value: _agreeToPrivacy,
                    onChanged: (value) {
                      setState(() {
                        _agreeToPrivacy = value ?? false;
                      });
                    },
                    title: Text(
                      'I agree to the Privacy Policy',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(NexoraColors.text),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),

                  SizedBox(height: NexoraSpacing.xl),

                  NexoraButton(
                    label: 'Continue',
                    onPressed: _continue,
                    isEnabled: _canProceed,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
