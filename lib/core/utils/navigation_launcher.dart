import 'package:url_launcher/url_launcher.dart';

/// Lanza navegación externa (Google Maps / Waze) y llamadas telefónicas.
/// No requiere API key de Google Maps.
class NavigationLauncher {
  NavigationLauncher._();

  /// Abre Google Maps con navegación hacia el destino.
  static Future<bool> navigateTo(double lat, double lng, {String? label}) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    return _launch(uri);
  }

  /// Abre Waze hacia el destino (si está instalado).
  static Future<bool> navigateWithWaze(double lat, double lng) async {
    final uri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    return _launch(uri);
  }

  /// Realiza una llamada telefónica.
  static Future<bool> call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return false;
    return _launch(Uri.parse('tel:$cleaned'));
  }

  /// Abre WhatsApp con el número indicado.
  static Future<bool> whatsapp(String phone, {String? message}) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return false;
    final msg = message != null ? '?text=${Uri.encodeComponent(message)}' : '';
    return _launch(Uri.parse('https://wa.me/$cleaned$msg'));
  }

  static Future<bool> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
