import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  timeago.setLocaleMessages('es', timeago.EsMessages());

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: AcmeDriverApp(),
    ),
  );
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
