import 'package:equatable/equatable.dart';

/// Un pedido visto por el repartidor: asignación + pedido + local + entrega.
class DeliveryOrder extends Equatable {
  final String assignmentId;
  final AssignmentStatus assignmentStatus;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  final String orderId;
  final int orderCode;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String? specialInstructions;
  final DateTime? placedAt;

  // Local (recojo)
  final String branchName;
  final String? branchPhone;
  final double branchLat;
  final double branchLng;

  // Entrega
  final String deliveryAddress;
  final String? deliveryReference;
  final double deliveryLat;
  final double deliveryLng;
  final String recipientName;
  final String recipientPhone;
  final double? estimatedDistanceKm;
  final int? estimatedTimeMin;

  final List<OrderItem> items;

  const DeliveryOrder({
    required this.assignmentId,
    required this.assignmentStatus,
    this.assignedAt,
    this.acceptedAt,
    this.completedAt,
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.specialInstructions,
    this.placedAt,
    required this.branchName,
    this.branchPhone,
    required this.branchLat,
    required this.branchLng,
    required this.deliveryAddress,
    this.deliveryReference,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.recipientName,
    required this.recipientPhone,
    this.estimatedDistanceKm,
    this.estimatedTimeMin,
    this.items = const [],
  });

  String get code => '#$orderCode';

  bool get hasCoordinates =>
      (branchLat != 0 || branchLng != 0) && (deliveryLat != 0 || deliveryLng != 0);

  @override
  List<Object?> get props => [assignmentId, orderId, status, assignmentStatus];
}

class OrderItem extends Equatable {
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  @override
  List<Object?> get props => [name, quantity, lineTotal];
}

enum AssignmentStatus { assigned, accepted, rejected, cancelled, completed }

extension AssignmentStatusX on AssignmentStatus {
  static AssignmentStatus fromString(String? v) {
    switch (v) {
      case 'accepted':
        return AssignmentStatus.accepted;
      case 'rejected':
        return AssignmentStatus.rejected;
      case 'cancelled':
        return AssignmentStatus.cancelled;
      case 'completed':
        return AssignmentStatus.completed;
      default:
        return AssignmentStatus.assigned;
    }
  }
}

/// Estados del pedido (enum public.order_status del backend).
enum OrderStatus {
  pendingPayment,
  placed,
  confirmed,
  preparing,
  readyForPickup,
  assigned,
  driverAccepted,
  pickedUp,
  onTheWay,
  delivered,
  cancelled,
  failed,
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'Pago pendiente';
      case OrderStatus.placed:
        return 'Recibido';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.preparing:
        return 'En preparación';
      case OrderStatus.readyForPickup:
        return 'Listo para recojo';
      case OrderStatus.assigned:
        return 'Oferta asignada';
      case OrderStatus.driverAccepted:
        return 'Aceptado';
      case OrderStatus.pickedUp:
        return 'Recogido';
      case OrderStatus.onTheWay:
        return 'En camino';
      case OrderStatus.delivered:
        return 'Entregado';
      case OrderStatus.cancelled:
        return 'Cancelado';
      case OrderStatus.failed:
        return 'Fallido';
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'pending_payment';
      case OrderStatus.placed:
        return 'placed';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.driverAccepted:
        return 'driver_accepted';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.failed:
        return 'failed';
    }
  }

  static OrderStatus fromString(String? value) {
    for (final s in OrderStatus.values) {
      if (s.value == value) return s;
    }
    return OrderStatus.placed;
  }

  /// Siguiente estado que el repartidor puede reportar.
  OrderStatus? get next {
    switch (this) {
      case OrderStatus.driverAccepted:
        return OrderStatus.pickedUp;
      case OrderStatus.pickedUp:
        return OrderStatus.onTheWay;
      case OrderStatus.onTheWay:
        return OrderStatus.delivered;
      default:
        return null;
    }
  }

  /// Etiqueta del botón para avanzar al siguiente estado.
  String? get nextActionLabel {
    switch (this) {
      case OrderStatus.driverAccepted:
        return 'Ya recogí el pedido';
      case OrderStatus.pickedUp:
        return 'Iniciar entrega';
      case OrderStatus.onTheWay:
        return 'Confirmar entrega';
      default:
        return null;
    }
  }

  bool get isActiveForDriver =>
      this == OrderStatus.driverAccepted ||
      this == OrderStatus.pickedUp ||
      this == OrderStatus.onTheWay;
}
