import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/driver_profile_model.dart';
import '../../data/repositories/auth_remote_datasource.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/providers/supabase_provider.dart';

// ── Data source provider ────────────────────────────────────
final authDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});

// ── Auth state provider ─────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authDataSourceProvider).authStateChanges;
});

// ── Current driver provider ──────────────────────────────────
final currentDriverProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<DriverProfileModel?>>((ref) {
  return AuthNotifier(
    ref.watch(authDataSourceProvider),
    ref.watch(locationServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AsyncValue<DriverProfileModel?>> {
  final AuthRemoteDataSource _dataSource;
  final LocationService _locationService;

  AuthNotifier(this._dataSource, this._locationService)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final driver = await _dataSource.getCurrentDriver();
      state = AsyncValue.data(driver);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final driver = await _dataSource.signIn(email, password);
      state = AsyncValue.data(driver);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp(
      String email, String password, Map<String, dynamic> metadata) async {
    state = const AsyncValue.loading();
    try {
      final driver = await _dataSource.signUp(email, password, metadata);
      state = AsyncValue.data(driver);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _dataSource.setOnline(false);
    } catch (_) {}
    _locationService.stop();
    await _dataSource.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> sendPasswordReset(String email) async {
    await _dataSource.sendPasswordResetEmail(email);
  }

  /// Conecta/desconecta al repartidor. Al conectarse envía la posición actual
  /// y arranca el envío periódico de ubicación.
  Future<void> toggleOnline() async {
    final current = state.value;
    if (current == null) return;

    final goOnline = !current.isOnline;
    double? lat;
    double? lng;
    if (goOnline) {
      final pos = await _locationService.getCurrentPosition();
      lat = pos?.latitude;
      lng = pos?.longitude;
    }

    await _dataSource.setOnline(goOnline, lat: lat, lng: lng);

    if (goOnline) {
      _locationService.start();
    } else {
      _locationService.stop();
    }

    await refresh();
  }

  Future<void> refresh() async {
    final updated = await _dataSource.getCurrentDriver();
    if (mounted) state = AsyncValue.data(updated);
  }
}
