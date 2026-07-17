import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/entities/order.dart';

/// Capa de presentación del estado del pedido: color e ícono consistentes
/// para badges, steppers y banners en toda la app. Usa la paleta `orderXxx`
/// definida en [AppColors] para que el color-código sea uniforme.
extension OrderStatusUI on OrderStatus {
  Color get color {
    switch (this) {
      case OrderStatus.pendingPayment:
        return AppColors.textHint;
      case OrderStatus.placed:
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.warning;
      case OrderStatus.readyForPickup:
        return AppColors.orderAssigned;
      case OrderStatus.assigned:
        return AppColors.orderAssigned;
      case OrderStatus.driverAccepted:
        return AppColors.orderAccepted;
      case OrderStatus.pickedUp:
        return AppColors.orderPickedUp;
      case OrderStatus.onTheWay:
        return AppColors.orderOnTheWay;
      case OrderStatus.delivered:
        return AppColors.orderDelivered;
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return AppColors.orderCancelled;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pendingPayment:
        return PhosphorIconsRegular.creditCard;
      case OrderStatus.placed:
        return PhosphorIconsRegular.receipt;
      case OrderStatus.confirmed:
        return PhosphorIconsRegular.checkCircle;
      case OrderStatus.preparing:
        return PhosphorIconsRegular.cookingPot;
      case OrderStatus.readyForPickup:
        return PhosphorIconsRegular.bagSimple;
      case OrderStatus.assigned:
        return PhosphorIconsRegular.bellRinging;
      case OrderStatus.driverAccepted:
        return PhosphorIconsRegular.handshake;
      case OrderStatus.pickedUp:
        return PhosphorIconsRegular.package;
      case OrderStatus.onTheWay:
        return PhosphorIconsRegular.motorcycle;
      case OrderStatus.delivered:
        return PhosphorIconsRegular.flagCheckered;
      case OrderStatus.cancelled:
        return PhosphorIconsRegular.xCircle;
      case OrderStatus.failed:
        return PhosphorIconsRegular.warningCircle;
    }
  }
}

/// Íconos por método de pago (efectivo, Yape, Plin, tarjeta) para mostrar
/// de forma consistente cuánto y cómo debe cobrar el repartidor.
class PaymentUi {
  const PaymentUi._();

  static IconData icon(String methodCode) {
    switch (methodCode) {
      case 'yape':
      case 'plin':
        return PhosphorIconsFill.deviceMobile;
      case 'card_pos':
        return PhosphorIconsFill.creditCard;
      case 'card_online':
        return PhosphorIconsRegular.creditCard;
      case 'cash':
      default:
        return PhosphorIconsFill.money;
    }
  }
}
