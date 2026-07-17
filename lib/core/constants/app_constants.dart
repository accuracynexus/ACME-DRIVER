class AppConstants {
  AppConstants._();

  static const String appName = 'ACME-DRIVER';
  static const String appVersion = '1.0.0';

  // Intervalo de envío de ubicación (segundos)
  static const int locationUpdateInterval = 10;

  // Intervalo de refresco de ofertas/pedido activo (segundos)
  static const int ordersPollInterval = 12;

  // Intervalo de refresco de notificaciones in-app (segundos)
  static const int notificationsPollInterval = 25;

  // Paginación
  static const int pageSize = 20;
}
