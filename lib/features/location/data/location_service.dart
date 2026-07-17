import 'package:geolocator/geolocator.dart';

/// Servicio de ubicación basado en geolocator. Métodos tolerantes a fallos:
/// si no hay permiso o el GPS está apagado, devuelven null en lugar de lanzar.
class LocationService {
  LocationService._();

  static Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  static Future<Position?> tryGetPosition() async {
    try {
      if (!await ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream de posiciones con filtro de distancia (metros).
  static Stream<Position> positionStream({int distanceFilter = 25}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
