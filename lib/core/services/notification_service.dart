import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Notificaciones locales del dispositivo (sonido/banner) para avisar
/// nuevas ofertas de pedido y actualizaciones aunque la app esté en segundo plano.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'acme_driver_orders',
    'Pedidos',
    description: 'Ofertas de pedidos y actualizaciones de entrega',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(initSettings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.initialize: $e');
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.recommendation,
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService.show: $e');
    }
  }

  Future<void> showNewOffer(String orderCode, double deliveryFee) {
    return show(
      id: orderCode.hashCode & 0x7fffffff,
      title: '🛵 Nuevo pedido disponible',
      body:
          'Pedido $orderCode — ganancia S/ ${deliveryFee.toStringAsFixed(2)}. Toca para verlo.',
    );
  }
}
