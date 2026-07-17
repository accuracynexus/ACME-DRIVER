import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/settlement_datasource.dart';
import '../../domain/entities/settlement.dart';

final settlementDataSourceProvider = Provider<SettlementDataSource>((ref) {
  return SettlementDataSource(ref.watch(supabaseClientProvider));
});

final _driverIdProvider = Provider<String>((ref) {
  return ref.watch(currentDriverProvider).value?.userId ?? '';
});

final settlementsProvider = FutureProvider<List<Settlement>>((ref) async {
  final id = ref.watch(_driverIdProvider);
  if (id.isEmpty) return [];
  return ref.watch(settlementDataSourceProvider).getSettlements(id);
});

final todaySummaryProvider = FutureProvider<TodaySummary>((ref) async {
  final id = ref.watch(_driverIdProvider);
  if (id.isEmpty) return TodaySummary.empty;
  return ref.watch(settlementDataSourceProvider).getTodaySummary(id);
});
