import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  /// Credenciales públicas inyectadas en tiempo de compilación con
  /// `--dart-define-from-file=dart_defines.json`. Nunca se empaquetan
  /// secretos (service role, cadena de conexión) dentro de la app.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Compila con '
        '--dart-define-from-file=dart_defines.json',
      );
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: false,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
