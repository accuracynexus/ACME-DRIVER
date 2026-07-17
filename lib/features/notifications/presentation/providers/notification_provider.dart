import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      entityId: json['entity_id'] as String?,
      isRead: json['status'] == 'read' || json['read_at'] != null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final driverId = ref.watch(currentDriverProvider).value?.id;
  if (driverId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('notifications')
      .select()
      .eq('user_id', driverId)
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List).map((e) => AppNotification.fromJson(e)).toList();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;
  NotificationActions(this._ref);

  Future<void> markRead(String id) async {
    final client = _ref.read(supabaseClientProvider);
    await client.from('notifications').update({
      'status': 'read',
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    final driverId = _ref.read(currentDriverProvider).value?.id;
    if (driverId == null) return;
    final client = _ref.read(supabaseClientProvider);
    await client
        .from('notifications')
        .update({
          'status': 'read',
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', driverId)
        .neq('status', 'read');
    _ref.invalidate(notificationsProvider);
  }
}
