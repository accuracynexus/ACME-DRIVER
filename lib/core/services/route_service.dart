import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final routeServiceProvider = Provider<RouteService>((ref) => RouteService());

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get etaLabel {
    final min = (durationSeconds / 60).ceil();
    return min < 60 ? '$min min' : '${min ~/ 60} h ${min % 60} min';
  }
}

/// Calcula rutas por calles con el servidor público de OSRM (sin API key).
/// Si falla, la UI cae a una línea recta.
class RouteService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  LatLng? _lastOrigin;
  LatLng? _lastTarget;
  RouteResult? _lastResult;

  static const _distance = Distance();

  /// Devuelve la ruta origen→destino. Reutiliza la última respuesta si el
  /// origen se movió menos de [refreshMeters] y el destino no cambió.
  Future<RouteResult?> getRoute(
    LatLng origin,
    LatLng target, {
    double refreshMeters = 40,
  }) async {
    if (_lastResult != null &&
        _lastTarget == target &&
        _lastOrigin != null &&
        _distance.as(LengthUnit.Meter, _lastOrigin!, origin) < refreshMeters) {
      return _lastResult;
    }

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${target.longitude},${target.latitude}'
          '?overview=full&geometries=geojson';
      final res = await _dio.get(url);
      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _lastResult;

      final route = routes.first;
      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      _lastOrigin = origin;
      _lastTarget = target;
      _lastResult = RouteResult(
        points: coords,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
      return _lastResult;
    } catch (e) {
      debugPrint('RouteService: $e');
      return _lastResult;
    }
  }

  void clear() {
    _lastOrigin = null;
    _lastTarget = null;
    _lastResult = null;
  }
}
