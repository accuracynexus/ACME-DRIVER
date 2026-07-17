import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/chat_message.dart';

/// Acceso al chat del pedido sobre las tablas compartidas
/// `conversations` / `messages`. El ingreso del repartidor a la conversación
/// se resuelve con la RPC `get_or_create_order_conversation` (SECURITY DEFINER),
/// porque las RLS no permiten que el driver se agregue como participante.
class ChatRemoteDataSource {
  final SupabaseClient _client;
  ChatRemoteDataSource(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Devuelve el id de la conversación order_chat del pedido (la crea y agrega
  /// al repartidor si hace falta).
  Future<String> getOrCreateConversation(String orderId) async {
    try {
      final res = await _client.rpc(
        AppConstants.rpcGetOrCreateOrderConversation,
        params: {'p_order_id': orderId},
      );
      return res.toString();
    } catch (e) {
      throw OrderException('No se pudo abrir el chat: $e');
    }
  }

  /// Carga inicial de mensajes (orden cronológico).
  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final data = await _client
        .from(AppConstants.messagesTable)
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Stream en tiempo real de los mensajes de la conversación.
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _client
        .from(AppConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  /// Envía un mensaje de texto a la conversación.
  Future<void> sendMessage(String conversationId, String body) async {
    final uid = currentUserId;
    await _client.from(AppConstants.messagesTable).insert({
      'conversation_id': conversationId,
      'sender_user_id': uid,
      'message_type': 'text',
      'body': body,
      'is_system': false,
    });
  }
}
