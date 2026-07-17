import 'package:equatable/equatable.dart';

/// Estados del pedido (enum order_status del backend).
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

extension OrderStatusX on OrderStatus {
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

  String get label {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'Pago pendiente';
      case OrderStatus.placed:
        return 'Realizado';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.preparing:
        return 'En preparación';
      case OrderStatus.readyForPickup:
        return 'Listo para recoger';
      case OrderStatus.assigned:
        return 'Asignado';
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

  static OrderStatus fromString(String? v) {
    switch (v) {
      case 'pending_payment':
        return OrderStatus.pendingPayment;
      case 'placed':
        return OrderStatus.placed;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready_for_pickup':
        return OrderStatus.readyForPickup;
      case 'assigned':
        return OrderStatus.assigned;
      case 'driver_accepted':
        return OrderStatus.driverAccepted;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'failed':
        return OrderStatus.failed;
      default:
        return OrderStatus.placed;
    }
  }

  /// Siguiente estado que el repartidor puede accionar, o null si no aplica.
  OrderStatus? get nextForDriver {
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

  String? get driverActionLabel {
    switch (this) {
      case OrderStatus.driverAccepted:
        return 'Marcar como recogido';
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

  bool get isFinished =>
      this == OrderStatus.delivered ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.failed;
}

class Order extends Equatable {
  final String id;
  final int orderCode;
  final OrderStatus status;
  final String? paymentStatus;
  final String paymentMethodCode; // cash, yape, plin, card_online, card_pos
  final String paymentMethodName; // "Efectivo", "Yape", "Plin", ...
  final String fulfillmentType;

  // Recojo (merchant_branches)
  final String? branchId;
  final String branchName;
  final String? branchPhone;
  final String? branchAddress;
  final String? branchReference;
  final double? branchLat;
  final double? branchLng;

  // Entrega (order_delivery_details)
  final String deliveryAddress;
  final String? deliveryReference;
  final String? deliveryDistrict;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? recipientName;
  final String? recipientPhone;
  final double? estimatedDistanceKm;
  final int? estimatedTimeMin;

  // Dinero
  final double subtotal;
  final double deliveryFee;
  final double tipAmount;
  final double total;
  final double? cashChangeFor;
  final String currency;

  final String? specialInstructions;

  // Tiempos
  final DateTime? placedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.orderCode,
    required this.status,
    this.paymentStatus,
    this.paymentMethodCode = '',
    this.paymentMethodName = '',
    required this.fulfillmentType,
    this.branchId,
    required this.branchName,
    this.branchPhone,
    this.branchAddress,
    this.branchReference,
    this.branchLat,
    this.branchLng,
    required this.deliveryAddress,
    this.deliveryReference,
    this.deliveryDistrict,
    this.deliveryLat,
    this.deliveryLng,
    this.recipientName,
    this.recipientPhone,
    this.estimatedDistanceKm,
    this.estimatedTimeMin,
    required this.subtotal,
    required this.deliveryFee,
    required this.tipAmount,
    required this.total,
    this.cashChangeFor,
    required this.currency,
    this.specialInstructions,
    this.placedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    required this.createdAt,
  });

  /// Ganancia del repartidor por este pedido (delivery fee + propina).
  double get driverEarning => deliveryFee + tipAmount;

  /// El repartidor debe cobrarle al cliente al entregar (efectivo, Yape, Plin,
  /// o tarjeta en el POS). No cobra si ya se pagó online o el pago está saldado.
  bool get mustCollectPayment =>
      paymentStatus != 'paid' && paymentMethodCode != 'card_online';

  /// Cobro específicamente en efectivo (para el registro de cash_collections).
  bool get isCashOnDelivery => mustCollectPayment && paymentMethodCode == 'cash';

  /// Nombre legible del método de pago para mostrar al repartidor.
  String get paymentMethodLabel {
    if (paymentMethodName.isNotEmpty) return paymentMethodName;
    switch (paymentMethodCode) {
      case 'cash':
        return 'Efectivo';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      case 'card_pos':
        return 'Tarjeta (POS)';
      case 'card_online':
        return 'Tarjeta online';
      default:
        return 'Efectivo';
    }
  }

  @override
  List<Object?> get props => [id, status];
}
