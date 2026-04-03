import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/order_model.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../domain/entities/order.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Data source provider ────────────────────────────────────
final orderDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

// ── Available orders ────────────────────────────────────────
final availableOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  return ref.watch(orderDataSourceProvider).getAvailableOrders();
});

// ── Active order ────────────────────────────────────────────
final activeOrderProvider = StateNotifierProvider<ActiveOrderNotifier, AsyncValue<OrderModel?>>((ref) {
  final driverId = ref.watch(currentDriverProvider).value?.id ?? '';
  return ActiveOrderNotifier(ref.watch(orderDataSourceProvider), driverId);
});

class ActiveOrderNotifier extends StateNotifier<AsyncValue<OrderModel?>> {
  final OrderRemoteDataSource _dataSource;
  final String _driverId;

  ActiveOrderNotifier(this._dataSource, this._driverId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (_driverId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    state = await AsyncValue.guard(() => _dataSource.getActiveOrder(_driverId));
  }

  Future<void> acceptOrder(String orderId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _dataSource.acceptOrder(orderId, _driverId));
  }

  Future<void> advanceStatus() async {
    final current = state.value;
    if (current == null) return;

    final next = current.status.next;
    if (next == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _dataSource.updateOrderStatus(current.id, next.value),
    );
  }

  void refresh() => _load();
}

// ── Order history ────────────────────────────────────────────
final orderHistoryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final driverId = ref.watch(currentDriverProvider).value?.id ?? '';
  if (driverId.isEmpty) return [];
  return ref.watch(orderDataSourceProvider).getOrderHistory(driverId);
});
