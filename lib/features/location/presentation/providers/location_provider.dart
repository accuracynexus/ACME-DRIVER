import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/location_service.dart';

/// Posición GPS actual del repartidor para pintarla en el mapa.
/// Emite primero la posición actual y luego un stream con los cambios.
final driverPositionProvider = StreamProvider.autoDispose<Position?>((ref) async* {
  if (!await LocationService.ensurePermission()) {
    yield null;
    return;
  }
  yield await LocationService.tryGetPosition();
  yield* LocationService.positionStream();
});

/// Mantiene el envío de ubicación al backend mientras el repartidor está
/// online o tiene un pedido activo. Se activa observándolo desde el shell.
final locationTrackingProvider =
    StateNotifierProvider<LocationTrackingNotifier, bool>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final notifier = LocationTrackingNotifier(client);

  // Reaccionar a cambios de estado del repartidor.
  ref.listen(currentDriverProvider, (prev, next) {
    final driver = next.value;
    final shouldTrack =
        driver != null && (driver.isOnline || driver.currentOrderId != null);
    notifier.setTracking(shouldTrack, orderId: driver?.currentOrderId);
  }, fireImmediately: true);

  ref.onDispose(notifier.stop);
  return notifier;
});

class LocationTrackingNotifier extends StateNotifier<bool> {
  final SupabaseClient _client;
  StreamSubscription<Position>? _sub;
  String? _orderId;

  LocationTrackingNotifier(this._client) : super(false);

  Future<void> setTracking(bool enabled, {String? orderId}) async {
    _orderId = orderId;
    if (enabled == state) return;
    if (enabled) {
      await _start();
    } else {
      stop();
    }
  }

  Future<void> _start() async {
    if (!await LocationService.ensurePermission()) return;
    _sub?.cancel();
    _sub = LocationService.positionStream().listen(_onPosition);
    state = true;
  }

  Future<void> _onPosition(Position pos) async {
    try {
      await _client.rpc(AppConstants.rpcPingLocation, params: {
        'p_lat': pos.latitude,
        'p_lng': pos.longitude,
        'p_order_id': _orderId,
        'p_accuracy': pos.accuracy,
        'p_speed': pos.speed * 3.6, // m/s -> km/h
        'p_heading': pos.heading,
      });
    } catch (_) {
      // best-effort; no interrumpir la app por un ping fallido
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    state = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
