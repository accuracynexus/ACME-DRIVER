import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../providers/earnings_provider.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(earningsSummaryProvider);
    final settlementsAsync = ref.watch(settlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orderHistoryProvider);
          ref.invalidate(settlementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync.when(
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _EarningCard(
                          title: 'Hoy',
                          amount: s.today,
                          deliveries: s.todayDeliveries,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _EarningCard(
                          title: 'Esta semana',
                          amount: s.week,
                          deliveries: s.weekDeliveries,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EarningCard(
                    title: 'Total histórico',
                    amount: s.total,
                    deliveries: s.totalDeliveries,
                    color: AppColors.success,
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Liquidaciones'),
            const SizedBox(height: 8),
            settlementsAsync.when(
              data: (settlements) {
                if (settlements.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Aún no tienes liquidaciones generadas.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                final df = DateFormat('dd/MM');
                return Column(
                  children: settlements
                      .map(
                        (s) => Card(
                          child: ListTile(
                            leading: Icon(
                              s.status == 'paid'
                                  ? Icons.check_circle
                                  : Icons.pending_actions,
                              color: s.status == 'paid'
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            title: Text(
                              '${df.format(s.periodStart)} — ${df.format(s.periodEnd)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                                '${s.deliveriesCount} entregas · ${s.statusLabel}'),
                            trailing: Text(
                              s.netPayable.toCurrency,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningCard extends StatelessWidget {
  final String title;
  final double amount;
  final int deliveries;
  final Color color;

  const _EarningCard({
    required this.title,
    required this.amount,
    required this.deliveries,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              amount.toCurrency,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$deliveries entregas',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
