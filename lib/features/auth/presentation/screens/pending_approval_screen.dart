import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/premium_header.dart';
import '../../../documents/domain/driver_document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../providers/auth_provider.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider).value;
    final docsAsync = ref.watch(driverDocumentsProvider);

    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            title: 'Cuenta en revisión',
            subtitle: 'Casi listo para repartir',
            actions: [
              HeaderIconButton(
                icon: PhosphorIconsBold.signOut,
                onTap: () =>
                    ref.read(currentDriverProvider.notifier).signOut(),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(driverDocumentsProvider);
                await ref.read(currentDriverProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x33FF6200),
                              blurRadius: 24,
                              offset: Offset(0, 10)),
                        ],
                      ),
                      child: const Icon(PhosphorIconsFill.hourglassMedium,
                          size: 52, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡Hola ${driver?.fullName.isEmpty == false ? driver!.fullName : 'repartidor'}!',
                    textAlign: TextAlign.center,
                    style: context.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un administrador está revisando tus documentos. '
                    'Te avisaremos en cuanto puedas empezar a recibir pedidos.',
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.fileText,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Estado de tus documentos',
                          style: context.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  docsAsync.when(
                    data: (docs) {
                      if (docs.isEmpty) {
                        return const Text('Aún no has subido documentos.');
                      }
                      return Column(children: docs.map(_docRow).toList());
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Actualizar estado',
                    icon: PhosphorIconsBold.arrowClockwise,
                    onPressed: () async {
                      ref.invalidate(driverDocumentsProvider);
                      await ref.read(currentDriverProvider.notifier).refresh();
                      if (context.mounted) {
                        context.showSnackBar('Estado actualizado');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docRow(DriverDocument doc) {
    final type = DocTypeX.fromString(doc.documentType);
    final (color, icon) = switch (doc.status) {
      'approved' => (AppColors.success, PhosphorIconsFill.checkCircle),
      'rejected' => (AppColors.error, PhosphorIconsFill.xCircle),
      _ => (AppColors.warning, PhosphorIconsFill.clock),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.file, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(type?.label ?? doc.documentType,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(doc.statusLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
