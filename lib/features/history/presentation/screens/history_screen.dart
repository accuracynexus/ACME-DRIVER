import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/order_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: historyAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No hay entregas',
              subtitle: 'Tu historial de entregas aparecerá aquí.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderHistoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final order = orders[index];
                final delivered =
                    order.assignmentStatus == AssignmentStatus.completed;
                final when = order.completedAt ?? order.assignedAt;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      delivered ? Icons.check_circle : Icons.cancel,
                      color: delivered ? AppColors.success : AppColors.error,
                    ),
                    title: Text(
                      '${order.code} · ${order.branchName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.deliveryAddress,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (when != null)
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(when.toLocal()),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint),
                          ),
                      ],
                    ),
                    trailing: Text(
                      order.deliveryFee.toCurrency,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            delivered ? AppColors.success : AppColors.textHint,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
