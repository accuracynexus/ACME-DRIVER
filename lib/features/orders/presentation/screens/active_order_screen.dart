import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/navigation_launcher.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../domain/entities/order.dart';
import '../order_status_ui.dart';
import '../providers/order_provider.dart';
import '../widgets/order_map.dart';

/// Color de marca de Waze (cyan) para el botón de navegación.
const Color _wazeColor = Color(0xFF33CCFF);

class ActiveOrderScreen extends ConsumerStatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  ConsumerState<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends ConsumerState<ActiveOrderScreen> {
  bool _busy = false;

  Future<void> _advance(Order order) async {
    final next = order.status.nextForDriver;
    if (next == null) return;

    // Al confirmar la entrega: pedir evidencia y cobro si es contra entrega.
    if (next == OrderStatus.delivered) {
      final confirmed = await _deliveryFlow(order);
      if (!confirmed) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(activeOrderProvider.notifier).advance();
      await ref.read(currentDriverProvider.notifier).refresh();
      if (next == OrderStatus.delivered && mounted) {
        context.showSnackBar('¡Pedido entregado!');
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Captura foto de evidencia (opcional) y cobro en efectivo (si aplica).
  Future<bool> _deliveryFlow(Order order) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => _DeliverySheet(order: order),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeOrderProvider);
    final driverPos = ref.watch(driverPositionProvider).value;

    return Scaffold(
      body: Column(
        children: [
          const PremiumHeader(
              title: 'Pedido activo', subtitle: 'Sigue los pasos de la entrega'),
          Expanded(
            child: async.when(
        data: (order) {
          if (order == null) {
            return const EmptyState(
              icon: PhosphorIconsRegular.motorcycle,
              title: 'Sin pedido activo',
              subtitle: 'Cuando aceptes una oferta aparecerá aquí.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(activeOrderProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                _statusStepper(order.status),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  // Antes de recoger, se navega al local; luego, al cliente.
                  final goToClient = order.status == OrderStatus.pickedUp ||
                      order.status == OrderStatus.onTheWay ||
                      order.status == OrderStatus.delivered;
                  return OrderMap(
                    branchLat: order.branchLat,
                    branchLng: order.branchLng,
                    clientLat: order.deliveryLat,
                    clientLng: order.deliveryLng,
                    driverLat: driverPos?.latitude,
                    driverLng: driverPos?.longitude,
                    navLat: goToClient ? order.deliveryLat : order.branchLat,
                    navLng: goToClient ? order.deliveryLng : order.branchLng,
                    navLabel: goToClient
                        ? (order.recipientName ?? 'Cliente')
                        : order.branchName,
                  );
                }),
                const SizedBox(height: 16),
                _orderHeader(order),
                const SizedBox(height: 16),
                _locationCard(
                  title: 'Recoger en',
                  name: order.branchName,
                  address: order.branchAddress ?? 'Dirección no disponible',
                  reference: order.branchReference,
                  phone: order.branchPhone,
                  lat: order.branchLat,
                  lng: order.branchLng,
                  icon: PhosphorIconsRegular.storefront,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                _locationCard(
                  title: 'Entregar a',
                  name: order.recipientName ?? 'Cliente',
                  address: order.deliveryAddress,
                  reference: order.deliveryReference,
                  phone: order.recipientPhone,
                  lat: order.deliveryLat,
                  lng: order.deliveryLng,
                  icon: PhosphorIconsFill.mapPin,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Chatear con el cliente',
                  icon: PhosphorIconsFill.chatCircleText,
                  isOutlined: true,
                  onPressed: () => context.push(
                    AppRoutes.orderChat,
                    extra: {
                      'orderId': order.id,
                      'title': order.recipientName ?? 'Cliente',
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _paymentCard(order),
                if (order.specialInstructions != null &&
                    order.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _noteCard(order.specialInstructions!),
                ],
                const SizedBox(height: 24),
                if (order.status.driverActionLabel != null)
                  AppButton(
                    label: order.status.driverActionLabel!,
                    isLoading: _busy,
                    icon: PhosphorIconsBold.arrowRight,
                    onPressed: () => _advance(order),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderHeader(Order order) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Pedido #${order.orderCode}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          StatusBadge(label: order.status.label, color: order.status.color),
        ],
      );

  Widget _statusStepper(OrderStatus status) {
    const steps = [
      OrderStatus.driverAccepted,
      OrderStatus.pickedUp,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ];
    const labels = ['Aceptado', 'Recogido', 'En camino', 'Entregado'];
    final idx = steps.indexOf(status);
    final current = idx < 0 ? (status == OrderStatus.delivered ? 3 : 0) : idx;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(steps.length, (i) {
          final step = steps[i];
          final done = i <= current;
          final isCurrent = i == current;
          final color = step.color;
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= current ? color : AppColors.border),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isCurrent ? 36 : 30,
                      height: isCurrent ? 36 : 30,
                      decoration: BoxDecoration(
                        color: done ? color : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    spreadRadius: 1)
                              ]
                            : null,
                      ),
                      child: Icon(
                        i < current ? PhosphorIconsBold.check : step.icon,
                        size: isCurrent ? 18 : 15,
                        color: done ? Colors.white : AppColors.textHint,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == steps.length - 1
                            ? Colors.transparent
                            : (i < current ? steps[i + 1].color : AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: done ? color : AppColors.textHint)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _locationCard({
    required String title,
    required String name,
    required String address,
    String? reference,
    String? phone,
    double? lat,
    double? lng,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(),
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(PhosphorIconsRegular.mapPin,
                                size: 14, color: AppColors.textHint),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(address,
                                style: context.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                      if (reference != null && reference.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Ref: $reference',
                              style: context.textTheme.bodySmall),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((lat != null && lng != null) ||
              (phone != null && phone.isNotEmpty)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (lat != null && lng != null)
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Maps',
                            icon: PhosphorIconsFill.navigationArrow,
                            onPressed: () => NavigationLauncher.navigateTo(
                                lat, lng,
                                label: name),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Waze',
                            icon: PhosphorIconsFill.car,
                            backgroundColor: _wazeColor,
                            onPressed: () =>
                                NavigationLauncher.navigateWithWaze(lat, lng),
                          ),
                        ),
                      ],
                    ),
                  if (phone != null && phone.isNotEmpty) ...[
                    if (lat != null && lng != null) const SizedBox(height: 8),
                    AppButton(
                      label: 'Llamar',
                      icon: PhosphorIconsRegular.phone,
                      isOutlined: true,
                      onPressed: () => NavigationLauncher.call(phone),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard(Order order) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _row('Subtotal', order.subtotal.toCurrency),
              _row('Envío', order.deliveryFee.toCurrency),
              if (order.tipAmount > 0) _row('Propina', order.tipAmount.toCurrency),
              const Divider(),
              _row('Total', order.total.toCurrency, bold: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (order.mustCollectPayment
                          ? AppColors.warning
                          : AppColors.success)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      order.mustCollectPayment
                          ? PaymentUi.icon(order.paymentMethodCode)
                          : PhosphorIconsRegular.checkCircle,
                      size: 18,
                      color: order.mustCollectPayment
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.mustCollectPayment
                            ? 'Cobrar ${order.total.toCurrency} · ${order.paymentMethodLabel}'
                            : 'Pagado en línea — no cobrar',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _noteCard(String note) => Card(
        color: AppColors.warning.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.note, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(child: Text(note)),
            ],
          ),
        ),
      );

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      );
}

/// Hoja de confirmación de entrega: evidencia + cobro en efectivo.
class _DeliverySheet extends ConsumerStatefulWidget {
  final Order order;
  const _DeliverySheet({required this.order});

  @override
  ConsumerState<_DeliverySheet> createState() => _DeliverySheetState();
}

class _DeliverySheetState extends ConsumerState<_DeliverySheet> {
  bool _uploading = false;
  bool _photoDone = false;

  Future<void> _takePhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 65, maxWidth: 1280);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(orderDataSourceProvider)
          .uploadDeliveryPhoto(widget.order.id, bytes);
      setState(() => _photoDone = true);
    } catch (e) {
      if (mounted) context.showSnackBar('No se pudo subir la foto', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirmar entrega',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Toma una foto como evidencia (recomendado).'),
          const SizedBox(height: 16),
          AppButton(
            label: _photoDone ? 'Foto cargada ✓' : 'Tomar foto de evidencia',
            icon: _photoDone ? PhosphorIconsBold.check : PhosphorIconsRegular.camera,
            isOutlined: true,
            isLoading: _uploading,
            onPressed: _photoDone ? null : _takePhoto,
          ),
          if (order.mustCollectPayment) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(PaymentUi.icon(order.paymentMethodCode),
                      color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Confirma que cobraste ${order.total.toCurrency} vía ${order.paymentMethodLabel}.'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Confirmar entrega',
            onPressed: () async {
              if (order.isCashOnDelivery) {
                try {
                  await ref
                      .read(activeOrderProvider.notifier)
                      .collectCash(order.total);
                } catch (_) {}
              }
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
  }
}
