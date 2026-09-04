import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../models/notification_model.dart';
import '../../../../services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF818CF8)),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final service = ref.read(notificationServiceProvider);
              await service.markAllAsRead();
              ref.invalidate(notificationListProvider);
              ref.invalidate(unreadNotificationCountProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(),

          // Notification List
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF818CF8)),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load notifications',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      onPressed: () => ref.invalidate(notificationListProvider),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              data: (notifs) {
                final filtered = _filterNotifications(notifs);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Notifications Yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are all caught up with your academic updates.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF818CF8),
                  backgroundColor: const Color(0xFF1E293B),
                  onRefresh: () async {
                    ref.invalidate(notificationListProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildNotificationCard(item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'ALL', 'label': 'All'},
      {'key': 'RESULT', 'label': 'Results'},
      {'key': 'EVENT', 'label': 'Events'},
      {'key': 'CIRCULAR', 'label': 'Circulars'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedFilter == f['key'];

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Center(
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<NotificationModel> _filterNotifications(List<NotificationModel> list) {
    if (_selectedFilter == 'ALL') return list;
    return list.where((n) => n.type == _selectedFilter).toList();
  }

  Widget _buildNotificationCard(NotificationModel item) {
    final iconData = _getNotificationIcon(item.type);
    final iconColor = _getNotificationColor(item.type);

    return InkWell(
      onTap: () async {
        if (!item.isRead) {
          final service = ref.read(notificationServiceProvider);
          await service.markAsRead(item.id);
          ref.invalidate(notificationListProvider);
          ref.invalidate(unreadNotificationCountProvider);
        }

        // Navigate safely to deep link target
        if (mounted) {
          if (item.route == '/results' || item.type == 'RESULT') {
            context.push('/results');
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFF818CF8).withOpacity(0.4),
            width: item.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.3)),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF818CF8),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.type,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(item.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'RESULT':
        return Icons.school_rounded;
      case 'EVENT':
        return Icons.event_available_rounded;
      case 'ATTENDANCE':
        return Icons.fact_check_rounded;
      case 'EXAM':
        return Icons.assignment_rounded;
      case 'FEE':
        return Icons.payments_rounded;
      case 'CIRCULAR':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'RESULT':
        return const Color(0xFF10B981); // Emerald Green
      case 'EVENT':
        return const Color(0xFF818CF8); // Indigo / Purple
      case 'ATTENDANCE':
        return const Color(0xFFF59E0B); // Amber
      case 'EXAM':
        return const Color(0xFFEC4899); // Pink
      case 'FEE':
        return const Color(0xFF06B6D4); // Cyan
      case 'CIRCULAR':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF818CF8);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
