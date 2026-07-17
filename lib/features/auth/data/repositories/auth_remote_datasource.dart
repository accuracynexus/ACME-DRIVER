import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../datasources/driver_profile_model.dart';

abstract class AuthRemoteDataSource {
  Future<DriverProfileModel> signIn(String email, String password);

  /// Crea el usuario en Auth y registra el perfil de repartidor (RPC).
  Future<DriverProfileModel> signUp(
      String email, String password, Map<String, dynamic> metadata);

  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<DriverProfileModel?> getCurrentDriver();

  /// Actualiza los datos personales editables del repartidor (tabla profiles).
  Future<void> updateProfile({String? fullName, String? phone});

  /// Conecta/desconecta al repartidor (driver_current_state) vía RPC.
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
    } on AppException {
      rethrow;
    } on AuthApiException catch (e) {
      if (e.code == 'invalid_credentials' ||
          (e.message.contains('Invalid login credentials'))) {
        throw const AppAuthException(AppStrings.loginError);
      }
      throw AppAuthException(e.message);
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  @override
  Future<DriverProfileModel> signUp(
      String email, String password, Map<String, dynamic> metadata) async {
    try {
      final response =
          await _client.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) {
        throw const AppAuthException('No se pudo crear el usuario');
      }

      // Si el proyecto exige confirmación por correo, no habrá sesión:
      // intentamos iniciar sesión para poder ejecutar el RPC autenticado.
      if (_client.auth.currentSession == null) {
        await _client.auth
            .signInWithPassword(email: email, password: password);
      }

      // Registro atómico (profile + drivers + vehicle + estado) en el backend.
      await _client.rpc(AppConstants.rpcRegisterDriver, params: {
        'p_full_name': metadata['fullName'],
        'p_phone': metadata['phone'],
        'p_dni': metadata['dni'],
        'p_email': email,
        'p_vehicle_type_code': metadata['vehicleTypeCode'],
        'p_license_number': metadata['licenseNumber'],
        'p_plate': metadata['plate'],
        'p_brand': metadata['brand'],
        'p_model': metadata['model'],
        'p_color': metadata['color'],
        'p_birthday': metadata['birthday'],
        'p_notifications': metadata['notificationsEnabled'] ?? true,
        'p_location': metadata['locationEnabled'] ?? true,
      });

      return await _fetchDriverProfile(user.id);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (_) {
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
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setOnline(bool online, {double? lat, double? lng}) async {
    await _client.rpc(AppConstants.rpcSetOnline, params: {
      'p_online': online,
      'p_lat': lat,
      'p_lng': lng,
    });
  }

  @override
  Future<void> updateProfile({String? fullName, String? phone}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AppAuthException('Sesión expirada');

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (updates.isEmpty) return;

    try {
      await _client
          .from(AppConstants.profilesTable)
          .update(updates)
          .eq('user_id', user.id);
    } catch (e) {
      throw AppAuthException('No se pudo actualizar el perfil: $e');
    }
  }

  /// Combina profiles + drivers + driver_current_state + vehículo + tipo
  /// en un solo mapa para construir el [DriverProfileModel].
  Future<DriverProfileModel> _fetchDriverProfile(String userId) async {
    final profile = await _client
        .from(AppConstants.profilesTable)
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
        .from(AppConstants.driversTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (driver == null) {
      throw const AppAuthException('Datos de repartidor no encontrados');
    }

    final dcs = await _client
        .from(AppConstants.driverCurrentStateTable)
        .select()
        .eq('driver_id', userId)
        .maybeSingle();

    final vehicle = await _client
        .from(AppConstants.vehiclesTable)
        .select('plate, brand, model, vehicle_type_id')
        .eq('driver_id', userId)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    String? vehicleTypeName;
    final vtId = driver['vehicle_type_id'] ?? vehicle?['vehicle_type_id'];
    if (vtId != null) {
      final vt = await _client
          .from(AppConstants.vehicleTypesTable)
          .select('name')
          .eq('id', vtId)
          .maybeSingle();
      vehicleTypeName = vt?['name'] as String?;
    }

    final merged = <String, dynamic>{
      'user_id': userId,
      // profiles
      'email': profile['email'] ?? _client.auth.currentUser?.email,
      'full_name': profile['full_name'],
      'phone': profile['phone'],
      'avatar_url': profile['avatar_url'],
      'dni': profile['dni'],
      'birthday': profile['birthday'],
      'is_active': profile['is_active'],
      'notifications_enabled': profile['notifications_enabled'],
      'location_enabled': profile['location_enabled'],
      // drivers
      'is_verified': driver['is_verified'],
      'rating_avg': driver['rating_avg'],
      'license_number': driver['license_number'],
      'document_number': driver['document_number'],
      'vehicle_type_id': vtId,
      'joined_at': driver['joined_at'],
      // driver_current_state
      'state': dcs?['status'],
      'is_online': dcs?['is_online'] ?? false,
      'current_order_id': dcs?['current_order_id'],
      'last_lat': dcs?['last_lat'],
      'last_lng': dcs?['last_lng'],
      // vehículo
      'plate': vehicle?['plate'],
      'vehicle_brand': vehicle?['brand'],
      'vehicle_model': vehicle?['model'],
      'vehicle_type_name': vehicleTypeName,
    };

    return DriverProfileModel.fromMerged(merged);
  }
}
