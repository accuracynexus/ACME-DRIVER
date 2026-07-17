import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../domain/entities/chat_message.dart';

final chatDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource(ref.watch(supabaseClientProvider));
});

/// Id del usuario autenticado (para distinguir mensajes propios).
final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '';
});

/// Resuelve (o crea) la conversación del pedido. Family por orderId.
final conversationIdProvider =
    FutureProvider.family<String, String>((ref, orderId) async {
  return ref.watch(chatDataSourceProvider).getOrCreateConversation(orderId);
});

/// Stream de mensajes de una conversación. Family por conversationId.
final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatDataSourceProvider).watchMessages(conversationId);
});
