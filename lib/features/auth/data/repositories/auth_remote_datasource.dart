import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../datasources/driver_profile_model.dart';

abstract class AuthRemoteDataSource {
  Future<DriverProfileModel> signIn(String email, String password);
  Future<DriverProfileModel> signUp(
      String email, String password, Map<String, dynamic> metadata);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<DriverProfileModel?> getCurrentDriver();
  Future<void> setOnline(bool online, {double? lat, double? lng});
  Stream<AuthState> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<DriverProfileModel> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AppAuthException('No se pudo autenticar el usuario');
      }

      return await _fetchDriverProfile(user.id);
    } on AppAuthException {
      rethrow;
    } on AppRoleException {
      rethrow;
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e.message));
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  @override
  Future<DriverProfileModel> signUp(
      String email, String password, Map<String, dynamic> metadata) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': metadata['fullName']},
      );

      final user = response.user;
      if (user == null) {
        throw const AppAuthException('No se pudo crear el usuario');
      }
      if (response.session == null) {
        throw const AppAuthException(
            'Cuenta creada. Confirma tu correo electrónico y vuelve a iniciar sesión.');
      }

      // Registra perfil + driver + vehículo con la función del backend.
      await _client.rpc('register_driver', params: {
        'p_full_name': metadata['fullName'],
        'p_email': email,
        'p_phone': metadata['phone'],
        'p_dni': metadata['identificationNumber'],
        'p_vehicle_type_code':
            _vehicleTypeCode(metadata['vehicleType'] as String? ?? 'moto'),
        'p_plate': _nullIfEmpty(metadata['licensePlate'] as String?),
        'p_license_number': _nullIfEmpty(metadata['licenseNumber'] as String?),
        'p_notifications': metadata['notificationsEnabled'] ?? false,
        'p_location': metadata['locationEnabled'] ?? false,
      });

      return await _fetchDriverProfile(user.id);
    } on AppAuthException {
      rethrow;
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e.message));
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw const AppAuthException(
          'No se pudo enviar el correo de recuperación');
    }
  }

  @override
  Future<DriverProfileModel?> getCurrentDriver() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      return await _fetchDriverProfile(user.id);
    } on AppRoleException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setOnline(bool online, {double? lat, double? lng}) async {
    try {
      await _client.rpc('driver_set_online', params: {
        'p_online': online,
        if (lat != null) 'p_lat': lat,
        if (lng != null) 'p_lng': lng,
      });
    } catch (e) {
      throw AppAuthException('No se pudo cambiar el estado: $e');
    }
  }

  Future<DriverProfileModel> _fetchDriverProfile(String userId) async {
    final profile = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (profile == null) {
      throw const AppAuthException('Perfil no encontrado');
    }
    if (profile['default_role'] != 'driver') {
      await _client.auth.signOut();
      throw const AppRoleException();
    }

    final driver = await _client
        .from('drivers')
        .select('*, vehicle_type:vehicle_types(code, name)')
        .eq('user_id', userId)
        .maybeSingle();

    if (driver == null) {
      throw const AppAuthException('Datos de repartidor no encontrados');
    }

    final state = await _client
        .from('driver_current_state')
        .select()
        .eq('driver_id', userId)
        .maybeSingle();

    final vehicle = await _client
        .from('vehicles')
        .select('plate')
        .eq('driver_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    return DriverProfileModel.fromRows(
      profile: {...profile, 'email': _client.auth.currentUser?.email ?? profile['email']},
      driver: driver,
      state: state,
      vehicleType: driver['vehicle_type'] as Map<String, dynamic>?,
      vehicle: vehicle,
    );
  }

  static String _vehicleTypeCode(String uiValue) {
    switch (uiValue) {
      case 'moto':
      case 'motorcycle':
        return 'motorcycle';
      case 'bicicleta':
      case 'bicycle':
        return 'bicycle';
      case 'auto':
      case 'car':
        return 'car';
      case 'a_pie':
      case 'walker':
        return 'walker';
      default:
        return 'motorcycle';
    }
  }

  static String? _nullIfEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  static String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (message.contains('already registered')) {
      return 'Este correo ya está registrado';
    }
    if (message.contains('Email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión';
    }
    return message;
  }
}
