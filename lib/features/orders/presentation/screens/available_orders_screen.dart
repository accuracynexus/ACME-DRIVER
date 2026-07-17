import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order.dart';
import '../order_status_ui.dart';
import '../providers/order_provider.dart';
import '../widgets/offer_card.dart';

class AvailableOrdersScreen extends ConsumerStatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  ConsumerState<AvailableOrdersScreen> createState() =>
      _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends ConsumerState<AvailableOrdersScreen> {
  bool _processing = false;

  Future<void> _accept() async {
    setState(() => _processing = true);
    try {
      await ref.read(pendingOfferProvider.notifier).accept();
      await ref.read(activeOrderProvider.notifier).refresh();
      await ref.read(currentDriverProvider.notifier).refresh();
      if (mounted) context.go(AppRoutes.activeOrder);
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _processing = true);
    try {
      await ref.read(pendingOfferProvider.notifier).reject();
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider).value;
    final offer = ref.watch(pendingOfferProvider).value;
    final active = ref.watch(activeOrderProvider).value;
    final online = driver?.isOnline == true;

    return Scaffold(
      body: Column(
        children: [
          const PremiumHeader(
              title: 'Mis pedidos', subtitle: 'Ofertas y entrega en curso'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
              children: [
                if (offer != null)
                  OfferCard(
                    offer: offer,
                    processing: _processing,
                    onAccept: _accept,
                    onReject: _reject,
                  ),
                if (active != null) ...[
                  if (offer != null) const SizedBox(height: 16),
                  _ActiveTile(
                    code: active.orderCode,
                    status: active.status.label,
                    icon: active.status.icon,
                    onTap: () => context.go(AppRoutes.activeOrder),
                  ),
                ],
                if (offer == null && active == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: EmptyState(
                      icon: online
                          ? PhosphorIconsRegular.hourglassMedium
                          : PhosphorIconsBold.power,
                      title: online
                          ? 'Esperando pedidos'
                          : 'Estás desconectado',
                      subtitle: online
                          ? 'Los pedidos se asignan automáticamente según tu cercanía y carga. Te avisaremos cuando llegue uno.'
                          : 'Conéctate desde el inicio para empezar a recibir pedidos.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTile extends StatelessWidget {
  final int code;
  final String status;
  final IconData icon;
  final VoidCallback onTap;
  const _ActiveTile(
      {required this.code,
      required this.status,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pedido activo #$code',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  Text(status,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13)),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
