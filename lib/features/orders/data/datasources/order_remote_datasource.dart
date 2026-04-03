import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../datasources/order_model.dart';

abstract class OrderRemoteDataSource {
  Future<List<OrderModel>> getAvailableOrders();
  Future<OrderModel?> getActiveOrder(String driverId);
  Future<List<OrderModel>> getOrderHistory(String driverId);
  Future<OrderModel> acceptOrder(String orderId, String driverId);
  Future<OrderModel> updateOrderStatus(String orderId, String status);
  Stream<List<OrderModel>> watchAvailableOrders();
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final SupabaseClient _client;

  OrderRemoteDataSourceImpl(this._client);

  @override
  Future<List<OrderModel>> getAvailableOrders() async {
    try {
      final data = await _client
          .from(AppConstants.ordersTable)
          .select()
          .eq('status', 'assigned')
          .isFilter('driver_id', null)
          .order('created_at', ascending: false);

      return (data as List).map((e) => OrderModel.fromJson(e)).toList();
    } catch (e) {
      // Return mock data if Supabase is not configured yet
      return MockOrders.available;
    }
  }

  @override
  Future<OrderModel?> getActiveOrder(String driverId) async {
    try {
      final data = await _client
          .from(AppConstants.ordersTable)
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', ['accepted', 'picked_up', 'on_the_way'])
          .maybeSingle();

      if (data == null) return null;
      return OrderModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<OrderModel>> getOrderHistory(String driverId) async {
    try {
      final data = await _client
          .from(AppConstants.ordersTable)
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', ['delivered', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(AppConstants.pageSize);

      return (data as List).map((e) => OrderModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<OrderModel> acceptOrder(String orderId, String driverId) async {
    try {
      final data = await _client
          .from(AppConstants.ordersTable)
          .update({
            'driver_id': driverId,
            'status': 'accepted',
            'assigned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select()
          .single();

      await _client.from(AppConstants.orderStatusHistoryTable).insert({
        'order_id': orderId,
        'status': 'accepted',
        'driver_id': driverId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return OrderModel.fromJson(data);
    } catch (e) {
      throw OrderException('No se pudo aceptar el pedido: $e');
    }
  }

  @override
  Future<OrderModel> updateOrderStatus(String orderId, String status) async {
    try {
      final updates = <String, dynamic>{'status': status};
      if (status == 'delivered') {
        updates['delivered_at'] = DateTime.now().toIso8601String();
      }

      final data = await _client
          .from(AppConstants.ordersTable)
          .update(updates)
          .eq('id', orderId)
          .select()
          .single();

      await _client.from(AppConstants.orderStatusHistoryTable).insert({
        'order_id': orderId,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
      });

      return OrderModel.fromJson(data);
    } catch (e) {
      throw OrderException('Error al actualizar estado: $e');
    }
  }

  @override
  Stream<List<OrderModel>> watchAvailableOrders() {
    return _client
        .from(AppConstants.ordersTable)
        .stream(primaryKey: ['id'])
        .eq('status', 'assigned')
        .map((data) => data.map((e) => OrderModel.fromJson(e)).toList());
  }
}
