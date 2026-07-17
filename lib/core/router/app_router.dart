import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/datasources/driver_profile_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen_steps.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/orders/presentation/screens/available_orders_screen.dart';
import '../../features/orders/presentation/screens/active_order_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signUpSteps = '/signup-steps';
  static const forgotPassword = '/forgot-password';
  static const pending = '/pending';
  static const home = '/home';
  static const availableOrders = '/orders';
  static const activeOrder = '/orders/active';
  static const history = '/history';
  static const earnings = '/earnings';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const orderChat = '/chat';
}

final routerProvider = Provider<GoRouter>((ref) {
  // El router se crea UNA sola vez. En vez de `ref.watch` (que recrearía el
  // GoRouter en cada cambio de sesión y lo mandaría a initialLocation/splash),
  // se refresca con un ValueNotifier vía refreshListenable.
  final authNotifier =
      ValueNotifier<AsyncValue<DriverProfileModel?>>(const AsyncValue.loading());
  ref.onDispose(authNotifier.dispose);
  ref.listen<AsyncValue<DriverProfileModel?>>(currentDriverProvider, (_, next) {
    authNotifier.value = next;
  }, fireImmediately: true);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authAsync = authNotifier.value;
      final isLoading = authAsync.isLoading;
      if (isLoading) return null; // permanecer en splash

      final driver = authAsync.value;
      final isAuth = driver != null;
      final loc = state.matchedLocation;
      final isSplash = loc == AppRoutes.splash;
      final isAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.signUpSteps ||
          loc == AppRoutes.forgotPassword;
      final isPending = loc == AppRoutes.pending;

      // Sin sesión
      if (!isAuth) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // Con sesión pero no aprobado → pantalla de revisión
      if (!driver.isApproved) {
        return isPending ? null : AppRoutes.pending;
      }

      // Aprobado: fuera de splash/auth/pending
      if (isSplash || isAuthRoute || isPending) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.signUpSteps,
          builder: (_, __) => const SignUpScreenSteps()),
      GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: AppRoutes.pending,
          builder: (_, __) => const PendingApprovalScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
              path: AppRoutes.availableOrders,
              builder: (_, __) => const AvailableOrdersScreen()),
          GoRoute(
              path: AppRoutes.activeOrder,
              builder: (_, __) => const ActiveOrderScreen()),
          GoRoute(
              path: AppRoutes.history,
              builder: (_, __) => const HistoryScreen()),
          GoRoute(
              path: AppRoutes.earnings,
              builder: (_, __) => const EarningsScreen()),
          GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen()),
          GoRoute(
              path: AppRoutes.notifications,
              builder: (_, __) => const NotificationsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.orderChat,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            orderId: extra?['orderId'] as String? ?? '',
            title: extra?['title'] as String? ?? 'Cliente',
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
    ),
  );
});
