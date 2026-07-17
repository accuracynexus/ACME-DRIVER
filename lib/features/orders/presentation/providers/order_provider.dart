import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/order_model.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../domain/entities/order.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Data source ─────────────────────────────────────────────
final orderDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

// ── Ofertas pendientes ──────────────────────────────────────
final offersProvider = FutureProvider<List<DeliveryOrderModel>>((ref) async {
  final driverId = ref.watch(currentDriverProvider).value?.id ?? '';
  if (driverId.isEmpty) return [];
  return ref.watch(orderDataSourceProvider).getOffers(driverId);
});

// ── Historial ───────────────────────────────────────────────
final orderHistoryProvider =
    FutureProvider<List<DeliveryOrderModel>>((ref) async {
  final driverId = ref.watch(currentDriverProvider).value?.id ?? '';
  if (driverId.isEmpty) return [];
  return ref.watch(orderDataSourceProvider).getHistory(driverId);
});

// ── Entrega activa ──────────────────────────────────────────
final activeOrderProvider = StateNotifierProvider<ActiveOrderNotifier,
    AsyncValue<DeliveryOrderModel?>>((ref) {
  final driverId = ref.watch(currentDriverProvider).value?.id ?? '';
  return ActiveOrderNotifier(
    ref.watch(orderDataSourceProvider),
    ref.watch(locationServiceProvider),
    driverId,
    onChanged: () {
      ref.invalidate(offersProvider);
      ref.invalidate(orderHistoryProvider);
    },
  );
});

class ActiveOrderNotifier
    extends StateNotifier<AsyncValue<DeliveryOrderModel?>> {
  final OrderRemoteDataSource _dataSource;
  final LocationService _locationService;
  final String _driverId;
  final VoidCallback? onChanged;

  ActiveOrderNotifier(this._dataSource, this._locationService, this._driverId,
      {this.onChanged})
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    if (_driverId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    final result =
        await AsyncValue.guard(() => _dataSource.getActiveDelivery(_driverId));
    if (!mounted) return;
    state = result;
    _locationService.currentOrderId = result.value?.orderId;
  }

  /// Acepta una oferta y la convierte en la entrega activa.
  Future<void> acceptOffer(DeliveryOrder offer) async {
    await _dataSource.acceptOffer(offer.assignmentId);
    _locationService.start(); // asegura el envío de ubicación durante la entrega
    await refresh();
    onChanged?.call();
  }

  Future<void> rejectOffer(DeliveryOrder offer, {String? reason}) async {
    await _dataSource.rejectOffer(offer.assignmentId, reason: reason);
    onChanged?.call();
  }

  /// Avanza el pedido activo al siguiente estado del flujo.
  Future<void> advanceStatus() async {
    final current = state.value;
    final next = current?.status.next;
    if (current == null || next == null) return;

    await _dataSource.advanceOrderStatus(current.orderId, next);
    await refresh();
    onChanged?.call();
  }
}

// ── Sincronización: polling + realtime + aviso de nuevas ofertas ──
final orderSyncProvider = Provider<OrderSync>((ref) {
  final sync = OrderSync(ref);
  ref.onDispose(sync.stop);
  return sync;
});

/// Refresca ofertas/pedido activo periódicamente y por realtime (si el
/// proyecto lo tiene habilitado). Lanza una notificación local cuando
/// aparece una oferta nueva.
class OrderSync {
  final Ref _ref;
  Timer? _timer;
  RealtimeChannel? _channel;
  Set<String> _knownOfferIds = {};
  bool _primed = false;

  OrderSync(this._ref);

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.ordersPollInterval),
      (_) => _tick(),
    );
    _subscribeRealtime();
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _channel?.unsubscribe();
    _channel = null;
    _primed = false;
    _knownOfferIds = {};
  }

  void _subscribeRealtime() {
    final driverId = _ref.read(currentDriverProvider).value?.id;
    if (driverId == null || _channel != null) return;
    try {
      final client = _ref.read(supabaseClientProvider);
      _channel = client
          .channel('driver_assignments')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_assignments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'driver_id',
              value: driverId,
            ),
            callback: (_) => _tick(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('OrderSync realtime: $e');
    }
  }

  Future<void> _tick() async {
    final driver = _ref.read(currentDriverProvider).value;
    if (driver == null) return;

    _ref.invalidate(offersProvider);
    unawaited(_ref.read(activeOrderProvider.notifier).refresh());

    try {
      final offers = await _ref.read(offersProvider.future);
      final ids = offers.map((o) => o.assignmentId).toSet();
      if (_primed) {
        for (final offer in offers) {
          if (!_knownOfferIds.contains(offer.assignmentId)) {
            unawaited(_ref
                .read(notificationServiceProvider)
                .showNewOffer(offer.code, offer.deliveryFee));
          }
        }
      }
      _knownOfferIds = ids;
      _primed = true;
    } catch (e) {
      debugPrint('OrderSync tick: $e');
    }
  }
}
