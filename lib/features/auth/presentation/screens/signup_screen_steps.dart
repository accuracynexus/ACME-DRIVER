import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../models/signup_form_data.dart';
import '../providers/auth_provider.dart';

class SignUpScreenSteps extends ConsumerStatefulWidget {
  const SignUpScreenSteps({super.key});

  @override
  ConsumerState<SignUpScreenSteps> createState() => _SignUpScreenStepsState();
}

class _SignUpScreenStepsState extends ConsumerState<SignUpScreenSteps> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _formData = SignUpFormData();
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _identificationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankAccountController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _identificationController.dispose();
    _passwordController.dispose();
    _licensePlateController.dispose();
    _licenseNumberController.dispose();
    _addressController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Geolocator.requestPermission();
      setState(() {
        _formData.locationEnabled = status == LocationPermission.whileInUse ||
            status == LocationPermission.always;
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error al solicitar permiso de ubicación', isError: true);
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      setState(() {
        _formData.notificationsEnabled = true;
      });
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error al solicitar permiso de notificaciones',
            isError: true);
      }
    }
  }

  Future<void> _handleSignUp() async {
    _formData.fullName = _fullNameController.text.trim();
    _formData.email = _emailController.text.trim();
    _formData.phone = _phoneController.text.trim();
    _formData.password = _passwordController.text.trim();
    _formData.identificationNumber = _identificationController.text.trim();
    _formData.licensePlate = _licensePlateController.text.trim();
    _formData.licenseNumber = _licenseNumberController.text.trim();
    _formData.address = _addressController.text.trim();
    _formData.bankAccount = _bankAccountController.text.trim();

    if (_currentStep < 3) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _currentStep++);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(currentDriverProvider.notifier).signUp(
        _formData.email,
        _formData.password,
        _formData.toMetadata(),
      );
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    if (_currentStep == 0) {
      context.pop();
    } else {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: _goBack,
        ),
        title: Text('Paso ${_currentStep + 1} de 4',
            style: const TextStyle(color: AppColors.primary)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(24),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 4,
                minHeight: 6,
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildStepContent(),
                  ),
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AppButton(
                    label: _currentStep == 3 ? 'Registrarse' : 'Siguiente',
                    isLoading: _isLoading,
                    onPressed: _handleSignUp,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _goBack,
                    child: const Text('Atrás'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1PersonalInfo();
      case 1:
        return _buildStep2VehicleInfo();
      case 2:
        return _buildStep3BankingAndAddress();
      case 3:
        return _buildStep4Permissions();
      default:
        return [];
    }
  }

  List<Widget> _buildStep1PersonalInfo() {
    return [
      const SizedBox(height: 20),
      Text(
        'Información Personal',
        style: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Cuéntanos sobre ti',
        style: context.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      AppTextField(
        controller: _fullNameController,
        label: 'Nombre completo',
        hint: 'Ej: Juan Pérez García',
        prefixIcon: const Icon(Icons.person_outline),
        validator: (v) => v == null || v.isEmpty ? 'Ingresa tu nombre' : null,
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _emailController,
        label: AppStrings.email,
        hint: 'tu@correo.com',
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.email_outlined),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Ingresa tu correo';
          if (!v.isValidEmail) return 'Correo inválido';
          return null;
        },
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _phoneController,
        label: 'Teléfono',
        hint: 'Ej: 1234567890',
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(Icons.phone_outlined),
        validator: (v) => v == null || v.isEmpty ? 'Ingresa tu teléfono' : null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _formData.identificationType,
        decoration: InputDecoration(
          labelText: 'Tipo de identificación',
          prefixIcon: const Icon(Icons.card_giftcard),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'cedula', child: Text('Cédula')),
          DropdownMenuItem(value: 'pasaporte', child: Text('Pasaporte')),
          DropdownMenuItem(value: 'licencia', child: Text('Licencia de conducir')),
        ],
        onChanged: (v) =>
            setState(() => _formData.identificationType = v ?? 'cedula'),
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _identificationController,
        label: 'Número de identificación',
        hint: 'Ej: 123456789',
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.numbers),
        validator: (v) =>
            v == null || v.isEmpty ? 'Ingresa tu número de identificación' : null,
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _passwordController,
        label: AppStrings.password,
        hint: '••••••••',
        obscureText: _obscurePassword,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
          if (v.length < 6) return 'Mínimo 6 caracteres';
          return null;
        },
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _buildStep2VehicleInfo() {
    return [
      const SizedBox(height: 20),
      Text(
        'Información del Vehículo',
        style: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Detalles de tu transporte',
        style: context.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: _formData.vehicleType,
        decoration: InputDecoration(
          labelText: 'Tipo de vehículo',
          prefixIcon: const Icon(Icons.directions_bike),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'bicicleta', child: Text('Bicicleta')),
          DropdownMenuItem(value: 'moto', child: Text('Moto')),
          DropdownMenuItem(value: 'auto', child: Text('Automóvil')),
        ],
        onChanged: (v) => setState(() => _formData.vehicleType = v ?? 'moto'),
      ),
      const SizedBox(height: 16),
      if (_formData.vehicleType != 'bicicleta') ...[
        AppTextField(
          controller: _licensePlateController,
          label: 'Placa del vehículo',
          hint: 'Ej: ABC-123',
          prefixIcon: const Icon(Icons.local_taxi),
          validator: (v) => v == null || v.isEmpty
              ? 'Ingresa la placa de tu vehículo'
              : null,
        ),
        const SizedBox(height: 16),
      ],
      AppTextField(
        controller: _licenseNumberController,
        label: 'Número de licencia de conducir',
        hint: 'Ej: L123456',
        prefixIcon: const Icon(Icons.card_membership),
        validator: (v) =>
            v == null || v.isEmpty ? 'Ingresa tu número de licencia' : null,
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _buildStep3BankingAndAddress() {
    return [
      const SizedBox(height: 20),
      Text(
        'Dirección y Datos Bancarios',
        style: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Para pagos y referencias',
        style: context.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      AppTextField(
        controller: _addressController,
        label: 'Dirección',
        hint: 'Calle Principal 123, Apto 4',
        prefixIcon: const Icon(Icons.location_on_outlined),
        maxLines: 3,
        validator: (v) => v == null || v.isEmpty ? 'Ingresa tu dirección' : null,
      ),
      const SizedBox(height: 16),
      AppTextField(
        controller: _bankAccountController,
        label: 'Cuenta bancaria (IBAN o número)',
        hint: 'Ej: ES9121000418450200051332',
        prefixIcon: const Icon(Icons.account_balance),
        validator: (v) =>
            v == null || v.isEmpty ? 'Ingresa tu cuenta bancaria' : null,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tus datos se mantienen seguros y confidenciales',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _buildStep4Permissions() {
    return [
      const SizedBox(height: 20),
      Text(
        'Permisos y Confirmación',
        style: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Necesitamos algunos permisos para funcionar',
        style: context.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      // Location Permission
      Card(
        elevation: 0,
        color: _formData.locationEnabled
            ? AppColors.accent.withValues(alpha: 0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _formData.locationEnabled ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Acceso a ubicación',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Para seguimiento de entregas',
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Checkbox(
                    value: _formData.locationEnabled,
                    onChanged: (_) => _requestLocationPermission(),
                    fillColor:
                        WidgetStateProperty.all(AppColors.primary),
                  ),
                ],
              ),
              if (!_formData.locationEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Habilitar ubicación',
                      onPressed: _requestLocationPermission,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Notifications Permission
      Card(
        elevation: 0,
        color: _formData.notificationsEnabled
            ? AppColors.accent.withValues(alpha: 0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _formData.notificationsEnabled
                ? AppColors.accent
                : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notifications_active,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Notificaciones',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Para recibir nuevas órdenes',
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Checkbox(
                    value: _formData.notificationsEnabled,
                    onChanged: (_) => _requestNotificationPermission(),
                    fillColor:
                        WidgetStateProperty.all(AppColors.primary),
                  ),
                ],
              ),
              if (!_formData.notificationsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Habilitar notificaciones',
                      onPressed: _requestNotificationPermission,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Estás a punto de completar tu registro',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Al continuar, aceptas que tenemos permiso para acceder a tu ubicación y enviarte notificaciones cuando sea necesario.',
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
    ];
  }
}
