import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../data/chat_repository.dart';

/// History Drawer displaying genuine persistent user conversations from Firestore & local storage
class HistoryDrawer extends StatefulWidget {
  final Function(String conversationId, String title)? onSelectConversation;
  final VoidCallback? onNewChat;

  const HistoryDrawer({
    Key? key,
    this.onSelectConversation,
    this.onNewChat,
  }) : super(key: key);

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  final ChatRepository _chatRepository = ChatRepository();

  String get _currentUid {
    final user = FirebaseAuth.instance.currentUser;
    return (user != null && user.uid.isNotEmpty) ? user.uid : 'guest_student';
  }

  void _showChatActionsModal(
    BuildContext context,
    ChatConversation conversation,
    String uid,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(NexoraColors.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NexoraSpacing.xl,
            vertical: NexoraSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              // Modal Title & Subtitle per Figma
              const Text(
                'Chat history actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Manage your saved conversations',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              const SizedBox(height: NexoraSpacing.lg),

              // Pin / Unpin
              ListTile(
                leading: Icon(
                  conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: const Color(NexoraColors.text),
                ),
                title: Text(conversation.isPinned ? 'Unpin chat' : 'Pin to top'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  await _chatRepository.togglePinConversation(
                    uid,
                    conversation.id,
                    !conversation.isPinned,
                  );
                },
                contentPadding: EdgeInsets.zero,
              ),

              // Rename
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Color(NexoraColors.text),
                ),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _showRenameDialog(context, conversation, uid);
                },
                contentPadding: EdgeInsets.zero,
              ),

              // Delete
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(NexoraColors.error),
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Color(NexoraColors.error)),
                ),
                onTap: () {
                  Navigator.pop(modalContext);
                  _showDeleteConfirmDialog(context, conversation, uid);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    ChatConversation conversation,
    String uid,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Chat?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(NexoraColors.text),
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${conversation.title}"? This cannot be undone.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(NexoraColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(NexoraColors.textSecondary)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _chatRepository.deleteConversation(uid, conversation.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Conversation deleted'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete conversation: $e'),
                      backgroundColor: const Color(NexoraColors.error),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(NexoraColors.error),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ChatConversation conversation,
    String uid,
  ) {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(NexoraColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new chat title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                await _chatRepository.renameConversation(uid, conversation.id, newText);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;

    return Drawer(
      backgroundColor: const Color(NexoraColors.background),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header: "History"
            Padding(
              padding: const EdgeInsets.all(NexoraSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(NexoraColors.text),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(NexoraColors.text)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(NexoraColors.divider), height: 1),

            // Persistent Chat List Stream
            Expanded(
              child: StreamBuilder<List<ChatConversation>>(
                stream: _chatRepository.streamConversations(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF171717),
                          ),
                        ),
                      ),
                    );
                  }

                  final conversations = snapshot.data ?? [];
                  if (conversations.isEmpty) {
                    return _buildEmptyState(
                      'No conversations yet.\nAsk a question to start saving your chat history.',
                    );
                  }

                  final pinned = conversations.where((c) => c.isPinned).toList();
                  final recent = conversations.where((c) => !c.isPinned).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NexoraSpacing.md,
                      vertical: NexoraSpacing.md,
                    ),
                    children: [
                      // PINNED Section
                      if (pinned.isNotEmpty) ...[
                        _buildSectionHeader('PINNED'),
                        ...pinned.map(
                          (conv) => _buildChatItem(conv, uid, isPinned: true),
                        ),
                        const SizedBox(height: NexoraSpacing.lg),
                      ],

                      // RECENT Section
                      if (recent.isNotEmpty) ...[
                        _buildSectionHeader('RECENT'),
                        ...recent.map(
                          (conv) => _buildChatItem(conv, uid, isPinned: false),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Bottom Docked "+ New Chat" Button
            Container(
              padding: const EdgeInsets.all(NexoraSpacing.lg),
              decoration: const BoxDecoration(
                color: Color(NexoraColors.surface),
                border: Border(
                  top: BorderSide(color: Color(NexoraColors.divider)),
                ),
              ),
              child: NexoraButton(
                label: 'New Chat',
                leadingIcon: Icons.add,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNewChat?.call();
                },
                width: double.infinity,
                height: 50,
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                borderRadius: 100,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NexoraSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: Color(NexoraColors.textMuted),
            ),
            const SizedBox(height: NexoraSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(NexoraColors.textSecondary),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NexoraSpacing.sm,
        vertical: NexoraSpacing.sm,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Color(NexoraColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildChatItem(
    ChatConversation conversation,
    String uid, {
    required bool isPinned,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: NexoraSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(NexoraColors.border).withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NexoraSpacing.md,
          vertical: 2,
        ),
        leading: Icon(
          isPinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded,
          size: 18,
          color: isPinned
              ? const Color(0xFF171717)
              : const Color(NexoraColors.textSecondary),
        ),
        title: Text(
          conversation.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(NexoraColors.text),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: conversation.lastMessage != null
            ? Text(
                conversation.lastMessage!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(NexoraColors.textMuted),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: IconButton(
          icon: const Icon(
            Icons.more_horiz,
            size: 18,
            color: Color(NexoraColors.textMuted),
          ),
          onPressed: () => _showChatActionsModal(context, conversation, uid),
        ),
        onTap: () {
          Navigator.pop(context);
          widget.onSelectConversation?.call(conversation.id, conversation.title);
        },
      ),
    );
  }
}
