import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../datasources/driver_profile_model.dart';

abstract class AuthRemoteDataSource {
  Future<DriverProfileModel> signIn(String email, String password);
  Future<DriverProfileModel> signUp(String email, String password, Map<String, dynamic> metadata);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<DriverProfileModel?> getCurrentDriver();
  Future<void> updateDriverStatus(String status);
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

      // Fetch driver profile and verify role
      final profile = await _fetchDriverProfile(user.id);
      return profile;
    } on AppAuthException {
      rethrow;
    } on AppRoleException {
      rethrow;
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
      );

      final user = response.user;
      if (user == null) {
        throw const AppAuthException('No se pudo crear el usuario');
      }

      // Create profile record
      await _client.from(AppConstants.profilesTable).insert({
        'id': user.id,
        'full_name': metadata['fullName'],
        'role': 'driver',
      });

      // Create driver record
      await _client.from(AppConstants.driversTable).insert({
        'user_id': user.id,
        'vehicle_type': metadata['vehicleType'] ?? 'moto',
        'phone': metadata['phone'] ?? '',
        'status': 'offline',
        'is_active': false,
      });

      return await _fetchDriverProfile(user.id);
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
      throw const AppAuthException('No se pudo enviar el correo de recuperación');
    }
  }

  @override
  Future<DriverProfileModel?> getCurrentDriver() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      return await _fetchDriverProfile(user.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateDriverStatus(String status) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from(AppConstants.driversTable)
          .update({'status': status})
          .eq('user_id', user.id);
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  Future<DriverProfileModel> _fetchDriverProfile(String userId) async {
    // First check the profile has role 'driver'
    final profileData = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (profileData == null) {
      throw const AppAuthException('Perfil no encontrado');
    }

    final role = profileData['role'] as String?;
    if (role != 'driver') {
      await _client.auth.signOut();
      throw const AppRoleException();
    }

    // Fetch driver-specific data
    final driverData = await _client
        .from(AppConstants.driversTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (driverData == null) {
      throw const AppAuthException('Datos de repartidor no encontrados');
    }

    // Merge profile + driver data
    final merged = {
      ...profileData,
      ...driverData,
      'email': _client.auth.currentUser?.email ?? '',
    };

    return DriverProfileModel.fromJson(merged);
  }
}
