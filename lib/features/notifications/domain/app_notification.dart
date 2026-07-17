import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String type;
  final String? title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final String status;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.title,
    this.body,
    this.entityType,
    this.entityId,
    required this.status,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null || status == 'read';

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'info',
        title: j['title'] as String?,
        body: j['body'] as String?,
        entityType: j['entity_type'] as String?,
        entityId: j['entity_id'] as String?,
        status: j['status'] as String? ?? 'sent',
        readAt: j['read_at'] == null
            ? null
            : DateTime.tryParse(j['read_at'].toString()),
        createdAt:
            DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [id, status, readAt];
}
