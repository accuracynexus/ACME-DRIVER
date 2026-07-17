import '../../domain/entities/order.dart';

class DeliveryOrderModel extends DeliveryOrder {
  const DeliveryOrderModel({
    required super.assignmentId,
    required super.assignmentStatus,
    super.assignedAt,
    super.acceptedAt,
    super.completedAt,
    required super.orderId,
    required super.orderCode,
    required super.status,
    required super.subtotal,
    required super.deliveryFee,
    required super.total,
    super.specialInstructions,
    super.placedAt,
    required super.branchName,
    super.branchPhone,
    required super.branchLat,
    required super.branchLng,
    required super.deliveryAddress,
    super.deliveryReference,
    required super.deliveryLat,
    required super.deliveryLng,
    required super.recipientName,
    required super.recipientPhone,
    super.estimatedDistanceKm,
    super.estimatedTimeMin,
    super.items,
  });

  /// Parsea una fila de order_assignments con el pedido anidado:
  /// order:orders(..., branch:merchant_branches(...),
  /// delivery:order_delivery_details(...), items:order_items(...)).
  factory DeliveryOrderModel.fromAssignmentJson(Map<String, dynamic> json) {
    final order = (json['order'] as Map<String, dynamic>?) ?? const {};
    final branch = (order['branch'] as Map<String, dynamic>?) ?? const {};
    final delivery = (order['delivery'] as Map<String, dynamic>?) ?? const {};
    final itemsJson = (order['items'] as List?) ?? const [];

    return DeliveryOrderModel(
      assignmentId: json['id'] as String,
      assignmentStatus: AssignmentStatusX.fromString(json['status'] as String?),
      assignedAt: _date(json['assigned_at']),
      acceptedAt: _date(json['accepted_at']),
      completedAt: _date(json['completed_at']),
      orderId: order['id'] as String? ?? '',
      orderCode: (order['order_code'] as num?)?.toInt() ?? 0,
      status: OrderStatusExtension.fromString(order['status'] as String?),
      subtotal: _num(order['subtotal']),
      deliveryFee: _num(order['delivery_fee']),
      total: _num(order['total']),
      specialInstructions: order['special_instructions'] as String?,
      placedAt: _date(order['placed_at']),
      branchName: branch['name'] as String? ?? 'Local',
      branchPhone: branch['phone'] as String?,
      branchLat: _num(branch['lat']),
      branchLng: _num(branch['lng']),
      deliveryAddress: delivery['address_snapshot'] as String? ?? '',
      deliveryReference: delivery['reference_snapshot'] as String?,
      deliveryLat: _num(delivery['lat']),
      deliveryLng: _num(delivery['lng']),
      recipientName: delivery['recipient_name'] as String? ?? 'Cliente',
      recipientPhone: delivery['recipient_phone'] as String? ?? '',
      estimatedDistanceKm: (delivery['estimated_distance_km'] as num?)?.toDouble(),
      estimatedTimeMin: (delivery['estimated_time_min'] as num?)?.toInt(),
      items: itemsJson
          .map((e) => OrderItem(
                name: e['product_name_snapshot'] as String? ?? '',
                quantity: (e['quantity'] as num?)?.toInt() ?? 1,
                unitPrice: _num(e['unit_price']),
                lineTotal: _num(e['line_total']),
              ))
          .toList(),
    );
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);
}
