import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';

/// Start Chat screen - topic selection
class StartChatScreen extends StatelessWidget {
  const StartChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final topics = [
      ChatTopic(
        title: 'Academic Regulations',
        icon: Icons.book,
        description: 'Learn about college rules and regulations',
      ),
      ChatTopic(
        title: 'Placement Information',
        icon: Icons.business,
        description: 'Get placement opportunities and details',
      ),
      ChatTopic(
        title: 'Study Material',
        icon: Icons.school,
        description: 'Find study resources and materials',
      ),
      ChatTopic(
        title: 'General Query',
        icon: Icons.help,
        description: 'Ask any question about the college',
      ),
    ];

    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      appBar: AppBar(
        title: Text('Start New Chat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(NexoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to know?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              SizedBox(height: NexoraSpacing.md),
              Text(
                'Select a topic or ask anything',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Topics grid
              GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: NexoraSpacing.lg,
                  crossAxisSpacing: NexoraSpacing.lg,
                  childAspectRatio: 0.9,
                ),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  return _TopicCard(
                    topic: topics[index],
                    onTap: () {
                      // TODO: Start chat with topic
                    },
                  );
                },
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Start from scratch button
              NexoraOutlineButton(
                label: 'Start from scratch',
                onPressed: () {
                  // TODO: Navigate to chat with no topic
                },
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatTopic {
  final String title;
  final IconData icon;
  final String description;

  ChatTopic({
    required this.title,
    required this.icon,
    required this.description,
  });
}

class _TopicCard extends StatelessWidget {
  final ChatTopic topic;
  final VoidCallback onTap;

  const _TopicCard({
    Key? key,
    required this.topic,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(NexoraColors.surface),
          borderRadius: BorderRadius.circular(NexoraSpacing.radiusLG),
          border: Border.all(
            color: Color(NexoraColors.border),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              topic.icon,
              size: 48,
              color: Color(NexoraColors.primary),
            ),
            SizedBox(height: NexoraSpacing.md),
            Text(
              topic.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            SizedBox(height: NexoraSpacing.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: NexoraSpacing.md),
              child: Text(
                topic.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(NexoraColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
