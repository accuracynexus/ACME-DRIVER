import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/order_status_ui.dart';
import '../../../orders/presentation/providers/order_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderHistoryProvider);

    return Scaffold(
      body: Column(
        children: [
          const PremiumHeader(
              title: 'Historial', subtitle: 'Tus entregas completadas'),
          Expanded(
            child: async.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const EmptyState(
                    icon: PhosphorIconsRegular.clockCounterClockwise,
                    title: 'Sin entregas',
                    subtitle: 'Tus entregas completadas aparecerán aquí.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(orderHistoryProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _HistoryTile(order: orders[i]),
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
}

class _HistoryTile extends StatelessWidget {
  final Order order;
  const _HistoryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final delivered = order.status == OrderStatus.delivered;
    final color = order.status.color;
    final date = order.deliveredAt ?? order.cancelledAt ?? order.createdAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(order.status.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('#${order.orderCode}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
              StatusBadge(label: order.status.label, color: color),
            ],
          ),
          const SizedBox(height: 12),
          InfoTile(
              icon: PhosphorIconsRegular.storefront,
              title: 'Local',
              value: order.branchName),
          const SizedBox(height: 8),
          InfoTile(
              icon: PhosphorIconsFill.mapPin,
              title: 'Entrega',
              value: order.deliveryAddress,
              iconColor: AppColors.accent),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.clock,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(DateFormat('dd MMM yyyy · HH:mm', 'es').format(date),
                      style: context.textTheme.bodySmall),
                ],
              ),
              if (delivered)
                Text('+ ${order.driverEarning.toCurrency}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                        fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}
