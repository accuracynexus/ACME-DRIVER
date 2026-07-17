import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/evidence_service.dart';
import '../../../../core/services/route_service.dart';
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
  double _heading = 0;
  double _speedKmh = 0;
  RouteResult? _route;
  LatLng? _routeTarget;
  bool _follow = true;
  bool _mapReady = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startPositionStream();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startPositionStream() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Primera posición inmediata para no esperar al stream.
      Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).then(_onPosition).catchError((_) {});

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (_) {}
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    setState(() {
      _driverPosition = LatLng(pos.latitude, pos.longitude);
      if (pos.heading >= 0) _heading = pos.heading;
      _speedKmh = pos.speed > 0 ? pos.speed * 3.6 : 0;
    });

    if (_follow && _mapReady) {
      _mapController.move(_driverPosition!, _mapController.camera.zoom);
    }
    _refreshRoute();
  }

  Future<void> _refreshRoute() async {
    final order = ref.read(activeOrderProvider).value;
    final origin = _driverPosition;
    if (order == null || origin == null || !order.hasCoordinates) return;

    final target = _targetFor(order);
    final result =
        await ref.read(routeServiceProvider).getRoute(origin, target);
    if (mounted && result != null) {
      setState(() {
        _route = result;
        _routeTarget = target;
      });
    }
  }

  LatLng _targetFor(DeliveryOrder order) {
    final pickedUp = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.onTheWay;
    return pickedUp
        ? LatLng(order.deliveryLat, order.deliveryLng)
        : LatLng(order.branchLat, order.branchLng);
  }

  Future<void> _advance(DeliveryOrder order) async {
    final next = order.status.next;
    if (next == null) return;

    // Entrega final: confirmar y ofrecer foto de evidencia.
    XFile? evidencePhoto;
    if (next == OrderStatus.delivered) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar entrega'),
          content: Text(
              '¿Entregaste el pedido ${order.code} a ${order.recipientName}?\n\n'
              'Puedes tomar una foto como evidencia de la entrega.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aún no'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'no_photo'),
              child: const Text('Sin foto'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'photo'),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Foto y entregar'),
            ),
          ],
        ),
      );
      if (choice == null) return;

      if (choice == 'photo') {
        evidencePhoto = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (evidencePhoto == null) return; // canceló la cámara
      }
    }

    setState(() => _busy = true);
    try {
      if (evidencePhoto != null) {
        await ref.read(evidenceServiceProvider).uploadDeliveryPhoto(
              orderId: order.orderId,
              image: evidencePhoto,
            );
      }
      await ref.read(activeOrderProvider.notifier).advanceStatus();
      ref.read(routeServiceProvider).clear();
      _route = null;
      if (mounted && next == OrderStatus.delivered) {
        context.showSnackBar(evidencePhoto != null
            ? '¡Entrega completada con evidencia! 🎉'
            : '¡Entrega completada! 🎉');
      }
    } catch (e) {
      if (mounted) context.showSnackBar('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        context.showSnackBar('No se pudo abrir la aplicación', isError: true);
      }
    }
  }

  void _fitAll(DeliveryOrder order) {
    final points = <LatLng>[
      LatLng(order.branchLat, order.branchLng),
      LatLng(order.deliveryLat, order.deliveryLng),
      if (_driverPosition != null) _driverPosition!,
    ];
    setState(() => _follow = false);
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(50, 100, 50, 260),
    ));
  }

  void _recenter() {
    if (_driverPosition == null) return;
    setState(() => _follow = true);
    _mapController.move(_driverPosition!, 17);
  }

  @override
  Widget build(BuildContext context) {
    final activeOrderAsync = ref.watch(activeOrderProvider);

    return Scaffold(
      body: activeOrderAsync.when(
        data: (order) {
          if (order == null) {
            return SafeArea(
              child: Column(
                children: [
                  AppBar(title: const Text('Pedido Activo')),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.motorcycle_outlined,
                      title: 'Sin pedido activo',
                      subtitle: 'Acepta un pedido disponible para comenzar.',
                    ),
                  ),
                ],
              ),
            );
          }
          if (!order.hasCoordinates) {
            return SafeArea(
              child: Column(
                children: [
                  AppBar(title: Text('Pedido ${order.code}')),
                  Expanded(child: _DetailsList(order: order, launch: _launch)),
                  _ActionBar(order: order, busy: _busy, onAdvance: _advance),
                ],
              ),
            );
          }
          return _buildCourierView(order);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  // ── Vista courier: mapa a pantalla completa + hoja deslizable ──
  Widget _buildCourierView(DeliveryOrder order) {
    final branch = LatLng(order.branchLat, order.branchLng);
    final delivery = LatLng(order.deliveryLat, order.deliveryLng);
    final pickedUp = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.onTheWay;
    final target = _targetFor(order);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _driverPosition ?? branch,
            initialZoom: 16,
            onMapReady: () {
              _mapReady = true;
              if (_driverPosition == null) _fitAll(order);
            },
            onPositionChanged: (camera, hasGesture) {
              // Si el repartidor mueve el mapa a mano, dejamos de seguirlo.
              if (hasGesture && _follow) {
                setState(() => _follow = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.acme.acme_driver',
            ),
            PolylineLayer(
              polylines: [
                if (_route != null && _routeTarget == target)
                  Polyline(
                    points: _route!.points,
                    strokeWidth: 6,
                    color: AppColors.primary.withOpacity(0.85),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  )
                else
                  Polyline(
                    points: [_driverPosition ?? branch, target],
                    strokeWidth: 4,
                    color: AppColors.primary.withOpacity(0.5),
                    pattern: const StrokePattern.dotted(),
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: branch,
                  width: 44,
                  height: 44,
                  child: _MapPin(
                    icon: Icons.store,
                    color: pickedUp
                        ? AppColors.textHint
                        : AppColors.primary,
                  ),
                ),
                Marker(
                  point: delivery,
                  width: 44,
                  height: 44,
                  child: const _MapPin(
                      icon: Icons.flag, color: AppColors.accent),
                ),
                if (_driverPosition != null)
                  Marker(
                    point: _driverPosition!,
                    width: 54,
                    height: 54,
                    child: _DriverMarker(heading: _heading),
                  ),
              ],
            ),
          ],
        ),

        // ── Chip superior: fase + distancia + ETA ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _EtaChip(
                phaseLabel: pickedUp
                    ? 'Hacia el cliente'
                    : 'Hacia ${order.branchName}',
                route: _routeTarget == target ? _route : null,
                speedKmh: _speedKmh,
              ),
            ),
          ),
        ),

        // ── Botones flotantes ──
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).size.height * 0.34,
          child: Column(
            children: [
              _RoundButton(
                icon: Icons.zoom_out_map,
                tooltip: 'Ver todo el recorrido',
                onTap: () => _fitAll(order),
              ),
              const SizedBox(height: 10),
              _RoundButton(
                icon: _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                tooltip: 'Seguir mi posición',
                active: _follow,
                onTap: _recenter,
              ),
              const SizedBox(height: 10),
              _RoundButton(
                icon: Icons.navigation,
                tooltip: 'Abrir en Google Maps',
                onTap: () => _launch(Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=driving')),
              ),
              const SizedBox(height: 10),
              _RoundButton(
                icon: Icons.chat_bubble_outline,
                tooltip: 'Chat del pedido',
                onTap: () => context.push(
                    AppRoutes.orderChat(order.orderId, order.code)),
              ),
            ],
          ),
        ),

        // ── Hoja deslizable con detalles y acción ──
        DraggableScrollableSheet(
          initialChildSize: 0.30,
          minChildSize: 0.18,
          maxChildSize: 0.72,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                        _StatusStepper(status: order.status),
                        const SizedBox(height: 16),
                        _DetailsContent(order: order, launch: _launch),
                      ],
                    ),
                  ),
                  _ActionBar(order: order, busy: _busy, onAdvance: _advance),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.driverAccepted:
        return AppColors.orderAccepted;
      case OrderStatus.pickedUp:
        return AppColors.orderPickedUp;
      case OrderStatus.onTheWay:
        return AppColors.orderOnTheWay;
      case OrderStatus.delivered:
        return AppColors.orderDelivered;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

