import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/route_service.dart';
import '../../../../core/utils/navigation_launcher.dart';

/// Color de marca de Waze (cyan) para el botón de navegación.
const Color _wazeColor = Color(0xFF33CCFF);

/// Mapa interactivo (OpenStreetMap, sin API key) que muestra el local de
/// recojo, el destino del cliente y, si está disponible, la posición del
/// repartidor, con la ruta por calles (OSRM) entre ellos y su distancia/ETA.
class OrderMap extends StatefulWidget {
  final double? branchLat;
  final double? branchLng;
  final double? clientLat;
  final double? clientLng;
  final double? driverLat;
  final double? driverLng;
  final double height;

  /// Destino de la etapa actual (local antes de recoger, cliente después)
  /// para los botones de navegación externa (Maps/Waze) con tráfico en vivo.
  final double? navLat;
  final double? navLng;
  final String? navLabel;

  const OrderMap({
    super.key,
    this.branchLat,
    this.branchLng,
    this.clientLat,
    this.clientLng,
    this.driverLat,
    this.driverLng,
    this.height = 220,
    this.navLat,
    this.navLng,
    this.navLabel,
  });

  @override
  State<OrderMap> createState() => _OrderMapState();
}

class _OrderMapState extends State<OrderMap> {
  final RouteService _routeService = RouteService();
  RouteResult? _route;

  LatLng? get _branch => (widget.branchLat != null && widget.branchLng != null)
      ? LatLng(widget.branchLat!, widget.branchLng!)
      : null;
  LatLng? get _client => (widget.clientLat != null && widget.clientLng != null)
      ? LatLng(widget.clientLat!, widget.clientLng!)
      : null;
  LatLng? get _driver => (widget.driverLat != null && widget.driverLng != null)
      ? LatLng(widget.driverLat!, widget.driverLng!)
      : null;

  List<LatLng> get _waypoints => [
        if (_driver != null) _driver!,
        if (_branch != null) _branch!,
        if (_client != null) _client!,
      ];

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(covariant OrderMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchLat != widget.branchLat ||
        oldWidget.branchLng != widget.branchLng ||
        oldWidget.clientLat != widget.clientLat ||
        oldWidget.clientLng != widget.clientLng ||
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng) {
      _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    final wps = _waypoints;
    if (wps.length < 2) return;
    final result = await _routeService.getRouteThrough(wps);
    if (mounted && result != null) {
      setState(() => _route = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _waypoints;

    // Sin coordenadas no hay nada que mostrar.
    if (points.isEmpty) {
      return _MapPlaceholder(height: widget.height);
    }

    // Ruta por calles si OSRM respondió; si no, línea recta entre puntos.
    final routePoints = _route?.points ?? points;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 14,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(48),
                        maxZoom: 16,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  // CartoDB "Voyager": estilo claro/amigable estilo Google Maps,
                  // gratuito y sin API key (solo requiere atribución).
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  userAgentPackageName: 'com.acme.acme_driver',
                  maxZoom: 20,
                ),
                if (routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4,
                        color: AppColors.primary.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_branch != null)
                      _pin(_branch!, PhosphorIconsFill.storefront,
                          AppColors.primary),
                    if (_client != null)
                      _pin(_client!, PhosphorIconsFill.mapPin, AppColors.accent),
                    if (_driver != null)
                      _pin(_driver!, PhosphorIconsFill.motorcycle,
                          AppColors.info),
                  ],
                ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap, © CARTO'),
                  ],
                ),
              ],
            ),
            if (_route != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsFill.navigationArrow,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${_route!.distanceLabel} · ${_route!.etaLabel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Botones de navegación externa con tráfico en vivo (Maps/Waze)
            // hacia el destino de la etapa actual.
            if (widget.navLat != null && widget.navLng != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                  children: [
                    _NavButton(
                      icon: PhosphorIconsFill.navigationArrow,
                      color: AppColors.primary,
                      tooltip: 'Abrir en Google Maps',
                      onTap: () => NavigationLauncher.navigateTo(
                          widget.navLat!, widget.navLng!,
                          label: widget.navLabel),
                    ),
                    const SizedBox(height: 8),
                    _NavButton(
                      icon: PhosphorIconsFill.car,
                      color: _wazeColor,
                      tooltip: 'Abrir en Waze',
                      onTap: () => NavigationLauncher.navigateWithWaze(
                          widget.navLat!, widget.navLng!),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _pin(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Botón circular pequeño para lanzar navegación externa desde el mapa.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black45,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final double height;
  const _MapPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsRegular.mapTrifold,
              size: 40, color: AppColors.textHint),
          SizedBox(height: 8),
          Text('Ubicación no disponible',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
