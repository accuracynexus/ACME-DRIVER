import '../../domain/entities/order_assignment.dart';
import 'order_model.dart';

class OrderAssignmentModel extends OrderAssignment {
  const OrderAssignmentModel({
    required super.id,
    required super.orderId,
    required super.driverId,
    required super.status,
    required super.assignedAt,
    super.order,
  });

  /// Espera un row de `order_assignments` con embed opcional
  /// `orders(*, order_delivery_details(*), merchant_branches(...))`.
  factory OrderAssignmentModel.fromJson(Map<String, dynamic> j) {
    final orderJson = j['orders'];
    return OrderAssignmentModel(
      id: j['id'] as String,
      orderId: j['order_id'] as String,
      driverId: j['driver_id'] as String,
      status: AssignmentStatusX.fromString(j['status'] as String?),
      assignedAt: DateTime.tryParse(j['assigned_at']?.toString() ?? '') ??
          DateTime.now(),
      order: orderJson is Map<String, dynamic>
          ? OrderModel.fromJson(orderJson)
          : null,
    );
  }
}
