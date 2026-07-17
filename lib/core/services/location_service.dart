import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../../shared/providers/supabase_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService(ref.watch(supabaseClientProvider));
  ref.onDispose(service.stop);
  return service;
});

/// Envía la ubicación del repartidor al backend (driver_ping_location)
/// mientras esté en línea. También expone la última posición conocida.
class LocationService {
  final SupabaseClient _client;
  Timer? _timer;
  Position? lastPosition;

  /// Si hay un pedido activo, el ping se asocia a ese pedido.
  String? currentOrderId;

  LocationService(this._client);

  bool get isRunning => _timer != null;

  Future<bool> ensurePermission() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await ensurePermission()) return null;
      lastPosition = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return lastPosition;
    } catch (e) {
      debugPrint('LocationService.getCurrentPosition: $e');
      return lastPosition;
    }
  }

  /// Inicia el envío periódico de ubicación.
  void start() {
    stop();
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.locationUpdateInterval),
      (_) => _ping(),
    );
    _ping();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    try {
      final pos = await getCurrentPosition();
      if (pos == null) return;
      await _client.rpc('driver_ping_location', params: {
        'p_lat': pos.latitude,
        'p_lng': pos.longitude,
        'p_accuracy': pos.accuracy,
        'p_speed': pos.speed * 3.6, // m/s -> km/h
        'p_heading': pos.heading,
        if (currentOrderId != null) 'p_order_id': currentOrderId,
      });
    } catch (e) {
      debugPrint('LocationService.ping: $e');
    }
  }
}
