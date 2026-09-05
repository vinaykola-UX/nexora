import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../models/notification_model.dart';
import '../../../../services/native_notification_service.dart';
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
      backgroundColor: const Color(NexoraColors.background),
      appBar: AppBar(
        backgroundColor: const Color(NexoraColors.background),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(NexoraColors.text), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(NexoraColors.text),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(NexoraColors.textSecondary)),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(NexoraColors.textSecondary)),
            tooltip: 'Notification Options & Tests',
            color: const Color(NexoraColors.surface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) async {
              if (value == 'test_local') {
                await NativeNotificationService.instance.showLocalNotification(
                  title: 'Nexora Native Alert',
                  body: 'This is a genuine native notification in your device status tray!',
                  channelId: NativeNotificationService.channelAcademic,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local native notification sent to device system tray!'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } else if (value == 'test_fcm') {
                final service = ref.read(notificationServiceProvider);
                final res = await service.triggerTestFcmPush(
                  title: 'Nexora Official Push',
                  body: 'Dispatched through Cloudflare Worker & Google FCM v1!',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'FCM test push requested.'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } else if (value == 'sync_fcm') {
                final notifService = ref.read(notificationServiceProvider);
                final ok = await NativeNotificationService.instance.syncDeviceToken(
                  notificationService: notifService,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'FCM Device Token registered successfully' : 'FCM Token sync failed or permission not granted'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test_local',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: Color(NexoraColors.text)),
                    SizedBox(width: 10),
                    Text('Test Native Notification', style: TextStyle(fontSize: 13, color: Color(NexoraColors.text))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test_fcm',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18, color: Color(NexoraColors.text)),
                    SizedBox(width: 10),
                    Text('Test Worker FCM Push', style: TextStyle(fontSize: 13, color: Color(NexoraColors.text))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync_fcm',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: Color(NexoraColors.text)),
                    SizedBox(width: 10),
                    Text('Sync FCM Device Token', style: TextStyle(fontSize: 13, color: Color(NexoraColors.text))),
                  ],
                ),
              ),
            ],
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
                child: CircularProgressIndicator(color: Color(NexoraColors.text)),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(NexoraColors.error), size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load notifications',
                      style: TextStyle(color: const Color(NexoraColors.text).withOpacity(0.8)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(NexoraColors.text),
                        foregroundColor: const Color(NexoraColors.surface),
                      ),
                      onPressed: () => ref.invalidate(notificationListProvider),
                      child: const Text('Retry'),
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
                            color: const Color(NexoraColors.surface),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(NexoraColors.border)),
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: Color(NexoraColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Notifications Yet',
                          style: TextStyle(
                            color: Color(NexoraColors.text),
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are all caught up with your academic updates.',
                          style: TextStyle(
                            color: const Color(NexoraColors.textMuted),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(NexoraColors.text),
                  backgroundColor: const Color(NexoraColors.surface),
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
                color: isSelected ? const Color(NexoraColors.text) : const Color(NexoraColors.surface),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(NexoraColors.text) : const Color(NexoraColors.border),
                ),
              ),
              child: Center(
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? const Color(NexoraColors.surface) : const Color(NexoraColors.textSecondary),
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
          color: item.isRead
              ? const Color(NexoraColors.surface).withOpacity(0.7)
              : const Color(NexoraColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? const Color(NexoraColors.border)
                : const Color(NexoraColors.text).withOpacity(0.2),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: item.isRead
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.2)),
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
                            color: const Color(NexoraColors.text),
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
                            color: Color(NexoraColors.text),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: const Color(NexoraColors.textSecondary),
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
                          color: iconColor.withOpacity(0.08),
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
                        style: const TextStyle(
                          color: Color(NexoraColors.textMuted),
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
        return const Color(0xFF2D8A56); // Muted Green
      case 'EVENT':
        return const Color(0xFF555555); // Dark Gray
      case 'ATTENDANCE':
        return const Color(0xFF8B7300); // Dark Gold
      case 'EXAM':
        return const Color(0xFFC04070); // Muted Rose
      case 'FEE':
        return const Color(0xFF3A7A8A); // Muted Teal
      case 'CIRCULAR':
        return const Color(0xFF3A6EAF); // Muted Blue
      default:
        return const Color(NexoraColors.textSecondary);
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
