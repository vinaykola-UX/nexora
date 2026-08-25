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
                icon: Icons.chat,
                title: 'Start a conversation',
                description: 'Send your first message to begin',
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(NexoraSpacing.lg),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            // Message input area
            Container(
              decoration: BoxDecoration(
                color: Color(NexoraColors.surface),
                border: Border(
                  top: BorderSide(
                    color: Color(NexoraColors.divider),
                  ),
                ),
              ),
              padding: EdgeInsets.all(NexoraSpacing.lg),
              child: Row(
                children: [
                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(NexoraColors.inputBackground),
                        borderRadius: BorderRadius.circular(NexoraSpacing.radiusMD),
                        border: Border.all(
                          color: Color(NexoraColors.border),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: NexoraSpacing.lg,
                            vertical: NexoraSpacing.md,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  SizedBox(width: NexoraSpacing.md),

                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: Color(NexoraColors.primary),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Color(NexoraColors.surface),
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
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
