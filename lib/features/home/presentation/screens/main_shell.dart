import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = [
    AppRoutes.home,
    AppRoutes.availableOrders,
    AppRoutes.history,
    AppRoutes.earnings,
    AppRoutes.profile,
  ];

  static const _items = [
    _NavData(PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Inicio'),
    _NavData(PhosphorIconsRegular.package, PhosphorIconsFill.package, 'Pedidos'),
    _NavData(PhosphorIconsRegular.clockCounterClockwise,
        PhosphorIconsFill.clockCounterClockwise, 'Historial'),
    _NavData(PhosphorIconsRegular.wallet, PhosphorIconsFill.wallet, 'Ganancias'),
    _NavData(PhosphorIconsRegular.user, PhosphorIconsFill.user, 'Perfil'),
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith(AppRoutes.availableOrders)) return 1;
    if (loc.startsWith(AppRoutes.history)) return 2;
    if (loc.startsWith(AppRoutes.earnings)) return 3;
    if (loc.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(context);
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 24, offset: Offset(0, -6)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                return _NavButton(
                  data: _items[i],
                  active: i == index,
                  onTap: () => context.go(_routes[i]),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavData(this.icon, this.activeIcon, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavData data;
  final bool active;
  final VoidCallback onTap;
  const _NavButton(
      {required this.data, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? data.activeIcon : data.icon,
                size: 24,
                color: active ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
