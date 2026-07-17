import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/order_model.dart';
import '../../data/datasources/order_assignment_model.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../domain/entities/order.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Data source ──────────────────────────────────────────────
final orderDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

final _driverIdProvider = Provider<String>((ref) {
  return ref.watch(currentDriverProvider).value?.userId ?? '';
});

// ── Pedido activo ────────────────────────────────────────────
final activeOrderProvider =
    StateNotifierProvider<ActiveOrderNotifier, AsyncValue<OrderModel?>>((ref) {
  return ActiveOrderNotifier(
    ref.watch(orderDataSourceProvider),
    ref.watch(_driverIdProvider),
  );
});

class ActiveOrderNotifier extends StateNotifier<AsyncValue<OrderModel?>> {
  final OrderRemoteDataSource _ds;
  final String _driverId;

  ActiveOrderNotifier(this._ds, this._driverId)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    if (_driverId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    state = await AsyncValue.guard(() => _ds.getActiveOrder(_driverId));
  }

  Future<void> advance() async {
    final order = state.value;
    if (order == null) return;
    final next = order.status.nextForDriver;
    if (next == null) return;
    await _ds.advanceStatus(order.id, next.value);
    await refresh();
  }

  Future<void> submitDeliveryEvidence(String fileUrl, {String? note}) async {
    final order = state.value;
    if (order == null) return;
    await _ds.submitEvidence(order.id, fileUrl, 'delivery_photo', note: note);
  }

  Future<void> collectCash(double amount) async {
    final order = state.value;
    if (order == null) return;
    await _ds.recordCashCollection(order.id, amount);
  }
}

// ── Historial ────────────────────────────────────────────────
final orderHistoryProvider = FutureProvider<List<OrderModel>>((ref) async {
  final driverId = ref.watch(_driverIdProvider);
  if (driverId.isEmpty) return [];
  return ref.watch(orderDataSourceProvider).getOrderHistory(driverId);
});

// ── Oferta pendiente (realtime) ──────────────────────────────
final pendingOfferProvider =
    StateNotifierProvider<OfferNotifier, AsyncValue<OrderAssignmentModel?>>(
        (ref) {
  return OfferNotifier(
    ref.watch(orderDataSourceProvider),
    ref.watch(_driverIdProvider),
    ref.watch(notificationServiceProvider),
  );
});

class OfferNotifier
    extends StateNotifier<AsyncValue<OrderAssignmentModel?>> {
  final OrderRemoteDataSource _ds;
  final String _driverId;
  final NotificationService _notifications;
  StreamSubscription? _sub;

  /// Id de la última oferta notificada, para no repetir el aviso al refrescar.
  String? _lastNotifiedOfferId;

  OfferNotifier(this._ds, this._driverId, this._notifications)
      : super(const AsyncValue.loading()) {
    // Inicializa el canal y pide permiso de notificaciones al arrancar,
    // así el aviso a la barra funciona apenas llegue la primera oferta.
    _notifications.initialize();
    _start();
  }

  void _start() {
    if (_driverId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    _load();
    _sub = _ds.watchAssignments(_driverId).listen((rows) {
      final hasOffer = rows.any((r) => r['status'] == 'assigned');
      if (hasOffer) {
        _load();
      } else {
        state = const AsyncValue.data(null);
        _lastNotifiedOfferId = null;
      }
    });
  }

  Future<void> _load() async {
    state = await AsyncValue.guard(() => _ds.getPendingOffer(_driverId));
    _maybeNotify(state.value);
  }

  /// Dispara la notificación a la barra del sistema cuando aparece una oferta
  /// nueva (distinta a la ya notificada).
  void _maybeNotify(OrderAssignmentModel? offer) {
    if (offer == null) {
      _lastNotifiedOfferId = null;
      return;
    }
    if (offer.id == _lastNotifiedOfferId) return;
    _lastNotifiedOfferId = offer.id;
    final order = offer.order;
    if (order != null) {
      _notifications.showNewOffer('#${order.orderCode}', order.driverEarning);
    }
  }

  /// Acepta la oferta actual. Devuelve el id del pedido aceptado.
  Future<String?> accept() async {
    final offer = state.value;
    if (offer == null) return null;
    final orderId = await _ds.acceptOffer(offer.id);
    state = const AsyncValue.data(null);
    return orderId;
  }

  Future<void> reject({String? reason}) async {
    final offer = state.value;
    if (offer == null) return;
    await _ds.rejectOffer(offer.id, reason: reason);
    state = const AsyncValue.data(null);
  }

  void refresh() => _load();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
