import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../documents/domain/driver_document.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../models/signup_form_data.dart';
import '../providers/auth_provider.dart';

class SignUpScreenSteps extends ConsumerStatefulWidget {
  const SignUpScreenSteps({super.key});

  @override
  ConsumerState<SignUpScreenSteps> createState() => _SignUpScreenStepsState();
}

class _SignUpScreenStepsState extends ConsumerState<SignUpScreenSteps> {
  int _step = 0;
  final _data = SignUpFormData();
  bool _loading = false;
  bool _obscure = true;

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dni = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _fullName, _email, _phone, _dni, _password,
      _license, _plate, _brand, _model,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncData() {
    _data
      ..fullName = _fullName.text
      ..email = _email.text.trim()
      ..phone = _phone.text.trim()
      ..dni = _dni.text.trim()
      ..password = _password.text
      ..licenseNumber = _license.text.trim()
      ..plate = _plate.text.trim()
      ..brand = _brand.text.trim()
      ..model = _model.text.trim();
  }

  Future<void> _next() async {
    _syncData();
    final ok = switch (_step) {
      0 => _data.isStep1Valid(),
      1 => _data.isStep2Valid(),
      2 => _data.isStep3Valid(),
      _ => _data.isStep4Valid(),
    };
    if (!ok) {
      context.showSnackBar(_errorFor(_step), isError: true);
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  String _errorFor(int step) => switch (step) {
        0 => 'Completa tus datos personales correctamente',
        1 => 'Datos del vehículo incompletos o inválidos',
        2 => 'Sube todos los documentos requeridos',
        _ => 'Debes aceptar los términos y condiciones',
      };

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(currentDriverProvider.notifier).signUp(
            _data.email,
            _data.password,
            _data.toMetadata(),
          );

      // Subir documentos ahora que la cuenta existe y hay sesión.
      final docsDs = ref.read(documentDataSourceProvider);
      for (final entry in _data.documents.entries) {
        await docsDs.uploadAndSubmit(
          type: entry.key.value,
          bytes: entry.value.bytes,
          extension: entry.value.extension,
          contentType: entry.value.contentType,
          documentNumber: _data.dni,
        );
      }

      if (mounted) context.go('/pending');
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickDoc(DocType type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsRegular.camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.images),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      setState(() {
        _data.documents[type] = PickedDoc(
          bytes,
          ext.isEmpty ? 'jpg' : ext,
          'image/${ext == 'png' ? 'png' : 'jpeg'}',
        );
      });
    } catch (e) {
      if (mounted) context.showSnackBar('No se pudo cargar la imagen', isError: true);
    }
  }

