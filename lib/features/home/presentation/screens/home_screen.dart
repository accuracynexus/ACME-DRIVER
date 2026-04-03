import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../auth/domain/entities/driver_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentDriverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: authState.when(
        data: (driver) {
          if (driver == null) return const Center(child: Text('Error: No driver profile found'));
          
          return RefreshIndicator(
            onRefresh: () async {
              // Add refresh logic here
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(driver.fullName),
                const SizedBox(height: 24),
                const SizedBox(height: 24),
                _buildStatusCard(context, ref, driver),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Resumen de hoy',
                  actionLabel: 'Ver detalles',
                  onAction: () => context.go(AppRoutes.earnings),
                ),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Acciones rápidas',
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hola,',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, WidgetRef ref, DriverProfile driver) {
    final isOnline = driver.status == DriverStatus.available;
    final statusColor = isOnline ? AppColors.success : Colors.grey;
    final statusText = isOnline
        ? 'Disponible para recibir pedidos'
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isOnline ? 'En línea' : 'Fuera de línea',
                      style: TextStyle(
                        fontSize: 14,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: isOnline,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (!driver.isActive) {
                      context.showSnackBar(
                          'Tu cuenta requiere aprobación del administrador',
                          isError: true);
                      return;
                    }
                    ref.read(currentDriverProvider.notifier).toggleStatus();
                  },
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

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Entregas',
            value: '4',
            icon: Icons.delivery_dining,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Ganancias',
            value: 'S/ 45.00',
            icon: Icons.attach_money,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppColors.surface,
          leading: const Icon(Icons.list_alt, color: AppColors.primary),
          title: const Text('Ver pedidos disponibles'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(AppRoutes.availableOrders),
        ),
        const SizedBox(height: 8),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                fontSize: 24,
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
