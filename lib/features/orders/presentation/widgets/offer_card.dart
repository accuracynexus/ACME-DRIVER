import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_assignment.dart';
import '../order_status_ui.dart';

/// Tarjeta de oferta de pedido con cuenta regresiva.
class OfferCard extends StatefulWidget {
  final OrderAssignment offer;
  final bool processing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    this.processing = false,
  });

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  Timer? _timer;
  int _left = AppConstants.offerTimeoutSeconds;

  @override
  void initState() {
    super.initState();
    _left = widget.offer.secondsLeft(AppConstants.offerTimeoutSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = widget.offer.secondsLeft(AppConstants.offerTimeoutSeconds);
      if (mounted) setState(() => _left = left);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.offer.order;
    final progress = _left / AppConstants.offerTimeoutSeconds;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsFill.bellRinging, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('¡Nuevo pedido!',
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                _Countdown(left: _left, progress: progress),
              ],
            ),
            const SizedBox(height: 16),
            if (order != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pedido #${order.orderCode}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(order.driverEarning.toCurrency,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              InfoTile(
                  icon: PhosphorIconsRegular.storefront,
                  title: 'Recojo',
                  value: order.branchName),
              const SizedBox(height: 8),
              InfoTile(
                icon: PhosphorIconsFill.mapPin,
                title: 'Entrega',
                value: order.deliveryAddress,
                iconColor: AppColors.accent,
              ),
              if (order.estimatedDistanceKm != null) ...[
                const SizedBox(height: 8),
                Text(
                  '≈ ${order.estimatedDistanceKm!.toStringAsFixed(1)} km · '
                  '${order.estimatedTimeMin ?? GeoUtils.etaMinutes(order.estimatedDistanceKm!)} min',
                  style: context.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 10),
              _PaymentPill(order: order),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Rechazar',
                    isOutlined: true,
                    onPressed: widget.processing ? null : widget.onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Aceptar',
                    isLoading: widget.processing,
                    onPressed: _left <= 0 ? null : widget.onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla que indica si el repartidor debe cobrar (y con qué método:
/// efectivo, Yape, Plin, tarjeta POS) o si el pedido ya está pagado online.
class _PaymentPill extends StatelessWidget {
  final Order order;
  const _PaymentPill({required this.order});

  @override
  Widget build(BuildContext context) {
    final collect = order.mustCollectPayment;
    final color = collect ? AppColors.warning : AppColors.success;
    final icon = collect
        ? PaymentUi.icon(order.paymentMethodCode)
        : PhosphorIconsRegular.checkCircle;
    final text = collect
        ? 'Cobrar ${order.total.toCurrency} · ${order.paymentMethodLabel}'
        : 'Pagado en línea — no cobrar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final int left;
  final double progress;
  const _Countdown({required this.left, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 4,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
                left <= 10 ? AppColors.error : AppColors.accent),
          ),
          Text('$left', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
