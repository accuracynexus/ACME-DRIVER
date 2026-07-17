import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/domain/entities/driver_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../earnings/presentation/providers/earnings_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../orders/presentation/providers/order_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _toggling = false;

  Future<void> _toggleOnline(DriverProfile driver) async {
    if (!driver.isVerified) {
      context.showSnackBar('Tu cuenta requiere aprobación del administrador',
          isError: true);
      return;
    }
    setState(() => _toggling = true);
    try {
      await ref.read(currentDriverProvider.notifier).toggleOnline();
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(currentDriverProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final offers = ref.watch(offersProvider).value ?? [];
    final activeOrder = ref.watch(activeOrderProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: badges.Badge(
              showBadge: unread > 0,
              badgeContent: Text(
                '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go(AppRoutes.notifications),
          ),
        ],
      ),
      body: authState.when(
        data: (driver) {
          if (driver == null) {
            return const Center(child: Text('No se encontró el perfil'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(currentDriverProvider.notifier).refresh();
              ref.invalidate(offersProvider);
              ref.invalidate(orderHistoryProvider);
              ref.invalidate(notificationsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(driver),
                const SizedBox(height: 24),
                _buildStatusCard(driver),
                if (!driver.isVerified) ...[
                  const SizedBox(height: 12),
                  _buildVerificationBanner(),
                ],
                if (activeOrder != null) ...[
                  const SizedBox(height: 16),
                  _buildActiveOrderBanner(activeOrder.code),
                ] else if (offers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildOffersBanner(offers.length),
                ],
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Resumen de hoy',
                  actionLabel: 'Ver detalles',
                  onAction: () => context.go(AppRoutes.earnings),
                ),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Acciones rápidas'),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(DriverProfile driver) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hola,',
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                driver.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(DriverProfile driver) {
    final isOnline = driver.isOnline;
    final statusColor = isOnline
        ? (driver.status == DriverStatus.busy
            ? AppColors.warning
            : AppColors.success)
        : Colors.grey;
    final statusText = isOnline
        ? (driver.status == DriverStatus.busy
            ? 'En una entrega'
            : 'Disponible para recibir pedidos')
        : 'Desconectado - No recibirás pedidos';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mi estado',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isOnline ? driver.status.label : 'Fuera de línea',
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                _toggling
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Switch.adaptive(
                        value: isOnline,
                        activeColor: AppColors.primary,
                        onChanged: (_) => _toggleOnline(driver),
                      ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top, color: AppColors.warning, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu cuenta está en revisión. Podrás conectarte cuando sea aprobada.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderBanner(String code) {
    return _Banner(
      color: AppColors.accent,
      icon: Icons.motorcycle,
      text: 'Tienes una entrega en curso ($code)',
      actionLabel: 'Ver mapa',
      onTap: () => context.go(AppRoutes.activeOrder),
    );
  }

  Widget _buildOffersBanner(int count) {
    return _Banner(
      color: AppColors.primary,
      icon: Icons.delivery_dining,
      text: count == 1
          ? 'Tienes 1 oferta de pedido esperando'
          : 'Tienes $count ofertas de pedido esperando',
      actionLabel: 'Ver ofertas',
      onTap: () => context.go(AppRoutes.availableOrders),
    );
  }

  Widget _buildSummaryCards() {
    final summary = ref.watch(earningsSummaryProvider).value ??
        const EarningsSummary();
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Entregas',
            value: '${summary.todayDeliveries}',
            icon: Icons.delivery_dining,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Ganancias',
            value: summary.today.toCurrency,
            icon: Icons.attach_money,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppColors.surface,
          leading: const Icon(Icons.list_alt, color: AppColors.primary),
          title: const Text('Ver ofertas de pedidos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.availableOrders),
        ),
        const SizedBox(height: 8),
        ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppColors.surface,
          leading: const Icon(Icons.map, color: AppColors.primary),
          title: const Text('Mi pedido activo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.activeOrder),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              actionLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
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

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
