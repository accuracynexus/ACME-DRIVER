import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/app_notification.dart';

class NotificationDataSource {
  final SupabaseClient _client;
  NotificationDataSource(this._client);

  Future<List<AppNotification>> getNotifications(String userId) async {
    final data = await _client
        .from(AppConstants.notificationsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _client.from(AppConstants.notificationsTable).update({
      'status': 'read',
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}
