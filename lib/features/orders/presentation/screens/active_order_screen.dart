import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/order_provider.dart';

class ActiveOrderScreen extends ConsumerWidget {
  const ActiveOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrderAsync = ref.watch(activeOrderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedido Activo'),
      ),
      body: activeOrderAsync.when(
        data: (order) {
          if (order == null) {
            return const EmptyState(
              icon: Icons.motorcycle_outlined,
              title: 'Sin pedido activo',
              subtitle: 'Acepta un pedido disponible para comenzar.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: 'Detalles del pedido: ${order.code}'),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InfoTile(
                          icon: Icons.store,
                          title: 'Local',
                          value: order.storeName,
                        ),
                        const Divider(height: 24),
                        InfoTile(
                          icon: Icons.person,
                          title: 'Cliente',
                          value: order.customerName,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(activeOrderProvider.notifier).advanceStatus();
                  },
                  child: const Text('Avanzar Estado'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
