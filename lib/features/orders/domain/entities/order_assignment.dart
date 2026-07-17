import 'package:equatable/equatable.dart';
import 'order.dart';

enum AssignmentStatus { assigned, accepted, rejected, cancelled, completed }

extension AssignmentStatusX on AssignmentStatus {
  String get value => name;

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

/// Una oferta/asignación de pedido para el repartidor.
class OrderAssignment extends Equatable {
  final String id;
  final String orderId;
  final String driverId;
  final AssignmentStatus status;
  final DateTime assignedAt;
  final Order? order;

  const OrderAssignment({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.status,
    required this.assignedAt,
    this.order,
  });

  /// Segundos restantes para aceptar antes de que expire la oferta.
  int secondsLeft(int timeoutSeconds) {
    final deadline = assignedAt.add(Duration(seconds: timeoutSeconds));
    final left = deadline.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  List<Object?> get props => [id, status];
}
