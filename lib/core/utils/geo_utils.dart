import 'dart:math';

/// Utilidades geográficas (distancia Haversine y ETA aproximado).
class GeoUtils {
  GeoUtils._();

  /// Distancia en kilómetros entre dos coordenadas (Haversine).
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// ETA aproximado en minutos asumiendo velocidad urbana media (km/h).
  static int etaMinutes(double distanceKm, {double speedKmh = 25}) {
    if (distanceKm <= 0) return 0;
    return (distanceKm / speedKmh * 60).round();
  }

  static double _toRad(double deg) => deg * pi / 180;
}
