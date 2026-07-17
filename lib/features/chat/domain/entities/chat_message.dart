import 'package:equatable/equatable.dart';

/// Un mensaje del chat de un pedido (tabla `messages`).
class ChatMessage extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final String messageType; // text / image / file / location / system
  final bool isSystem;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    required this.messageType,
    required this.isSystem,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    return ChatMessage(
      id: j['id'] as String,
      conversationId: j['conversation_id'] as String,
      senderId: j['sender_user_id'] as String? ?? '',
      body: j['body'] as String?,
      messageType: j['message_type'] as String? ?? 'text',
      isSystem: (j['is_system'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  bool isMine(String myUserId) => senderId == myUserId;

  @override
  List<Object?> get props => [id];
}
