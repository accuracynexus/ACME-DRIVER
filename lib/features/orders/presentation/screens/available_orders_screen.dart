import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../providers/order_provider.dart';

class AvailableOrdersScreen extends ConsumerWidget {
  const AvailableOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);
    final driver = ref.watch(currentDriverProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas de Pedidos')),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            final offline = driver != null && !driver.isOnline;
            return EmptyState(
              icon: offline ? Icons.wifi_off : Icons.inbox_outlined,
              title: offline ? 'Estás desconectado' : 'No hay ofertas',
              subtitle: offline
                  ? 'Conéctate desde Inicio para recibir pedidos.'
                  : 'Cuando te asignen un pedido aparecerá aquí.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(offersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _OfferCard(offer: offers[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  final DeliveryOrder offer;

  const _OfferCard({required this.offer});

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(activeOrderProvider.notifier).acceptOffer(widget.offer);
      if (mounted) {
        context.showSnackBar('Pedido aceptado');
        context.go(AppRoutes.activeOrder);
      }
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(activeOrderProvider.notifier)
          .rejectOffer(widget.offer, reason: 'Rechazado por el repartidor');
      if (mounted) context.showSnackBar('Oferta rechazada');
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  offer.code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  offer.deliveryFee.toCurrency,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (offer.assignedAt != null)
              Text(
                'Ofertado ${timeago.format(offer.assignedAt!, locale: 'es')}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            const SizedBox(height: 16),
            InfoTile(
              icon: Icons.store,
              title: 'Recojo',
              value: offer.branchName,
            ),
            const SizedBox(height: 8),
            InfoTile(
              icon: Icons.flag,
              title: 'Entrega',
              value: offer.deliveryAddress,
              iconColor: AppColors.accent,
            ),
            if (offer.estimatedDistanceKm != null) ...[
              const SizedBox(height: 8),
              InfoTile(
                icon: Icons.route,
                title: 'Distancia estimada',
                value:
                    '${offer.estimatedDistanceKm!.toStringAsFixed(1)} km'
                    '${offer.estimatedTimeMin != null ? ' · ${offer.estimatedTimeMin} min' : ''}',
                iconColor: AppColors.info,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _accept,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceptar Pedido'),
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
