import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notification_datasource.dart';
import '../../domain/app_notification.dart';

final notificationDataSourceProvider = Provider<NotificationDataSource>((ref) {
  return NotificationDataSource(ref.watch(supabaseClientProvider));
});

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final id = ref.watch(currentDriverProvider).value?.userId ?? '';
  if (id.isEmpty) return [];
  return ref.watch(notificationDataSourceProvider).getNotifications(id);
});

final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).value ?? [];
  return notifs.where((n) => !n.isRead).length;
});
