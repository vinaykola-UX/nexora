import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/copy_message_button.dart';
import '../../../../app/router/app_router.dart';
import '../../../../models/search_response_model.dart';
import '../../../../services/nexora_api_service.dart';
import '../../../../services/rag_service.dart';
import '../../data/chat_repository.dart';
import '../widgets/history_drawer.dart';

/// Main chat screen displaying real-time official BVC College retrieval results with persistent history
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
  final NexoraApiService _apiService = NexoraApiService();
  final RagService _ragService = RagService();
  final ChatRepository _chatRepository = ChatRepository();

  late TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  String? _currentConversationId;

  String get _currentUid {
    final user = FirebaseAuth.instance.currentUser;
    return (user != null && user.uid.isNotEmpty) ? user.uid : 'guest_student';
  }

  final List<String> _suggestionChips = [
    'What is a linked list?',
    'What is a doubly linked list?',
    'What is a circular linked list?',
    'Array vs linked list',
    'Applications of linked lists',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _currentConversationId = widget.chatId;

    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      _loadExistingConversation(widget.chatId!);
    } else {
      _showInitialGreeting();
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleSendMessage(widget.initialPrompt!);
        });
      }
    }
  }

  void _showInitialGreeting() {
    _messages.clear();
    _messages.add(
      _ChatMessage(
        text: 'Hello! I am Nexora, your official BVC College & Study Assistant.\nAsk me about Data Structures (Linked Lists, Arrays), examinations, regulations (BR23), syllabus, circulars, fee dates, or college announcements.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _loadExistingConversation(String conversationId) async {
    setState(() {
      _isLoadingHistory = true;
      _currentConversationId = conversationId;
      _messages.clear();
    });

    try {
      final persistedMessages = await _chatRepository.getMessages(_currentUid, conversationId);
      if (!mounted) return;

      if (persistedMessages.isEmpty) {
        _showInitialGreeting();
      } else {
        setState(() {
          _messages.addAll(persistedMessages.map((m) => _ChatMessage(
                text: m.text,
                isUser: m.isUser,
                timestamp: m.timestamp,
                searchResponse: m.searchResponse,
                isError: m.isError,
                retryQuery: m.retryQuery,
              )));
        });
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error loading conversation history: $e');
      if (mounted) _showInitialGreeting();
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _apiService.dispose();
    _ragService.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isTyping) return;

    final uid = _currentUid;

    // Create conversation if it doesn't exist yet
    if (_currentConversationId == null) {
      try {
        _currentConversationId = await _chatRepository.createConversation(
          uid,
          title: query.length > 35 ? '${query.substring(0, 35)}...' : query,
        );
      } catch (e) {
        debugPrint('[ChatScreen] Failed to create conversation: $e');
      }
    }

    final userMsgTime = DateTime.now();

    setState(() {
      _messages.add(
        _ChatMessage(
          text: query,
          isUser: true,
          timestamp: userMsgTime,
        ),
      );
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Persist user message immediately
    if (_currentConversationId != null) {
      await _chatRepository.saveMessage(
        uid,
        _currentConversationId!,
        text: query,
        isUser: true,
      );
    }

    try {
      // ---------------------------------------------------------------
      // Step 1: Send query to user-facing conversational AI endpoint (/chat)
      // Displays clean AI-generated response.answer (never raw chunks)
      // ---------------------------------------------------------------
      final recentHistory = _messages.take(6).map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      }).toList();

      final chatResponse = await _ragService.sendChatMessage(
        query,
        conversation: recentHistory,
      );

      if (!mounted) return;

      if (chatResponse.success && chatResponse.answer.isNotEmpty) {
        String? sourceLabel;
        if (chatResponse.sources.isNotEmpty) {
          final first = chatResponse.sources.first;
          sourceLabel = first.title.isNotEmpty
              ? first.title
              : (first.source ?? 'Official Knowledge Base');
        }

        final aiMsg = _ChatMessage(
          text: chatResponse.answer,
          isUser: false,
          timestamp: DateTime.now(),
          sourceLabel: sourceLabel,
        );

        setState(() {
          _isTyping = false;
          _messages.add(aiMsg);
        });

        // Persist AI chat response
        if (_currentConversationId != null) {
          await _chatRepository.saveMessage(
            uid,
            _currentConversationId!,
            text: chatResponse.answer,
            isUser: false,
          );
        }
      } else {
        // Fallback check against official BVC portal notifications if /chat returned empty
        final portalResponse = await _apiService.searchOfficialSources(query);

        if (!mounted) return;

        String aiText;
        bool isError = false;
        NexoraSearchResponse? parsedResponse;

        if (portalResponse.success && portalResponse.results.isNotEmpty) {
          aiText = 'Found ${portalResponse.results.length} official update${portalResponse.results.length > 1 ? 's' : ''} from BVC College sources for "$query":';
          parsedResponse = portalResponse;
        } else {
          // Task 4 requirement: show exact message when no relevant chunks found
          aiText = "I couldn't find relevant material for that question in the current Nexora knowledge base.";
          parsedResponse = portalResponse.success ? portalResponse : null;
        }

        final aiMsg = _ChatMessage(
          text: aiText,
          isUser: false,
          timestamp: DateTime.now(),
          searchResponse: parsedResponse,
          isError: isError,
          retryQuery: isError ? query : null,
        );

        setState(() {
          _isTyping = false;
          _messages.add(aiMsg);
        });

        if (_currentConversationId != null) {
          await _chatRepository.saveMessage(
            uid,
            _currentConversationId!,
            text: aiText,
            isUser: false,
            searchResponse: parsedResponse,
            isError: isError,
            retryQuery: isError ? query : null,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errorText = 'An unexpected error occurred while connecting to the college knowledge base. Please try again.';
      final aiMsg = _ChatMessage(
        text: errorText,
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
        retryQuery: query,
      );

      setState(() {
        _isTyping = false;
        _messages.add(aiMsg);
      });

      if (_currentConversationId != null) {
        await _chatRepository.saveMessage(
          uid,
          _currentConversationId!,
          text: errorText,
          isUser: false,
          isError: true,
          retryQuery: query,
        );
      }
    }

    _scrollToBottom();
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
      _currentConversationId = null;
      _showInitialGreeting();
    });
  }

  Future<void> _openOfficialUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  String _getCopyableText(_ChatMessage message) {
    final buffer = StringBuffer(message.text);
    if (message.searchResponse != null && message.searchResponse!.results.isNotEmpty) {
      for (final r in message.searchResponse!.results) {
        buffer.writeln('\n\n• ${r.title}');
        if (r.snippet.isNotEmpty) {
          buffer.writeln(r.snippet);
        }
        if (r.url.isNotEmpty) {
          buffer.writeln(r.url);
        }
      }
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(NexoraColors.background),
      drawer: HistoryDrawer(
        onSelectConversation: (convId, title) {
          _loadExistingConversation(convId);
        },
        onNewChat: _startNewChat,
      ),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(NexoraColors.text), size: 26),
          tooltip: 'Chat History',
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
            // Loading indicator for history
            if (_isLoadingHistory)
              const LinearProgressIndicator(
                backgroundColor: Color(NexoraColors.background),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF171717)),
                minHeight: 2,
              ),

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
                  final isFirstAiGreeting = index == 0 && !message.isUser && _messages.length == 1;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageBubble(message),
                      if (isFirstAiGreeting) ...[
                        const SizedBox(height: NexoraSpacing.md),
                        _buildSuggestionChips(),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Bottom Pill Input Bar
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
                          hintText: 'Ask anything about BVC or your subjects...',
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

                    // Send Button
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
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: NexoraSpacing.md),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E), // Dark black pill for user message
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: NexoraSpacing.lg,
              vertical: NexoraSpacing.md,
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    // AI Message
    final hasRagContent = message.sourceLabel != null;
    final results = message.searchResponse?.results ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: NexoraSpacing.lg),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.90,
          ),
          decoration: BoxDecoration(
            color: const Color(NexoraColors.surface),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: message.isError
                  ? const Color(NexoraColors.error).withOpacity(0.4)
                  : const Color(NexoraColors.border).withOpacity(0.8),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(NexoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: message.isError
                          ? const Color(NexoraColors.errorLight)
                          : const Color(NexoraColors.primary).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      message.isError
                          ? Icons.error_outline
                          : hasRagContent
                              ? Icons.school_rounded
                              : Icons.auto_awesome,
                      color: message.isError
                          ? const Color(NexoraColors.error)
                          : const Color(NexoraColors.primary),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: NexoraSpacing.sm),
                  Expanded(
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: (results.isNotEmpty && !hasRagContent) ? FontWeight.w600 : FontWeight.normal,
                        color: message.isError
                            ? const Color(NexoraColors.error)
                            : const Color(NexoraColors.text),
                      ),
                    ),
                  ),
                ],
              ),

              // RAG subtle indicator: "Based on Data Structures • Unit II"
              if (hasRagContent) ...[
                const SizedBox(height: NexoraSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(NexoraColors.primary).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 13,
                        color: Color(NexoraColors.primary),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Based on ${message.sourceLabel}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(NexoraColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Retry Button if error
              if (message.isError && message.retryQuery != null) ...[
                const SizedBox(height: NexoraSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _handleSendMessage(message.retryQuery!),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(NexoraColors.primary),
                    side: const BorderSide(color: Color(NexoraColors.primary)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],

              // Official Search Results List (fallback)
              if (results.isNotEmpty) ...[
                const SizedBox(height: NexoraSpacing.md),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: NexoraSpacing.md),
                  itemBuilder: (context, rIndex) {
                    final item = results[rIndex];
                    return _buildSearchResultCard(item);
                  },
                ),
              ],

              // Sources footer reference
              if (message.searchResponse != null &&
                  message.searchResponse!.sources.isNotEmpty) ...[
                const SizedBox(height: NexoraSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: NexoraSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(NexoraColors.textMuted)),
                    const SizedBox(width: 4),
                    const Text(
                      'Verified Official Sources: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(NexoraColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        message.searchResponse!.sources.map((s) => s.title).join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(NexoraColors.textSecondary),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Message Actions Footer (Copy Button)
              if (!message.isError && message.text.isNotEmpty) ...[
                const SizedBox(height: NexoraSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: CopyMessageButton(
                    text: _getCopyableText(message),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(SearchResultItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(NexoraColors.border),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(NexoraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Official Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.article_outlined,
                size: 18,
                color: Color(NexoraColors.primary),
              ),
              const SizedBox(width: NexoraSpacing.xs),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(NexoraColors.text),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoraSpacing.xs),

          // Snippet
          Text(
            item.snippet,
            style: const TextStyle(
              fontSize: 13,
              color: Color(NexoraColors.textSecondary),
              height: 1.45,
            ),
          ),
          const SizedBox(height: NexoraSpacing.sm),

          // Source and Date / Link Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Source & Date Badge
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(NexoraColors.gray2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.source,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(NexoraColors.text),
                        ),
                      ),
                    ),
                    if (item.publishedDate != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.publishedDate!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(NexoraColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Clickable link button
              if (item.url.isNotEmpty)
                InkWell(
                  onTap: () => _openOfficialUrl(item.url),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Open Page',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(NexoraColors.primary),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: Color(NexoraColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
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
            'Official BVC & Subject Topics',
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
                'Searching Nexora knowledge base...',
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
  final NexoraSearchResponse? searchResponse;
  final bool isError;
  final String? retryQuery;
  final String? sourceLabel;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.searchResponse,
    this.isError = false,
    this.retryQuery,
    this.sourceLabel,
  });
}
