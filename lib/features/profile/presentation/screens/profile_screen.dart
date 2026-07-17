import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/domain/entities/driver_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../documents/domain/driver_document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentDriverProvider);

    return Scaffold(
      body: async.when(
        data: (d) {
          if (d == null) return const SizedBox();
          return ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              _Hero(
                driver: d,
                onEdit: () => _showEditSheet(context, ref, d),
                onLogout: () => _confirmLogout(context, ref),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _statsRow(d),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    _SectionCard(
                      title: 'Datos personales',
                      icon: PhosphorIconsRegular.userCircle,
                      onEdit: () => _showEditSheet(context, ref, d),
                      children: [
                        _InfoRow(PhosphorIconsRegular.identificationBadge,
                            'Nombre', d.fullName),
                        _InfoRow(PhosphorIconsRegular.envelopeSimple, 'Correo', d.email),
                        _InfoRow(PhosphorIconsRegular.phone, 'Teléfono', d.phone),
                        if (d.dni != null && d.dni!.isNotEmpty)
                          _InfoRow(PhosphorIconsRegular.identificationCard,
                              'Documento', d.dni!),
                        const SizedBox(height: 6),
                        AppButton(
                          label: 'Editar mis datos',
                          icon: PhosphorIconsBold.pencilSimple,
                          isOutlined: true,
                          onPressed: () => _showEditSheet(context, ref, d),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Mi vehículo',
                      icon: PhosphorIconsRegular.motorcycle,
                      children: [
                        _InfoRow(PhosphorIconsRegular.tag, 'Tipo',
                            d.vehicleTypeName ?? 'No especificado'),
                        if (d.plate != null && d.plate!.isNotEmpty)
                          _InfoRow(PhosphorIconsRegular.hash, 'Placa', d.plate!),
                        if (d.licenseNumber != null && d.licenseNumber!.isNotEmpty)
                          _InfoRow(PhosphorIconsRegular.cardholder, 'Licencia',
                              d.licenseNumber!),
                        if (d.vehicleBrand != null && d.vehicleBrand!.isNotEmpty)
                          _InfoRow(PhosphorIconsRegular.wrench, 'Modelo',
                              '${d.vehicleBrand} ${d.vehicleModel ?? ''}'.trim()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DocumentsCard(),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: const Icon(PhosphorIconsBold.signOut, size: 20),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('ACME-DRIVER · v1.0.0',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 12)),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => const Center(child: Text('Error al cargar el perfil')),
      ),
    );
  }

  Widget _statsRow(DriverProfile d) => Row(
        children: [
          Expanded(
            child: _StatBox(
              icon: PhosphorIconsFill.star,
              color: AppColors.warning,
              value: d.ratingAvg.toStringAsFixed(1),
              label: 'Calificación',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              icon: d.isVerified
                  ? PhosphorIconsFill.sealCheck
                  : PhosphorIconsFill.hourglassMedium,
              color: d.isVerified ? AppColors.success : AppColors.warning,
              value: d.isVerified ? 'Activo' : 'Revisión',
              label: 'Estado',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatBox(
              icon: PhosphorIconsFill.motorcycle,
              color: AppColors.info,
              value: d.vehicleTypeName ?? '—',
              label: 'Vehículo',
            ),
          ),
        ],
      );

  Future<void> _showEditSheet(
      BuildContext context, WidgetRef ref, DriverProfile d) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditProfileSheet(driver: d),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsBold.signOut,
                  color: AppColors.error, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Cerrar sesión',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          ],
        ),
        content: const Text(
          '¿Seguro que quieres salir de tu cuenta? Tendrás que volver a iniciar sesión para recibir pedidos.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Salir',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(currentDriverProvider.notifier).signOut();
    }
  }
}

class _Hero extends StatelessWidget {
  final DriverProfile driver;
  final VoidCallback onEdit;
  final VoidCallback onLogout;
  const _Hero(
      {required this.driver, required this.onEdit, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 40),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Mi perfil',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onEdit,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(PhosphorIconsBold.pencilSimple,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onLogout,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(PhosphorIconsBold.signOut,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      image: driver.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(driver.avatarUrl!),
                              fit: BoxFit.cover)
                          : const DecorationImage(
                              image: AssetImage(AppAssets.iconMark),
                              fit: BoxFit.cover),
                    ),
                  ),
                  if (driver.isVerified)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.sealCheck,
                          color: AppColors.success, size: 24),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                driver.fullName.isEmpty ? 'Repartidor' : driver.fullName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(driver.email,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatBox(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback? onEdit;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.children,
      this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              if (onEdit != null) ...[
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PhosphorIconsBold.pencilSimple,
                            size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Editar',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para editar datos personales (nombre y teléfono).
class _EditProfileSheet extends ConsumerStatefulWidget {
  final DriverProfile driver;
  const _EditProfileSheet({required this.driver});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.driver.fullName);
    _phoneCtrl = TextEditingController(text: widget.driver.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(currentDriverProvider.notifier).updateProfile(
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        context.showSnackBar('Datos actualizados');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text('Editar mis datos',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Actualiza tu nombre y teléfono. El documento y los datos del vehículo los gestiona el administrador.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(PhosphorIconsRegular.identificationBadge),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Ingresa tu nombre completo'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(PhosphorIconsRegular.phone),
              ),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? 'Ingresa un teléfono válido'
                  : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Guardar cambios',
              icon: PhosphorIconsBold.check,
              isLoading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DocumentsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverDocumentsProvider);
    return _SectionCard(
      title: 'Documentos',
      icon: PhosphorIconsRegular.fileText,
      children: [
        async.when(
          data: (docs) {
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hay documentos cargados.',
                    style: TextStyle(color: AppColors.textSecondary)),
              );
            }
            return Column(children: docs.map(_docRow).toList());
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }

  Widget _docRow(DriverDocument doc) {
    final type = DocTypeX.fromString(doc.documentType);
    final (color, icon) = switch (doc.status) {
      'approved' => (AppColors.success, PhosphorIconsFill.checkCircle),
      'rejected' => (AppColors.error, PhosphorIconsFill.xCircle),
      _ => (AppColors.warning, PhosphorIconsFill.clock),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.file, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(type?.label ?? doc.documentType,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
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
