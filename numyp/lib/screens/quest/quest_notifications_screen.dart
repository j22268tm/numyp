import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import 'quest_completion_report_screen.dart';

class QuestNotificationsScreen extends ConsumerWidget {
  const QuestNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final notificationsAsync = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: colors.midnightBackground,
      appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '更新',
            onPressed: () => ref.read(notificationControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '通知の取得に失敗しました\n$error',
            style: TextStyle(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('通知はありません', style: TextStyle(color: colors.textSecondary)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final n = items[index];
              return _NotificationTile(
                notification: n,
                onTap: () async {
                  if (!n.isRead) {
                    await ref.read(notificationControllerProvider.notifier).markRead(n.id);
                  }
                  if (context.mounted && n.questId != null && n.type == NotificationType.questCompleted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuestCompletionReportScreen(questId: n.questId!),
                      ),
                    );
                  }
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isUnread = !notification.isRead;
    return Material(
      color: colors.cardSurface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isUnread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                color: isUnread ? colors.magicGold : colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(color: colors.textSecondary, height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.magicGold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hh:$mm';
  }
}

