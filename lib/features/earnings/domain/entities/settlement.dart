import 'package:equatable/equatable.dart';

class Settlement extends Equatable {
  final String id;
  final String driverId;
  final double amount;
  final int totalDeliveries;
  final DateTime periodStart;
  final DateTime periodEnd;
  final SettlementStatus status;
  final DateTime? paidAt;

  const Settlement({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.totalDeliveries,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.paidAt,
  });

  @override
  List<Object?> get props => [id, status];
}

enum SettlementStatus { pending, paid, rejected }

extension SettlementStatusExtension on SettlementStatus {
  String get label {
    switch (this) {
      case SettlementStatus.pending:
        return 'Pendiente';
      case SettlementStatus.paid:
        return 'Pagado';
      case SettlementStatus.rejected:
        return 'Rechazado';
    }
  }
}