class _DriverMarker extends StatelessWidget {
  final double heading;

  const _DriverMarker({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(Icons.navigation, color: Colors.white, size: 26),
      ),
    );
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

class _EtaChip extends StatelessWidget {
  final String phaseLabel;
  final RouteResult? route;
  final double speedKmh;

  const _EtaChip({
    required this.phaseLabel,
    required this.route,
    required this.speedKmh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phaseLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (route != null) ...[
            Text(
              '${route!.distanceLabel} · ${route!.etaLabel}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ] else
            const Text(
              'Calculando…',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          if (speedKmh > 1) ...[
            const SizedBox(width: 8),
            Text(
              '${speedKmh.round()} km/h',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? AppColors.primary : Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 22,
              color: active ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final OrderStatus status;

  const _StatusStepper({required this.status});

  static const _steps = [
    (OrderStatus.driverAccepted, Icons.store, 'Recoger'),
    (OrderStatus.pickedUp, Icons.motorcycle, 'En ruta'),
    (OrderStatus.onTheWay, Icons.flag, 'Entregar'),
  ];

  int get _currentIndex {
    switch (status) {
      case OrderStatus.driverAccepted:
        return 0;
      case OrderStatus.pickedUp:
        return 1;
      case OrderStatus.onTheWay:
        return 2;
      case OrderStatus.delivered:
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                color: i <= current
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.primary : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  i < current ? Icons.check : _steps[i].$2,
                  size: 18,
                  color:
                      i <= current ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _steps[i].$3,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      i == current ? FontWeight.w700 : FontWeight.w500,
                  color: i <= current
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DetailsContent extends StatelessWidget {
  final DeliveryOrder order;
  final Future<void> Function(Uri) launch;

  const _DetailsContent({required this.order, required this.launch});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContactRow(
          icon: Icons.store,
          iconColor: AppColors.primary,
          title: 'Recojo',
          value: order.branchName,
          phone: order.branchPhone,
          launch: launch,
        ),
        const SizedBox(height: 10),
        _ContactRow(
          icon: Icons.flag,
          iconColor: AppColors.accent,
          title: 'Entrega',
          value:
              '${order.deliveryAddress}${order.deliveryReference != null ? '\nRef: ${order.deliveryReference}' : ''}',
          phone: null,
          launch: launch,
        ),
        const SizedBox(height: 10),
        _ContactRow(
          icon: Icons.person,
          iconColor: AppColors.success,
          title: 'Cliente',
          value: order.recipientName,
          phone: order.recipientPhone.isEmpty ? null : order.recipientPhone,
          launch: launch,
        ),
        if (order.specialInstructions?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          InfoTile(
            icon: Icons.sticky_note_2_outlined,
            title: 'Instrucciones',
            value: order.specialInstructions!,
            iconColor: AppColors.warning,
          ),
        ],
        if (order.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(title: 'Productos'),
          const SizedBox(height: 4),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    item.lineTotal.toCurrency,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: order.mustCollectPayment
                ? AppColors.warning.withOpacity(0.1)
                : AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: order.mustCollectPayment
                  ? AppColors.warning.withOpacity(0.5)
                  : AppColors.success.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                order.mustCollectPayment
                    ? Icons.payments_outlined
                    : Icons.check_circle_outline,
                color: order.mustCollectPayment
                    ? AppColors.warning
                    : AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.mustCollectPayment
                      ? 'COBRAR al cliente'
                          '${order.paymentMethodName.isNotEmpty ? ' (${order.paymentMethodName})' : ''}'
                      : 'Pedido PAGADO — no cobrar'
                          '${order.paymentMethodName.isNotEmpty ? ' (${order.paymentMethodName})' : ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                order.mustCollectPayment ? order.total.toCurrency : '',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tu ganancia (envío)',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(
              order.deliveryFee.toCurrency,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? phone;
  final Future<void> Function(Uri) launch;

  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.phone,
    required this.launch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InfoTile(
            icon: icon,
            title: title,
            value: value,
            iconColor: iconColor,
          ),
        ),
        if (phone != null)
          IconButton(
            onPressed: () => launch(Uri.parse('tel:$phone')),
            icon: const Icon(Icons.phone, color: AppColors.success),
            tooltip: 'Llamar',
          ),
      ],
    );
  }
}

class _DetailsList extends StatelessWidget {
  final DeliveryOrder order;
  final Future<void> Function(Uri) launch;

  const _DetailsList({required this.order, required this.launch});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusStepper(status: order.status),
        const SizedBox(height: 16),
        _DetailsContent(order: order, launch: launch),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final DeliveryOrder order;
  final bool busy;
  final Future<void> Function(DeliveryOrder) onAdvance;

  const _ActionBar({
    required this.order,
    required this.busy,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final label = order.status.nextActionLabel;
    if (label == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: busy ? null : () => onAdvance(order),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: order.status == OrderStatus.onTheWay
                  ? AppColors.success
                  : AppColors.primary,
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
