import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../app/router/app_router.dart';
import '../widgets/history_drawer.dart';

/// Main chat screen matching Figma Mobile UI
class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? initialPrompt;

  const ChatScreen({
    Key? key,
    this.chatId,
    this.initialPrompt,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  final List<String> _suggestionChips = [
    'Academic regulations 2023',
    'Placement preparation guide',
    'Semester exam schedule',
    'Library timing & book borrowing rules',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    // Initial greeting from Nexora AI
    _messages.add(
      _ChatMessage(
        text: 'Hello! How can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    // If an initial prompt was passed from StartChatScreen
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage(String text) {
    final query = text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: query,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate College AI response
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        String responseText;
        if (query.toLowerCase().contains('regulation') || query.toLowerCase().contains('attendance')) {
          responseText =
              'At BVC Engineering College, students are required to maintain a minimum of 75% attendance in each semester to be eligible for university end-examinations. Condonation is permitted between 65% and 75% upon genuine medical grounds with principal approval.';
        } else if (query.toLowerCase().contains('placement') || query.toLowerCase().contains('recruit')) {
          responseText =
              'BVC placement cell conducts CRT training starting in the 3rd year. Major recruiters include TCS, Infosys, Wipro, Cognizant, and Tech Mahindra, with packages up to 8.5 LPA.';
        } else if (query.toLowerCase().contains('library') || query.toLowerCase().contains('timing')) {
          responseText =
              'The Central Library is open on all working days from 8:30 AM to 6:00 PM. Digital library facilities with DELNET and IEEE access are available on the 2nd floor.';
        } else {
          responseText =
              'Here is the information from BVC College knowledge base regarding "$query". You can ask follow-up questions or request specific department guidelines.';
        }

        setState(() {
          _isTyping = false;
          _messages.add(
            _ChatMessage(
              text: responseText,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        _ChatMessage(
          text: 'Hello! How can I help you today?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(NexoraColors.background),
      drawer: HistoryDrawer(
        onSelectChat: (title) {
          _handleSendMessage(title);
        },
        onNewChat: _startNewChat,
      ),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(NexoraColors.text), size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Nexora AI',
          style: TextStyle(
            color: Color(NexoraColors.text),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Color(NexoraColors.text), size: 26),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(NexoraColors.text)),
            tooltip: 'Profile',
            onPressed: () => context.push(RoutePaths.profile),
          ),
          const SizedBox(width: NexoraSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: NexoraSpacing.lg,
                  vertical: NexoraSpacing.md,
                ),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final message = _messages[index];
                  final isFirstAiGreeting = index == 0 && !message.isUser;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageBubble(message),
                      if (isFirstAiGreeting && _messages.length == 1) ...[
                        const SizedBox(height: NexoraSpacing.md),
                        _buildSuggestionChips(),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Bottom Pill Input Bar matching Figma
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NexoraSpacing.lg,
                vertical: NexoraSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: Color(NexoraColors.background),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(NexoraColors.surface),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(NexoraColors.border),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: NexoraSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(NexoraColors.text),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask anything about BVC...',
                          hintStyle: TextStyle(
                            color: Color(NexoraColors.textMuted),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (val) => _handleSendMessage(val),
                      ),
                    ),

                    // Black Circular Send Button
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF171717),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _handleSendMessage(_messageController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoraSpacing.md),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          decoration: BoxDecoration(
            color: message.isUser
                ? const Color(0xFF1E1E1E) // Dark black pill for user message
                : const Color(NexoraColors.surface), // Clean white surface for AI
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isUser ? 18 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 18),
            ),
            border: message.isUser
                ? null
                : Border.all(
                    color: const Color(NexoraColors.border).withOpacity(0.8),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(message.isUser ? 0.06 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.lg,
            vertical: NexoraSpacing.md,
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: message.isUser
                  ? Colors.white
                  : const Color(NexoraColors.text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: NexoraSpacing.xs),
          child: Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(NexoraColors.textMuted),
            ),
          ),
        ),
        Wrap(
          spacing: NexoraSpacing.sm,
          runSpacing: NexoraSpacing.sm,
          children: _suggestionChips.map((prompt) {
            return ActionChip(
              label: Text(
                prompt,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(NexoraColors.text),
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: const Color(NexoraColors.surface),
              side: BorderSide(
                color: const Color(NexoraColors.border).withOpacity(0.8),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              onPressed: () => _handleSendMessage(prompt),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoraSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(NexoraColors.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(NexoraColors.border).withOpacity(0.8),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(NexoraColors.primary)),
                ),
              ),
              SizedBox(width: NexoraSpacing.sm),
              Text(
                'Nexora is typing...',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
