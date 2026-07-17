import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/order_provider.dart';

class EarningsSummary {
  final double today;
  final int todayDeliveries;
  final double week;
  final int weekDeliveries;
  final double total;
  final int totalDeliveries;

  const EarningsSummary({
    this.today = 0,
    this.todayDeliveries = 0,
    this.week = 0,
    this.weekDeliveries = 0,
    this.total = 0,
    this.totalDeliveries = 0,
  });
}

/// Resumen calculado a partir de las entregas completadas del historial.
final earningsSummaryProvider = Provider<AsyncValue<EarningsSummary>>((ref) {
  final historyAsync = ref.watch(orderHistoryProvider);
  return historyAsync.whenData((orders) {
    final delivered = orders
        .where((o) => o.assignmentStatus == AssignmentStatus.completed)
        .toList();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));

    double today = 0, week = 0, total = 0;
    int todayCount = 0, weekCount = 0;

    for (final o in delivered) {
      total += o.deliveryFee;
      final when = (o.completedAt ?? o.assignedAt)?.toLocal();
      if (when == null) continue;
      if (!when.isBefore(startOfDay)) {
        today += o.deliveryFee;
        todayCount++;
      }
      if (!when.isBefore(startOfWeek)) {
        week += o.deliveryFee;
        weekCount++;
      }
    }

    return EarningsSummary(
      today: today,
      todayDeliveries: todayCount,
      week: week,
      weekDeliveries: weekCount,
      total: total,
      totalDeliveries: delivered.length,
    );
  });
});

class Settlement {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int deliveriesCount;
  final double grossEarnings;
  final double netPayable;
  final String status;
  final DateTime? paidAt;

  const Settlement({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.deliveriesCount,
    required this.grossEarnings,
    required this.netPayable,
    required this.status,
    this.paidAt,
  });

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Pagado';
      case 'generated':
        return 'Generado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Borrador';
    }
  }
}

final settlementsProvider = FutureProvider<List<Settlement>>((ref) async {
  final driverId = ref.watch(currentDriverProvider).value?.id;
  if (driverId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('driver_settlements')
      .select()
      .eq('driver_id', driverId)
      .order('period_start', ascending: false)
      .limit(20);

  return (data as List)
      .map((e) => Settlement(
            id: e['id'] as String,
            periodStart: DateTime.parse(e['period_start'] as String),
            periodEnd: DateTime.parse(e['period_end'] as String),
            deliveriesCount: (e['deliveries_count'] as num?)?.toInt() ?? 0,
            grossEarnings: (e['gross_earnings'] as num?)?.toDouble() ?? 0,
            netPayable: (e['net_payable'] as num?)?.toDouble() ?? 0,
            status: e['status'] as String? ?? 'draft',
            paidAt: e['paid_at'] != null
                ? DateTime.tryParse(e['paid_at'] as String)
                : null,
          ))
      .toList();
});
