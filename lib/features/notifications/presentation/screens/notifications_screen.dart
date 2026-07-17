import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            title: 'Notificaciones',
            subtitle: 'Avisos de tus pedidos',
            showBack: true,
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
          ),
          Expanded(
            child: async.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: PhosphorIconsRegular.bellSlash,
                    title: 'Sin notificaciones',
                    subtitle: 'Aquí verás los avisos de tus pedidos.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, 18, 16, 24 + MediaQuery.of(context).padding.bottom + 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? AppColors.surface
                              : AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: n.isRead
                                  ? AppColors.border
                                  : AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(PhosphorIconsFill.package,
                                  color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title ?? 'Notificación',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  if (n.body != null) ...[
                                    const SizedBox(height: 2),
                                    Text(n.body!,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13)),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                      timeago.format(n.createdAt, locale: 'es'),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textHint)),
                                ],
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(top: 4, left: 6),
                                decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      );
                    },
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
