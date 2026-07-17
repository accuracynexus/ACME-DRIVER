import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../../domain/entities/settlement.dart';
import '../providers/earnings_provider.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todaySummaryProvider).value;
    final settlementsAsync = ref.watch(settlementsProvider);

    return Scaffold(
      body: Column(
        children: [
          const PremiumHeader(
              title: 'Ganancias', subtitle: 'Tus pagos y liquidaciones'),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(todaySummaryProvider);
                ref.invalidate(settlementsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                children: [
            _todayCard(today?.deliveries ?? 0, today?.earnings ?? 0),
            const SizedBox(height: 24),
            Text('Liquidaciones',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            settlementsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: PhosphorIconsRegular.wallet,
                    title: 'Sin liquidaciones',
                    subtitle: 'Tus pagos por periodo aparecerán aquí.',
                  );
                }
                return Column(
                    children: items.map((s) => _SettlementTile(s: s)).toList());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(int deliveries, double earnings) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x334D148C), blurRadius: 22, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsFill.wallet,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Ganancias de hoy',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Text(earnings.toCurrency,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsFill.motorcycle,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text('$deliveries entregas completadas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SettlementTile extends StatelessWidget {
  final Settlement s;
  const _SettlementTile({required this.s});

  @override
  Widget build(BuildContext context) {
    final color = switch (s.status) {
      SettlementStatus.paid => AppColors.success,
      SettlementStatus.generated => AppColors.warning,
      SettlementStatus.cancelled => AppColors.error,
      SettlementStatus.draft => AppColors.textSecondary,
    };
    final fmt = DateFormat('dd MMM', 'es');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${fmt.format(s.periodStart)} - ${fmt.format(s.periodEnd)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                StatusBadge(label: s.status.label, color: color),
              ],
            ),
            const SizedBox(height: 12),
            _row('Entregas', '${s.deliveriesCount}'),
            _row('Bruto', s.grossEarnings.toCurrency),
            if (s.bonuses > 0) _row('Bonos', '+ ${s.bonuses.toCurrency}'),
            if (s.penalties > 0) _row('Penalidades', '- ${s.penalties.toCurrency}'),
            if (s.cashCollected > 0)
              _row('Efectivo cobrado', s.cashCollected.toCurrency),
            const Divider(),
            _row('Neto a pagar', s.netPayable.toCurrency, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: bold ? AppColors.primary : null)),
          ],
        ),
      );
}
