import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../auth/domain/entities/driver_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../earnings/presentation/providers/earnings_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../orders/presentation/order_status_ui.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../orders/presentation/widgets/offer_card.dart';
import '../../../location/presentation/providers/location_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _processingOffer = false;
  bool _togglingOnline = false;

  Future<void> _acceptOffer() async {
    setState(() => _processingOffer = true);
    try {
      await ref.read(pendingOfferProvider.notifier).accept();
      await ref.read(activeOrderProvider.notifier).refresh();
      await ref.read(currentDriverProvider.notifier).refresh();
      if (mounted) context.go(AppRoutes.activeOrder);
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processingOffer = false);
    }
  }

  Future<void> _rejectOffer() async {
    setState(() => _processingOffer = true);
    try {
      await ref.read(pendingOfferProvider.notifier).reject();
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processingOffer = false);
    }
  }

  Future<void> _toggleOnline() async {
    setState(() => _togglingOnline = true);
    try {
      await ref.read(currentDriverProvider.notifier).toggleOnline();
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(locationTrackingProvider);

    final driverAsync = ref.watch(currentDriverProvider);
    final offer = ref.watch(pendingOfferProvider).value;
    final activeOrder = ref.watch(activeOrderProvider).value;
    final summary = ref.watch(todaySummaryProvider).value;
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      body: driverAsync.when(
        data: (driver) {
          if (driver == null) {
            return const Center(child: Text('No se encontró el perfil'));
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(todaySummaryProvider);
              await ref.read(activeOrderProvider.notifier).refresh();
              await ref.read(currentDriverProvider.notifier).refresh();
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _hero(driver, unread),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      children: [
                        _statusCard(driver),
                        if (offer != null) ...[
                          const SizedBox(height: 16),
                          OfferCard(
                            offer: offer,
                            processing: _processingOffer,
                            onAccept: _acceptOffer,
                            onReject: _rejectOffer,
                          ),
                        ],
                        if (activeOrder != null) ...[
                          const SizedBox(height: 16),
                          _ActiveOrderBanner(
                            order: activeOrder,
                            onTap: () => context.go(AppRoutes.activeOrder),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Resumen de hoy',
                              style: context.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 12),
                        _summaryCards(
                            summary?.deliveries ?? 0, summary?.earnings ?? 0),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Acciones rápidas',
                              style: context.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 12),
                        _quickActions(offer != null, activeOrder),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _hero(DriverProfile d, int unread) => Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 44),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    image: d.avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(d.avatarUrl!), fit: BoxFit.cover)
                        : const DecorationImage(
                            image: AssetImage(AppAssets.iconMark), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola,',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13)),
                      Text(
                        d.fullName.isEmpty ? 'Repartidor' : d.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                _ratingChip(d.ratingAvg),
                const SizedBox(width: 4),
                _bell(unread),
              ],
            ),
          ),
        ),
      );

  Widget _ratingChip(double rating) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsFill.star, color: Colors.white, size: 15),
            const SizedBox(width: 4),
            Text(rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );

  Widget _bell(int unread) => Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.notifications),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                    unread > 0
                        ? PhosphorIconsFill.bellRinging
                        : PhosphorIconsRegular.bell,
                    color: Colors.white,
                    size: 22),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDark, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('${unread > 9 ? '9+' : unread}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );

  Widget _statusCard(DriverProfile d) {
    final online = d.isOnline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: online ? AppColors.accentGradient : null,
        color: online ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: online ? Colors.transparent : AppColors.border),
        boxShadow: [
          BoxShadow(
              color: online ? const Color(0x33FF6200) : AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: online
                  ? Colors.white.withValues(alpha: 0.22)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(PhosphorIconsBold.power,
                color: online ? Colors.white : AppColors.textHint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? 'Estás en línea' : 'Desconectado',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: online ? Colors.white : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    online
                        ? 'Recibiendo pedidos cercanos'
                        : 'Conéctate para recibir pedidos',
                    style: TextStyle(
                        fontSize: 13,
                        color: online
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary)),
              ],
            ),
          ),
          _togglingOnline
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: online ? Colors.white : AppColors.primary),
                )
              : Switch.adaptive(
                  value: online,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  onChanged: (_) => _toggleOnline(),
                ),
        ],
      ),
    );
  }

  Widget _summaryCards(int deliveries, double earnings) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
                title: 'Entregas hoy',
                value: '$deliveries',
                icon: PhosphorIconsFill.motorcycle,
                color: AppColors.info),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryCard(
                title: 'Ganancias hoy',
                value: earnings.toCurrency,
                icon: PhosphorIconsFill.coins,
                color: AppColors.success),
          ),
        ],
      );

  Widget _quickActions(bool hasOffer, Order? activeOrder) => Column(
        children: [
          _QuickActionTile(
            icon: PhosphorIconsFill.listChecks,
            label: 'Ver ofertas de pedidos',
            subtitle: hasOffer
                ? 'Tienes una oferta esperando'
                : 'Sin ofertas por ahora',
            color: AppColors.primary,
            highlighted: hasOffer,
            showDot: hasOffer,
            onTap: () => context.go(AppRoutes.availableOrders),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: PhosphorIconsFill.mapPinLine,
            label: 'Mi pedido activo',
            subtitle: activeOrder != null
                ? 'En curso · ${activeOrder.status.label}'
                : 'Sin pedido activo',
            color: AppColors.accent,
            highlighted: activeOrder != null,
            showDot: activeOrder != null,
            muted: activeOrder == null,
            onTap: () => context.go(
                activeOrder != null ? AppRoutes.activeOrder : AppRoutes.availableOrders),
          ),
        ],
      );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool highlighted;
  final bool showDot;
  final bool muted;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlighted = false,
    this.showDot = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? color.withValues(alpha: 0.06) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? color.withValues(alpha: 0.35)
                  : AppColors.border,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: muted ? 0.08 : 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon,
                        color: muted ? AppColors.textHint : color, size: 22),
                  ),
                  if (showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: highlighted ? color : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsBold.caretRight,
                  color: AppColors.textHint, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Banner del pedido activo en Inicio, con animaciones "en vivo":
/// halo pulsante alrededor del ícono, leve bamboleo del ícono y chevrons
/// que fluyen hacia la derecha indicando que el pedido está en movimiento.
class _ActiveOrderBanner extends StatefulWidget {
  final Order order;
  final VoidCallback onTap;
  const _ActiveOrderBanner({required this.order, required this.onTap});

  @override
  State<_ActiveOrderBanner> createState() => _ActiveOrderBannerState();
}

class _ActiveOrderBannerState extends State<_ActiveOrderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            // Ícono con halo pulsante + bamboleo.
            SizedBox(
              width: 52,
              height: 52,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final t = _c.value;
                  // Vaivén horizontal (como si manejara) + brinquitos verticales.
                  final dx = math.sin(t * 2 * math.pi) * 5.0;
                  final dy = -(math.sin(t * 4 * math.pi).abs()) * 2.5;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo pulsante que se expande y se desvanece.
                      Transform.scale(
                        scale: 1.0 + t * 0.9,
                        child: Opacity(
                          opacity: (1.0 - t) * 0.4,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // Ícono sin fondo, moviéndose solo.
                      Transform.translate(
                        offset: Offset(dx, dy),
                        child: Icon(order.status.icon,
                            color: Colors.white, size: 30),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('Pedido activo #${order.orderCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                      const SizedBox(width: 8),
                      _LivePill(controller: _c),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(order.status.label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13)),
                ],
              ),
            ),
            // Chevrons que fluyen hacia la derecha.
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final d = (t - i / 3.0).abs();
                    final opacity = (1.0 - d * 2.0).clamp(0.25, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: const SizedBox(
                        width: 13,
                        child: Icon(PhosphorIconsBold.caretRight,
                            color: Colors.white, size: 16),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla "EN VIVO" con punto que parpadea.
class _LivePill extends StatelessWidget {
  final AnimationController controller;
  const _LivePill({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final pulse = 0.4 + (math.sin(controller.value * 2 * math.pi) * 0.5 + 0.5) * 0.6;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: pulse),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          const Text('EN VIVO',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
