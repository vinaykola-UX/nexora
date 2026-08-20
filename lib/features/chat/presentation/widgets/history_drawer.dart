import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';

/// History Drawer matching Figma Mobile UI
class HistoryDrawer extends StatefulWidget {
  final Function(String title)? onSelectChat;
  final VoidCallback? onNewChat;

  const HistoryDrawer({
    Key? key,
    this.onSelectChat,
    this.onNewChat,
  }) : super(key: key);

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  final List<String> _pinnedChats = [
    'BVC academic rules & credits',
    'Placement stats 2024',
    'Class timetable 3-1 CSE',
  ];

  final List<String> _recentChats = [
    'Semester exams schedule',
    'BVC bus timings & routes',
    'Fee structure query',
    'Campus recruitment training (CRT)',
    'Library digital resources access',
  ];

  void _showChatActionsModal(BuildContext context, String chatTitle, bool isPinned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(NexoraColors.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
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
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: const Color(NexoraColors.text),
                ),
                title: Text(isPinned ? 'Unpin chat' : 'Pin to top'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (isPinned) {
                      _pinnedChats.remove(chatTitle);
                      _recentChats.insert(0, chatTitle);
                    } else {
                      _recentChats.remove(chatTitle);
                      _pinnedChats.insert(0, chatTitle);
                    }
                  });
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
                  Navigator.pop(context);
                  _showRenameDialog(context, chatTitle);
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
                  Navigator.pop(context);
                  setState(() {
                    _pinnedChats.remove(chatTitle);
                    _recentChats.remove(chatTitle);
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String oldTitle) {
    final controller = TextEditingController(text: oldTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty) {
                setState(() {
                  final pIdx = _pinnedChats.indexOf(oldTitle);
                  if (pIdx != -1) _pinnedChats[pIdx] = newText;
                  final rIdx = _recentChats.indexOf(oldTitle);
                  if (rIdx != -1) _recentChats[rIdx] = newText;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

            // Chat Lists (Pinned & Recent)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: NexoraSpacing.md,
                  vertical: NexoraSpacing.md,
                ),
                children: [
                  // PINNED Section
                  if (_pinnedChats.isNotEmpty) ...[
                    _buildSectionHeader('PINNED'),
                    ..._pinnedChats.map(
                      (title) => _buildChatItem(title, isPinned: true),
                    ),
                    const SizedBox(height: NexoraSpacing.lg),
                  ],

                  // RECENT Section
                  _buildSectionHeader('RECENT'),
                  ..._recentChats.map(
                    (title) => _buildChatItem(title, isPinned: false),
                  ),
                ],
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

  Widget _buildChatItem(String title, {required bool isPinned}) {
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
              ? const Color(NexoraColors.primaryDark)
              : const Color(NexoraColors.textSecondary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(NexoraColors.text),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.more_horiz,
            size: 18,
            color: Color(NexoraColors.textMuted),
          ),
          onPressed: () => _showChatActionsModal(context, title, isPinned),
        ),
        onTap: () {
          Navigator.pop(context);
          widget.onSelectChat?.call(title);
        },
      ),
    );
  }
}
