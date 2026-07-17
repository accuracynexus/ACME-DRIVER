import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentDriverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(currentDriverProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: authState.when(
        data: (driver) {
          if (driver == null) return const SizedBox();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                driver.fullName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(driver.email, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    driver.isVerified ? Icons.verified : Icons.hourglass_top,
                    size: 16,
                    color: driver.isVerified
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    driver.isVerified
                        ? 'Cuenta verificada'
                        : 'Verificación pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: driver.isVerified
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Vehículo'),
                subtitle: Text(
                  '${driver.vehicleTypeName.isNotEmpty ? driver.vehicleTypeName : driver.vehicleType}'
                  '${driver.licensePlate != null ? ' - ${driver.licensePlate}' : ''}',
                ),
              ),
              if (driver.licenseNumber != null)
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Licencia'),
                  subtitle: Text(driver.licenseNumber!),
                ),
              if (driver.dni != null)
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('DNI'),
                  subtitle: Text(driver.dni!),
                ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Teléfono'),
                subtitle: Text(
                    driver.phone.isNotEmpty ? driver.phone : 'No registrado'),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Calificación'),
                subtitle: Text(driver.rating > 0
                    ? driver.rating.toStringAsFixed(1)
                    : 'Sin calificaciones aún'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const Center(child: Text('Error al cargar el perfil')),
      ),
    );
  }
}
