import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_widgets.dart';

/// Main chat screen
class ChatScreen extends StatefulWidget {
  final String? chatId;

  const ChatScreen({
    Key? key,
    this.chatId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController _messageController;
  final List<ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    
    // Mock messages for now
    _messages.addAll([
      ChatBubble(
        message: 'Hello! How can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ]);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      appBar: AppBar(
        title: Text('Chat'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            // TODO: Open chat history drawer
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // TODO: Start new chat
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show chat options menu
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? NexoraEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Start a conversation',
                      description: 'Ask anything about BVC Engineering College',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: NexoraSpacing.lg,
                        vertical: NexoraSpacing.md,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),

            // Claude-style Chat Input Bar
            Container(
              padding: EdgeInsets.only(
                left: NexoraSpacing.md,
                right: NexoraSpacing.md,
                bottom: NexoraSpacing.md,
                top: NexoraSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Color(NexoraColors.background),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: NexoraSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Color(NexoraColors.border),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Attachment button
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(NexoraColors.textSecondary),
                        size: 22,
                      ),
                      onPressed: () {
                        // Attachment handler
                      },
                    ),

                    // Text Input
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(NexoraColors.text),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask anything about BVC...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(NexoraColors.textMuted),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          isDense: true,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),

                    SizedBox(width: 6),

                    // Claude-style Send Button (Black Circle with Upward Arrow)
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(NexoraColors.primary),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(NexoraColors.surface),
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatBubble bubble) {
    return Padding(
      padding: EdgeInsets.only(bottom: NexoraSpacing.md),
      child: Align(
        alignment: bubble.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubble.isUser
                ? Color(NexoraColors.primary)
                : Color(NexoraColors.surface),
            borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
            border: bubble.isUser
                ? null
                : Border.all(color: Color(NexoraColors.border)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: NexoraSpacing.md,
          ),
          child: Text(
            bubble.message,
            style: TextStyle(
              color: bubble.isUser ? Color(NexoraColors.surface) : Color(NexoraColors.text),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(
        ChatBubble(
          message: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();

      // Simulate AI response
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatBubble(
                message: 'This is a mock AI response. Actual AI integration coming in Phase 6.',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
        }
      });
    });

    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class ChatBubble {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ChatBubble({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });
}
