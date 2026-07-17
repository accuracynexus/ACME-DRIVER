import 'package:equatable/equatable.dart';

enum SettlementStatus { draft, generated, paid, cancelled }

extension SettlementStatusX on SettlementStatus {
  String get label {
    switch (this) {
      case SettlementStatus.draft:
        return 'Borrador';
      case SettlementStatus.generated:
        return 'Por pagar';
      case SettlementStatus.paid:
        return 'Pagado';
      case SettlementStatus.cancelled:
        return 'Cancelado';
    }
  }

  static SettlementStatus fromString(String? v) {
    switch (v) {
      case 'generated':
        return SettlementStatus.generated;
      case 'paid':
        return SettlementStatus.paid;
      case 'cancelled':
        return SettlementStatus.cancelled;
      default:
        return SettlementStatus.draft;
    }
  }
}

class Settlement extends Equatable {
  final String id;
  final String driverId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int deliveriesCount;
  final double grossEarnings;
  final double bonuses;
  final double penalties;
  final double cashCollected;
  final double netPayable;
  final SettlementStatus status;
  final DateTime? generatedAt;
  final DateTime? paidAt;

  const Settlement({
    required this.id,
    required this.driverId,
    required this.periodStart,
    required this.periodEnd,
    required this.deliveriesCount,
    required this.grossEarnings,
    required this.bonuses,
    required this.penalties,
    required this.cashCollected,
    required this.netPayable,
    required this.status,
    this.generatedAt,
    this.paidAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
    DateTime toDt(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return Settlement(
      id: j['id'] as String,
      driverId: j['driver_id'] as String,
      periodStart: toDt(j['period_start']),
      periodEnd: toDt(j['period_end']),
      deliveriesCount: (j['deliveries_count'] as num?)?.toInt() ?? 0,
      grossEarnings: toD(j['gross_earnings']),
      bonuses: toD(j['bonuses']),
      penalties: toD(j['penalties']),
      cashCollected: toD(j['cash_collected']),
      netPayable: toD(j['net_payable']),
      status: SettlementStatusX.fromString(j['status'] as String?),
      generatedAt: j['generated_at'] == null
          ? null
          : DateTime.tryParse(j['generated_at'].toString()),
      paidAt: j['paid_at'] == null
          ? null
          : DateTime.tryParse(j['paid_at'].toString()),
    );
  }

  @override
  List<Object?> get props => [id, status];
}
