import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                driver.email,
                textAlign: TextAlign.center,
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Vehículo'),
                subtitle: Text('${driver.vehicleType} - ${driver.licensePlate ?? "Sin placa"}'),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Teléfono'),
                subtitle: Text(driver.phone),
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
