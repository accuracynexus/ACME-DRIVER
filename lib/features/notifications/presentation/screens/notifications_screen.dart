import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationActionsProvider).markAllRead(),
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Sin notificaciones',
              subtitle: 'Aquí verás las ofertas de pedidos y avisos.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(notification: n);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification.type) {
      case 'order_offer':
        return Icons.delivery_dining;
      case 'conversation_message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: notification.isRead
          ? AppColors.surface
          : AppColors.primary.withOpacity(0.08),
      leading: Icon(_icon,
          color: notification.isRead ? AppColors.textSecondary : AppColors.primary),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.isRead ? FontWeight.w500 : FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            timeago.format(notification.createdAt, locale: 'es'),
            style: const TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
      onTap: () {
        ref.read(notificationActionsProvider).markRead(notification.id);
        if (notification.type == 'order_offer') {
          context.go(AppRoutes.availableOrders);
        }
      },
    );
  }
}
