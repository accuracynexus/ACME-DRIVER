import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../domain/entities/order.dart';

/// Indica al repartidor, sin ambigüedad, si debe cobrar este pedido.
/// Es la única fuente de verdad visual del cobro: se usa igual en la oferta
/// y en la entrega activa para que el mensaje nunca cambie a mitad del viaje.
class PaymentBanner extends StatelessWidget {
  final DeliveryOrder order;

  /// Versión compacta para la tarjeta de oferta.
  final bool compact;

  const PaymentBanner({
    super.key,
    required this.order,
    this.compact = false,
  });

  Color get _color {
    switch (order.paymentAction) {
      case PaymentAction.collectOnDelivery:
        return AppColors.warning;
      case PaymentAction.paidOnline:
      case PaymentAction.alreadyPaid:
        return AppColors.success;
      case PaymentAction.unconfirmed:
        return AppColors.info;
    }
  }

  IconData get _icon {
    switch (order.paymentAction) {
      case PaymentAction.collectOnDelivery:
        return Icons.payments_outlined;
      case PaymentAction.paidOnline:
      case PaymentAction.alreadyPaid:
        return Icons.check_circle_outline;
      case PaymentAction.unconfirmed:
        return Icons.help_outline;
    }
  }

  String get _title {
    final method = order.paymentMethodName.isNotEmpty
        ? ' (${order.paymentMethodName})'
        : '';
    switch (order.paymentAction) {
      case PaymentAction.collectOnDelivery:
        return 'COBRAR ${order.total.toCurrency}$method';
      case PaymentAction.paidOnline:
        return 'Pagado en línea$method — no cobrar';
      case PaymentAction.alreadyPaid:
        return 'Pedido pagado$method — no cobrar';
      case PaymentAction.unconfirmed:
        return 'Pago sin confirmar — no cobres';
    }
  }

  String? get _subtitle {
    switch (order.paymentAction) {
      case PaymentAction.collectOnDelivery:
        return 'Cobra el total al entregar.';
      case PaymentAction.paidOnline:
        return 'El cliente ya pagó al hacer el pedido.';
      case PaymentAction.alreadyPaid:
        return null;
      case PaymentAction.unconfirmed:
        return 'Este pedido (${order.total.toCurrency}) no tiene método de pago '
            'registrado. Consulta con soporte antes de cobrar.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Icon(_icon, size: 18, color: _color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (_subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
