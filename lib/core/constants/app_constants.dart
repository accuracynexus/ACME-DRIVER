class AppConstants {
  AppConstants._();

  static const String appName = 'ACME-DRIVER';
  static const String appVersion = '1.0.0';

  // ── Tablas Supabase (esquema real ACME PEDIDOS) ──────────────
  static const String profilesTable = 'profiles';
  static const String driversTable = 'drivers';
  static const String driverCurrentStateTable = 'driver_current_state';
  static const String driverLocationsTable = 'driver_locations';
  static const String driverDocumentsTable = 'driver_documents';
  static const String driverSettlementsTable = 'driver_settlements';
  static const String driverSettlementItemsTable = 'driver_settlement_items';
  static const String vehiclesTable = 'vehicles';
  static const String vehicleTypesTable = 'vehicle_types';
  static const String ordersTable = 'orders';
  static const String orderAssignmentsTable = 'order_assignments';
  static const String orderStatusHistoryTable = 'order_status_history';
  static const String orderDeliveryDetailsTable = 'order_delivery_details';
  static const String orderEvidencesTable = 'order_evidences';
  static const String cashCollectionsTable = 'cash_collections';
  static const String merchantBranchesTable = 'merchant_branches';
  static const String notificationsTable = 'notifications';
  static const String conversationsTable = 'conversations';
  static const String conversationParticipantsTable = 'conversation_participants';
  static const String messagesTable = 'messages';
  static const String messageReadsTable = 'message_reads';

  // ── RPC (definidas en supabase/migrations) ───────────────────
  static const String rpcRegisterDriver = 'register_driver';
  static const String rpcSubmitDriverDocument = 'submit_driver_document';
  static const String rpcAcceptAssignment = 'driver_accept_assignment';
  static const String rpcRejectAssignment = 'driver_reject_assignment';
  static const String rpcAdvanceOrderStatus = 'driver_advance_order_status';
  static const String rpcSetOnline = 'driver_set_online';
  static const String rpcPingLocation = 'driver_ping_location';
  static const String rpcGetOrCreateOrderConversation =
      'get_or_create_order_conversation';

  // ── Storage buckets ──────────────────────────────────────────
  static const String driverDocumentsBucket = 'driver-documents';
  static const String avatarsBucket = 'avatars';

  // ── Tuning local ──────────────────────────────────────────────
  static const int locationUpdateIntervalSec = 10;
  static const int offerTimeoutSeconds = 45;
  static const int pageSize = 20;
}
