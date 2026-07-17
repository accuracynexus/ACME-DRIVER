import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/providers/supabase_provider.dart';

class ChatMessage {
  final String id;
  final String senderUserId;
  final String body;
  final String messageType;
  final String? fileUrl;
  final bool isSystem;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.body,
    required this.messageType,
    this.fileUrl,
    required this.isSystem,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderUserId: json['sender_user_id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        messageType: json['message_type'] as String? ?? 'text',
        fileUrl: json['file_url'] as String?,
        isSystem: json['is_system'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class ChatState {
  final String conversationId;
  final List<ChatMessage> messages;

  /// user_id → rol del participante (driver, customer, merchant, admin…)
  final Map<String, String> participantRoles;

  const ChatState({
    required this.conversationId,
    this.messages = const [],
    this.participantRoles = const {},
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    Map<String, String>? participantRoles,
  }) =>
      ChatState(
        conversationId: conversationId,
        messages: messages ?? this.messages,
        participantRoles: participantRoles ?? this.participantRoles,
      );
}

final chatProvider = StateNotifierProvider.autoDispose
    .family<ChatNotifier, AsyncValue<ChatState>, String>((ref, orderId) {
  return ChatNotifier(ref.watch(supabaseClientProvider), orderId);
});

class ChatNotifier extends StateNotifier<AsyncValue<ChatState>> {
  final SupabaseClient _client;
  final String _orderId;
  Timer? _pollTimer;
  RealtimeChannel? _channel;
  final Set<String> _readIds = {};

  ChatNotifier(this._client, this._orderId)
      : super(const AsyncValue.loading()) {
    _init();
  }

  String? get _myId => _client.auth.currentUser?.id;

  Future<void> _init() async {
    try {
      final conversationId = await _client.rpc(
        'get_or_create_order_conversation',
        params: {'p_order_id': _orderId},
      ) as String;

      state = AsyncValue.data(ChatState(conversationId: conversationId));
      await _load();

      _pollTimer = Timer.periodic(
          const Duration(seconds: 4), (_) => _load());
      _subscribeRealtime(conversationId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime(String conversationId) {
    try {
      _channel = _client
          .channel('chat_$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (_) => _load(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Chat realtime: $e');
    }
  }

  Future<void> _load() async {
    final current = state.value;
    if (current == null) return;

    try {
      final results = await Future.wait([
        _client
            .from('messages')
            .select()
            .eq('conversation_id', current.conversationId)
            .order('created_at', ascending: true)
            .limit(200),
        _client
            .from('conversation_participants')
            .select('user_id, participant_role')
            .eq('conversation_id', current.conversationId),
      ]);

      final messages = (results[0] as List)
          .map((e) => ChatMessage.fromJson(e))
          .toList();
      final roles = <String, String>{
        for (final p in results[1] as List)
          p['user_id'] as String: p['participant_role'] as String? ?? ''
      };

      if (!mounted) return;
      state = AsyncValue.data(
          current.copyWith(messages: messages, participantRoles: roles));

      _markRead(messages);
    } catch (e) {
      debugPrint('Chat load: $e');
    }
  }

  /// Registra lectura de mensajes ajenos (best-effort).
  Future<void> _markRead(List<ChatMessage> messages) async {
    final me = _myId;
    if (me == null) return;
    for (final m in messages) {
      if (m.senderUserId == me || _readIds.contains(m.id)) continue;
      _readIds.add(m.id);
      try {
        await _client
            .from('message_reads')
            .insert({'message_id': m.id, 'user_id': me});
      } catch (_) {}
    }
  }

  Future<void> send(String text) async {
    final current = state.value;
    final me = _myId;
    final body = text.trim();
    if (current == null || me == null || body.isEmpty) return;

    await _client.from('messages').insert({
      'conversation_id': current.conversationId,
      'sender_user_id': me,
      'message_type': 'text',
      'body': body,
    });
    await _load();
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}
