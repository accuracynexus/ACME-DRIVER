import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/order.dart';
import 'order_model.dart';

abstract class OrderRemoteDataSource {
  /// Ofertas pendientes de aceptar (assignments en estado 'assigned').
  Future<List<DeliveryOrderModel>> getOffers(String driverId);

  /// Entrega activa (assignment aceptado cuyo pedido sigue en curso).
  Future<DeliveryOrderModel?> getActiveDelivery(String driverId);

  /// Entregas completadas / canceladas.
  Future<List<DeliveryOrderModel>> getHistory(String driverId, {int limit});

  Future<void> acceptOffer(String assignmentId);
  Future<void> rejectOffer(String assignmentId, {String? reason});
  Future<void> advanceOrderStatus(String orderId, OrderStatus toStatus);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final SupabaseClient _client;

  OrderRemoteDataSourceImpl(this._client);

  static const _select = '''
    id, order_id, status, assigned_at, accepted_at, completed_at,
    order:orders (
      id, order_code, status, subtotal, delivery_fee, total,
      special_instructions, placed_at,
      branch:merchant_branches ( id, name, phone, lat, lng ),
      delivery:order_delivery_details ( address_snapshot, reference_snapshot,
        lat, lng, recipient_name, recipient_phone,
        estimated_distance_km, estimated_time_min ),
      items:order_items ( product_name_snapshot, quantity, unit_price, line_total )
    )''';

  @override
  Future<List<DeliveryOrderModel>> getOffers(String driverId) async {
    try {
      final data = await _client
          .from('order_assignments')
          .select(_select)
          .eq('driver_id', driverId)
          .eq('status', 'assigned')
          .order('assigned_at', ascending: false);

      return (data as List)
          .map((e) => DeliveryOrderModel.fromAssignmentJson(e))
          .where((o) => o.status == OrderStatus.assigned)
          .toList();
    } catch (e) {
      throw OrderException('No se pudieron cargar las ofertas: $e');
    }
  }

  @override
  Future<DeliveryOrderModel?> getActiveDelivery(String driverId) async {
    try {
      final data = await _client
          .from('order_assignments')
          .select(_select)
          .eq('driver_id', driverId)
          .eq('status', 'accepted')
          .order('accepted_at', ascending: false)
          .limit(1);

      final list = (data as List)
          .map((e) => DeliveryOrderModel.fromAssignmentJson(e))
          .where((o) => o.status.isActiveForDriver)
          .toList();
      return list.isEmpty ? null : list.first;
    } catch (e) {
      throw OrderException('No se pudo cargar el pedido activo: $e');
    }
  }

  @override
  Future<List<DeliveryOrderModel>> getHistory(String driverId,
      {int limit = 50}) async {
    try {
      final data = await _client
          .from('order_assignments')
          .select(_select)
          .eq('driver_id', driverId)
          .inFilter('status', ['completed', 'cancelled'])
          .order('assigned_at', ascending: false)
          .limit(limit);

      return (data as List)
          .map((e) => DeliveryOrderModel.fromAssignmentJson(e))
          .toList();
    } catch (e) {
      throw OrderException('No se pudo cargar el historial: $e');
    }
  }

  @override
  Future<void> acceptOffer(String assignmentId) async {
    try {
      await _client.rpc('driver_accept_assignment',
          params: {'p_assignment_id': assignmentId});
    } catch (e) {
      throw OrderException('No se pudo aceptar el pedido: ${_pgMessage(e)}');
    }
  }

  @override
  Future<void> rejectOffer(String assignmentId, {String? reason}) async {
    try {
      await _client.rpc('driver_reject_assignment', params: {
        'p_assignment_id': assignmentId,
        if (reason != null) 'p_reason': reason,
      });
    } catch (e) {
      throw OrderException('No se pudo rechazar el pedido: ${_pgMessage(e)}');
    }
  }

  @override
  Future<void> advanceOrderStatus(String orderId, OrderStatus toStatus) async {
    try {
      await _client.rpc('driver_advance_order_status', params: {
        'p_order_id': orderId,
        'p_to_status': toStatus.value,
      });
    } catch (e) {
      throw OrderException('No se pudo actualizar el estado: ${_pgMessage(e)}');
    }
  }

  static String _pgMessage(Object e) =>
      e is PostgrestException ? e.message : e.toString();
}
