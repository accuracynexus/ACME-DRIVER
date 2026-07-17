import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import 'order_model.dart';
import 'order_assignment_model.dart';

const _orderSelect =
    '*, order_delivery_details(*), '
    'payment_method:payment_methods(code,name), '
    'merchant_branches(name,phone,lat,lng,addresses(line1,district,city,reference))';
const _assignmentSelect = '*, orders($_orderSelect)';

abstract class OrderRemoteDataSource {
  Future<OrderModel?> getActiveOrder(String driverId);
  Future<List<OrderModel>> getOrderHistory(String driverId);
  Future<OrderAssignmentModel?> getPendingOffer(String driverId);

  /// Stream crudo de asignaciones del repartidor (para detectar ofertas).
  Stream<List<Map<String, dynamic>>> watchAssignments(String driverId);

  Future<String> acceptOffer(String assignmentId);
  Future<void> rejectOffer(String assignmentId, {String? reason});
  Future<void> advanceStatus(String orderId, String toStatus);

  Future<void> submitEvidence(
      String orderId, String fileUrl, String evidenceType, {String? note});

  /// Sube una foto de evidencia al bucket privado y la registra.
  Future<void> uploadDeliveryPhoto(String orderId, Uint8List bytes);

  Future<void> recordCashCollection(String orderId, double amount);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final SupabaseClient _client;
  OrderRemoteDataSourceImpl(this._client);

  @override
  Future<OrderModel?> getActiveOrder(String driverId) async {
    final data = await _client
        .from(AppConstants.ordersTable)
        .select(_orderSelect)
        .eq('current_driver_id', driverId)
        .inFilter('status', ['driver_accepted', 'picked_up', 'on_the_way'])
        .order('accepted_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data == null ? null : OrderModel.fromJson(data);
  }

  @override
  Future<List<OrderModel>> getOrderHistory(String driverId) async {
    final data = await _client
        .from(AppConstants.ordersTable)
        .select(_orderSelect)
        .eq('current_driver_id', driverId)
        .inFilter('status', ['delivered', 'cancelled', 'failed'])
        .order('created_at', ascending: false)
        .limit(AppConstants.pageSize);

    return (data as List)
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderAssignmentModel?> getPendingOffer(String driverId) async {
    final data = await _client
        .from(AppConstants.orderAssignmentsTable)
        .select(_assignmentSelect)
        .eq('driver_id', driverId)
        .eq('status', 'assigned')
        .order('assigned_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data == null ? null : OrderAssignmentModel.fromJson(data);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAssignments(String driverId) {
    return _client
        .from(AppConstants.orderAssignmentsTable)
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId);
  }

  @override
  Future<String> acceptOffer(String assignmentId) async {
    try {
      final res = await _client.rpc(AppConstants.rpcAcceptAssignment,
          params: {'p_assignment_id': assignmentId});
      return res.toString();
    } catch (e) {
      throw OrderException('No se pudo aceptar el pedido: $e');
    }
  }

  @override
  Future<void> rejectOffer(String assignmentId, {String? reason}) async {
    try {
      await _client.rpc(AppConstants.rpcRejectAssignment,
          params: {'p_assignment_id': assignmentId, 'p_reason': reason});
    } catch (e) {
      throw OrderException('No se pudo rechazar el pedido: $e');
    }
  }

  @override
  Future<void> advanceStatus(String orderId, String toStatus) async {
    try {
      await _client.rpc(AppConstants.rpcAdvanceOrderStatus,
          params: {'p_order_id': orderId, 'p_to_status': toStatus});
    } catch (e) {
      throw OrderException('No se pudo actualizar el estado: $e');
    }
  }

  @override
  Future<void> submitEvidence(
      String orderId, String fileUrl, String evidenceType,
      {String? note}) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from(AppConstants.orderEvidencesTable).insert({
      'order_id': orderId,
      'driver_id': uid,
      'evidence_type': evidenceType,
      'file_url': fileUrl,
      'note': note,
    });
  }

  @override
  Future<void> uploadDeliveryPhoto(String orderId, Uint8List bytes) async {
    final uid = _client.auth.currentUser?.id;
    final path =
        '$uid/evidence_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(AppConstants.driverDocumentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    await submitEvidence(orderId, path, 'delivery_photo');
  }

  @override
  Future<void> recordCashCollection(String orderId, double amount) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from(AppConstants.cashCollectionsTable).insert({
      'order_id': orderId,
      'driver_id': uid,
      'amount_collected': amount,
      'status': 'collected',
      'collected_at': DateTime.now().toIso8601String(),
    });
  }
}