  Future<void> _requestLocation() async {
    final perm = await Geolocator.requestPermission();
    setState(() => _data.locationEnabled = perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.caretLeft, color: AppColors.primary),
          onPressed: _back,
        ),
        title: Text('Paso ${_step + 1} de 4',
            style: const TextStyle(color: AppColors.primary)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: LinearProgressIndicator(
                value: (_step + 1) / 4,
                minHeight: 6,
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _content(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton(
                label: _step == 3 ? 'Crear cuenta' : 'Siguiente',
                isLoading: _loading,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() => switch (_step) {
        0 => _stepPersonal(),
        1 => _stepVehicle(),
        2 => _stepDocuments(),
        _ => _stepPermissions(),
      };

  Widget _title(String t, String s) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: context.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(s, style: context.textTheme.bodyMedium),
          ],
        ),
      );

  List<Widget> _stepPersonal() => [
        _title('Datos personales', 'Cuéntanos sobre ti'),
        AppTextField(
          controller: _fullName,
          label: 'Nombre completo',
          prefixIcon: const Icon(PhosphorIconsRegular.user),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _email,
          label: AppStrings.email,
          hint: 'tu@correo.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(PhosphorIconsRegular.envelopeSimple),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _phone,
          label: 'Teléfono',
          keyboardType: TextInputType.phone,
          prefixIcon: const Icon(PhosphorIconsRegular.phone),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _dni,
          label: 'DNI / Documento',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(PhosphorIconsRegular.identificationCard),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _password,
          label: AppStrings.password,
          obscureText: _obscure,
          prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mínimo 8 caracteres, con mayúscula, minúscula, número y símbolo.',
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
      ];

  List<Widget> _stepVehicle() => [
        _title('Vehículo', 'Detalles de tu transporte'),
        DropdownButtonFormField<String>(
          initialValue: _data.vehicleTypeCode,
          decoration: const InputDecoration(
            labelText: 'Tipo de vehículo',
            prefixIcon: Icon(PhosphorIconsRegular.motorcycle),
          ),
          items: const [
            DropdownMenuItem(value: 'motorcycle', child: Text('Motocicleta')),
            DropdownMenuItem(value: 'car', child: Text('Auto')),
            DropdownMenuItem(value: 'bicycle', child: Text('Bicicleta')),
            DropdownMenuItem(value: 'walker', child: Text('A pie')),
          ],
          onChanged: (v) => setState(() => _data.vehicleTypeCode = v ?? 'motorcycle'),
        ),
        const SizedBox(height: 16),
        if (_data.isMotorized) ...[
          AppTextField(
            controller: _plate,
            label: 'Placa',
            hint: 'Ej: ABC-123',
            prefixIcon: const Icon(PhosphorIconsRegular.hash),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _license,
            label: 'Número de licencia',
            prefixIcon: const Icon(PhosphorIconsRegular.cardholder),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(controller: _brand, label: 'Marca'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(controller: _model, label: 'Modelo'),
              ),
            ],
          ),
        ] else
          _infoBox('Para bicicleta o reparto a pie no se requiere placa ni licencia.'),
        const SizedBox(height: 16),
      ];

  List<Widget> _stepDocuments() => [
        _title('Documentos', 'El administrador los revisará para habilitarte'),
        ..._data.requiredDocs.map(_docTile),
        const SizedBox(height: 16),
      ];

  Widget _docTile(DocType type) {
    final picked = _data.documents.containsKey(type);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: picked ? AppColors.success : AppColors.border),
      ),
      child: ListTile(
        leading: Icon(
          picked ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.uploadSimple,
          color: picked ? AppColors.success : AppColors.textSecondary,
        ),
        title: Text(type.label),
        subtitle: Text(picked ? 'Cargado' : 'Toca para subir'),
        trailing: const Icon(PhosphorIconsBold.caretRight),
        onTap: () => _pickDoc(type),
      ),
    );
  }

  List<Widget> _stepPermissions() => [
        _title('Permisos y términos', 'Casi listo'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: _data.locationEnabled ? AppColors.accent : AppColors.border),
          ),
          child: SwitchListTile(
            value: _data.locationEnabled,
            onChanged: (_) => _requestLocation(),
            title: const Text('Acceso a ubicación'),
            subtitle: const Text('Necesario para recibir y entregar pedidos'),
            activeThumbColor: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: _data.notificationsEnabled ? AppColors.accent : AppColors.border),
          ),
          child: SwitchListTile(
            value: _data.notificationsEnabled,
            onChanged: (v) => setState(() => _data.notificationsEnabled = v),
            title: const Text('Notificaciones'),
            subtitle: const Text('Para avisarte de nuevos pedidos'),
            activeThumbColor: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _data.acceptedTerms,
          onChanged: (v) => setState(() => _data.acceptedTerms = v ?? false),
          title: const Text('Acepto los términos y condiciones'),
          subtitle: const Text('Y la política de privacidad de ACME PEDIDOS'),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
        ),
        const SizedBox(height: 16),
        _infoBox(
            'Tras crear tu cuenta, un administrador revisará tus documentos. '
            'Podrás recibir pedidos cuando seas aprobado.'),
        const SizedBox(height: 16),
      ];

  Widget _infoBox(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.info, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text,
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary))),
          ],
        ),
      );
}
