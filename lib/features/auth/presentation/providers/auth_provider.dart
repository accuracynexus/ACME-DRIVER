import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/driver_profile_model.dart';
import '../../data/repositories/auth_remote_datasource.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../location/data/location_service.dart';

// ── Data source provider ────────────────────────────────────
final authDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

// ── Auth state stream (Supabase) ─────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authDataSourceProvider).authStateChanges;
});

// ── Current driver provider ──────────────────────────────────
final currentDriverProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<DriverProfileModel?>>((ref) {
  return AuthNotifier(ref.watch(authDataSourceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<DriverProfileModel?>> {
  final AuthRemoteDataSource _dataSource;

  AuthNotifier(this._dataSource) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    state = AsyncValue.data(await _dataSource.getCurrentDriver());
  }

  Future<void> refresh() async {
    state = AsyncValue.data(await _dataSource.getCurrentDriver());
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _dataSource.signIn(email, password));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp(
      String email, String password, Map<String, dynamic> metadata) async {
    state = const AsyncValue.loading();
    try {
      state =
          AsyncValue.data(await _dataSource.signUp(email, password, metadata));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final current = state.value;
    // intentar desconectar antes de salir
    if (current != null && current.isOnline) {
      try {
        await _dataSource.setOnline(false);
      } catch (_) {}
    }
    await _dataSource.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> sendPasswordReset(String email) =>
      _dataSource.sendPasswordResetEmail(email);

  /// Actualiza datos personales editables (nombre, teléfono) y refresca.
  Future<void> updateProfile({String? fullName, String? phone}) async {
    await _dataSource.updateProfile(fullName: fullName, phone: phone);
    await refresh();
  }

  /// Conecta/desconecta al repartidor, adjuntando ubicación si está disponible.
  Future<void> setOnline(bool online) async {
    final pos = online ? await LocationService.tryGetPosition() : null;
    await _dataSource.setOnline(online, lat: pos?.latitude, lng: pos?.longitude);
    await refresh();
  }

  Future<void> toggleOnline() async {
    final current = state.value;
    if (current == null) return;
    await setOnline(!current.isOnline);
  }
}
