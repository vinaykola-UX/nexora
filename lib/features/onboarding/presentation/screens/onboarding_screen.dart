import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';

/// Onboarding screens
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Nexora AI',
      description: 'Your personal college-aware AI assistant',
      icon: Icons.school,
    ),
    OnboardingPage(
      title: 'Instant Assistance',
      description: 'Get answers to your college-related questions',
      icon: Icons.lightbulb,
    ),
    OnboardingPage(
      title: 'Always Learning',
      description: 'Powered by your college knowledge base',
      icon: Icons.menu_book,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(NexoraSpacing.lg),
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to next step
                  },
                  child: Text('Skip'),
                ),
              ),
            ),

            // Page viewer
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Indicators & Navigation
            Padding(
              padding: EdgeInsets.all(NexoraSpacing.lg),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: NexoraSpacing.sm),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Color(NexoraColors.primary)
                              : Color(NexoraColors.border),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: NexoraSpacing.xl),

                  // CTA Button
                  NexoraButton(
                    label: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        // Navigate to login
                      } else {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
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

  Widget _buildPage(OnboardingPage page) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NexoraSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              page.icon,
              size: 100,
              color: Color(NexoraColors.primary),
            ),
            SizedBox(height: NexoraSpacing.xl),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            SizedBox(height: NexoraSpacing.md),
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}
