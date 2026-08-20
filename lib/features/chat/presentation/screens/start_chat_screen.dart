import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_sparkle_icon.dart';
import '../../../../app/router/app_router.dart';

/// Start Chat screen matching Figma Mobile UI ("How can I help you today?")
class StartChatScreen extends StatelessWidget {
  const StartChatScreen({Key? key}) : super(key: key);

  void _navigateToChat(BuildContext context, [String? initialPrompt]) {
    if (initialPrompt != null) {
      context.go(RoutePaths.chat, extra: initialPrompt);
    } else {
      context.go(RoutePaths.chat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = [
      {
        'title': 'Academic Regulations',
        'subtitle': 'JNTUK / Autonomous syllabus & attendance criteria',
        'icon': Icons.menu_book_outlined,
        'prompt': 'Tell me about BVC academic regulations and attendance rules',
      },
      {
        'title': 'Placement & Training',
        'subtitle': 'Recent drives, top recruiters & eligibility criteria',
        'icon': Icons.business_center_outlined,
        'prompt': 'What are the upcoming placement drives and training schedules?',
      },
      {
        'title': 'Syllabus & Materials',
        'subtitle': 'Previous question papers and department notes',
        'icon': Icons.school_outlined,
        'prompt': 'Where can I find BVC B.Tech syllabus and department materials?',
      },
      {
        'title': 'College Life & Timetable',
        'subtitle': 'Bus routes, library timings, events & contacts',
        'icon': Icons.directions_bus_outlined,
        'prompt': 'What are the college bus routes and library timings?',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Nexora AI',
          style: TextStyle(
            color: Color(NexoraColors.text),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(NexoraColors.text)),
            onPressed: () => context.push(RoutePaths.profile),
          ),
          const SizedBox(width: NexoraSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NexoraSpacing.md),

              // Sparkle icon badge
              Row(
                children: const [
                  NexoraSparkleIcon(size: 44, borderRadius: 12),
                  SizedBox(width: NexoraSpacing.md),
                  Text(
                    'Powered by BVC Knowledge',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(NexoraColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NexoraSpacing.lg),

              // Headline & Subtitle
              const Text(
                'How can I help you today?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xs),
              const Text(
                'Ask anything about courses, regulations, syllabus, placements, faculty, and college life.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: NexoraSpacing.xl),

              // Topic suggestions list
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: topics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: NexoraSpacing.md),
                  itemBuilder: (context, index) {
                    final item = topics[index];
                    return GestureDetector(
                      onTap: () => _navigateToChat(context, item['prompt'] as String),
                      child: Container(
                        padding: const EdgeInsets.all(NexoraSpacing.lg),
                        decoration: BoxDecoration(
                          color: const Color(NexoraColors.surface),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(NexoraColors.border).withOpacity(0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(NexoraColors.gray2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: const Color(0xFF171717),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: NexoraSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(NexoraColors.text),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['subtitle'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(NexoraColors.textMuted),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Color(NexoraColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Button: "Start Chat" Black Pill Button
              Padding(
                padding: const EdgeInsets.only(top: NexoraSpacing.md, bottom: NexoraSpacing.sm),
                child: NexoraButton(
                  label: 'Start Chat',
                  onPressed: () => _navigateToChat(context),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
