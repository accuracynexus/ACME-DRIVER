import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/entities/settlement.dart';

class TodaySummary {
  final int deliveries;
  final double earnings;
  const TodaySummary(this.deliveries, this.earnings);
  static const empty = TodaySummary(0, 0);
}

class SettlementDataSource {
  final SupabaseClient _client;
  SettlementDataSource(this._client);

  Future<List<Settlement>> getSettlements(String driverId) async {
    final data = await _client
        .from(AppConstants.driverSettlementsTable)
        .select()
        .eq('driver_id', driverId)
        .order('period_end', ascending: false)
        .limit(AppConstants.pageSize);
    return (data as List)
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Entregas y ganancias del día actual (pedidos entregados hoy).
  Future<TodaySummary> getTodaySummary(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final data = await _client
        .from(AppConstants.ordersTable)
        .select('delivery_fee, tip_amount')
        .eq('current_driver_id', driverId)
        .eq('status', 'delivered')
        .gte('delivered_at', startOfDay.toIso8601String());

    final rows = data as List;
    double earnings = 0;
    for (final r in rows) {
      earnings += ((r['delivery_fee'] as num?)?.toDouble() ?? 0) +
          ((r['tip_amount'] as num?)?.toDouble() ?? 0);
    }
    return TodaySummary(rows.length, earnings);
  }
}
