import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/entities/order.dart';
import '../providers/order_provider.dart';

class ActiveOrderScreen extends ConsumerStatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  ConsumerState<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends ConsumerState<ActiveOrderScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _driverPosition;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _listenPosition();
  }

  Future<void> _listenPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() => _driverPosition = LatLng(pos.latitude, pos.longitude));
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _advance() async {
    setState(() => _busy = true);
    try {
      await ref.read(activeOrderProvider.notifier).advanceStatus();
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) context.showSnackBar('No se pudo abrir la aplicación', isError: true);
    }
  }

  void _navigateTo(double lat, double lng, String label) {
    _launch(Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'));
  }

  @override
  Widget build(BuildContext context) {
    final activeOrderAsync = ref.watch(activeOrderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedido Activo')),
      body: activeOrderAsync.when(
        data: (order) {
          if (order == null) {
            return const EmptyState(
              icon: Icons.motorcycle_outlined,
              title: 'Sin pedido activo',
              subtitle: 'Acepta un pedido disponible para comenzar.',
            );
          }
          return _buildActiveOrder(order);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildActiveOrder(DeliveryOrder order) {
    final branch = LatLng(order.branchLat, order.branchLng);
    final delivery = LatLng(order.deliveryLat, order.deliveryLng);
    final pickedUp = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.onTheWay;
    final target = pickedUp ? delivery : branch;
    final targetLabel = pickedUp ? 'Punto de entrega' : 'Local de recojo';

    return Column(
      children: [
        Expanded(
          child: order.hasCoordinates
              ? _buildMap(order, branch, delivery)
              : const EmptyState(
                  icon: Icons.map_outlined,
                  title: 'Pedido sin coordenadas',
                  subtitle: 'Este pedido no tiene ubicación registrada.',
                ),
        ),
        _buildBottomPanel(order, target, targetLabel, pickedUp),
      ],
    );
  }

  Widget _buildMap(DeliveryOrder order, LatLng branch, LatLng delivery) {
    final points = <LatLng>[
      branch,
      delivery,
      if (_driverPosition != null) _driverPosition!,
    ];
    final bounds = LatLngBounds.fromPoints(points);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.acme.acme_driver',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: [branch, delivery],
              strokeWidth: 4,
              color: AppColors.primary.withOpacity(0.7),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: branch,
              width: 44,
              height: 44,
              child: const _MapPin(
                  icon: Icons.store, color: AppColors.primary),
            ),
            Marker(
              point: delivery,
              width: 44,
              height: 44,
              child: const _MapPin(icon: Icons.flag, color: AppColors.accent),
            ),
            if (_driverPosition != null)
              Marker(
                point: _driverPosition!,
                width: 44,
                height: 44,
                child: const _MapPin(
                    icon: Icons.motorcycle, color: AppColors.success),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomPanel(
      DeliveryOrder order, LatLng target, String targetLabel, bool pickedUp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido ${order.code}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                StatusBadge(
                  label: order.status.label,
                  color: _statusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoTile(
              icon: pickedUp ? Icons.flag : Icons.store,
              title: targetLabel,
              value: pickedUp ? order.deliveryAddress : order.branchName,
              iconColor: pickedUp ? AppColors.accent : AppColors.primary,
            ),
            const SizedBox(height: 8),
            InfoTile(
              icon: Icons.person,
              title: 'Cliente',
              value: '${order.recipientName} · ${order.recipientPhone}',
              iconColor: AppColors.success,
            ),
            if (order.specialInstructions?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              InfoTile(
                icon: Icons.sticky_note_2_outlined,
                title: 'Instrucciones',
                value: order.specialInstructions!,
                iconColor: AppColors.warning,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateTo(
                        target.latitude, target.longitude, targetLabel),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navegar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: order.recipientPhone.isEmpty
                        ? null
                        : () =>
                            _launch(Uri.parse('tel:${order.recipientPhone}')),
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Llamar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (order.status.nextActionLabel != null)
              ElevatedButton(
                onPressed: _busy ? null : _advance,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(order.status.nextActionLabel!),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAccepted:
        return AppColors.primary;
      case OrderStatus.pickedUp:
        return AppColors.warning;
      case OrderStatus.onTheWay:
        return AppColors.accent;
      case OrderStatus.delivered:
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MapPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
