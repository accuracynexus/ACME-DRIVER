import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Localización (fechas y "hace X tiempo" en español)
  await initializeDateFormatting('es', null);
  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Si Supabase no arranca, la app no puede funcionar: su cliente queda sin
  // inicializar y cualquier pantalla revienta con LateInitializationError,
  // dejando el splash girando para siempre. Mejor decirlo en pantalla.
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
    runApp(StartupErrorApp(message: e.toString()));
    return;
  }

  runApp(const ProviderScope(child: AcmeDriverApp()));
}

/// Pantalla de arranque fallido. Sustituye al splash infinito cuando la
/// configuración es inválida (típicamente, un build sin los --dart-define).
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACME-DRIVER',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 72, color: Colors.redAccent),
                const SizedBox(height: 20),
                Text(
                  'No se pudo iniciar la app',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Si estás compilando, recuerda:\n'
                  'flutter build apk --release '
                  '--dart-define-from-file=dart_defines.json',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AcmeDriverApp extends ConsumerWidget {
  const AcmeDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ACME-DRIVER',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
