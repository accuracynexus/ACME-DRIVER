import 'package:flutter_test/flutter_test.dart';
import 'package:acme_driver/features/orders/data/datasources/order_model.dart';
import 'package:acme_driver/features/orders/domain/entities/order.dart';

/// Construye una fila de `order_assignments` como la que devuelve Supabase.
Map<String, dynamic> assignmentJson({
  required String paymentStatus,
  Map<String, dynamic>? paymentMethod,
}) {
  return {
    'id': 'assignment-1',
    'status': 'assigned',
    'assigned_at': '2026-08-18T10:00:00Z',
    'order': {
      'id': 'order-1',
      'order_code': 1021,
      'status': 'assigned',
      'subtotal': 20.45,
      'delivery_fee': 5.00,
      'total': 25.45,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'branch': {'name': 'Local', 'lat': -12.785, 'lng': -74.970},
      'delivery': {
        'address_snapshot': 'Jr. Test 100',
        'lat': -12.789,
        'lng': -74.972,
        'recipient_name': 'Cliente',
        'recipient_phone': '999888777',
      },
      'items': [],
    },
  };
}

DeliveryOrder parse({
  required String paymentStatus,
  Map<String, dynamic>? paymentMethod,
}) =>
    DeliveryOrderModel.fromAssignmentJson(
      assignmentJson(
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
      ),
    );

// Métodos tal como están en la tabla payment_methods.
const cash = {'code': 'cash', 'name': 'Efectivo', 'is_online': false};
const cardPos = {
  'code': 'card_pos',
  'name': 'Tarjeta contra entrega',
  'is_online': false
};
const cardOnline = {
  'code': 'card_online',
  'name': 'Tarjeta online',
  'is_online': true
};
const yape = {'code': 'yape', 'name': 'Yape', 'is_online': true};
const plin = {'code': 'plin', 'name': 'Plin', 'is_online': true};

void main() {
  group('Se cobra únicamente contra entrega y sin pagar', () {
    test('efectivo pendiente → cobrar', () {
      final order = parse(paymentStatus: 'pending', paymentMethod: cash);
      expect(order.paymentAction, PaymentAction.collectOnDelivery);
      expect(order.mustCollectPayment, isTrue);
    });

    test('tarjeta POS pendiente → cobrar', () {
      final order = parse(paymentStatus: 'pending', paymentMethod: cardPos);
      expect(order.paymentAction, PaymentAction.collectOnDelivery);
    });

    test('efectivo ya pagado → no cobrar', () {
      final order = parse(paymentStatus: 'paid', paymentMethod: cash);
      expect(order.paymentAction, PaymentAction.alreadyPaid);
      expect(order.mustCollectPayment, isFalse);
    });
  });

  group('Métodos en línea (Culqi) nunca se cobran al entregar', () {
    // El webhook de Culqi hoy no actualiza orders.payment_status, así que
    // estos pedidos llegan como 'pending' aunque el cliente ya pagó.
    for (final method in [cardOnline, yape, plin]) {
      test('${method['code']} pendiente → no cobrar', () {
        final order = parse(paymentStatus: 'pending', paymentMethod: method);
        expect(order.paymentAction, PaymentAction.paidOnline);
        expect(order.mustCollectPayment, isFalse,
            reason: 'cobrar ${method['code']} le cobraría dos veces al cliente');
      });

      test('${method['code']} pagado → no cobrar', () {
        final order = parse(paymentStatus: 'paid', paymentMethod: method);
        expect(order.mustCollectPayment, isFalse);
      });
    }
  });

  group('Pedido sin método de pago registrado', () {
    // Caso real: los pedidos #1017–#1021 se crearon con payment_method_id NULL.
    test('método nulo → verificar, nunca cobrar', () {
      final order = parse(paymentStatus: 'pending', paymentMethod: null);
      expect(order.paymentAction, PaymentAction.unconfirmed);
      expect(order.mustCollectPayment, isFalse,
          reason: 'sin método registrado no se puede afirmar que deba cobrar');
    });

    test('método nulo pero pagado → pagado', () {
      final order = parse(paymentStatus: 'paid', paymentMethod: null);
      expect(order.paymentAction, PaymentAction.alreadyPaid);
    });
  });

  test('el total se conserva para mostrarlo al repartidor', () {
    final order = parse(paymentStatus: 'pending', paymentMethod: cash);
    expect(order.total, 25.45);
    expect(order.paymentMethodName, 'Efectivo');
  });
}
