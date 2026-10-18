import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/route_service.dart';
import '../../../../core/utils/navigation_launcher.dart';

/// Color de marca de Waze (cyan) para el botón de navegación.
const Color _wazeColor = Color(0xFF33CCFF);

/// Mapa interactivo (Google Maps) que muestra el local de recojo, el destino
/// del cliente y, si está disponible, la posición del repartidor, con la ruta
/// por calles (OSRM) entre ellos y su distancia/ETA.
///
/// El trazado de la ruta lo sigue calculando OSRM, no Google: es gratuito y
/// ya está integrado. Google aquí solo dibuja el mapa.
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

  final Completer<GoogleMapController> _mapController = Completer();

  /// Encuadre ya aplicado, para no reencuadrar en cada rebuild y pelearse con
  /// el repartidor mientras mueve el mapa con el dedo.
  bool _encuadrado = false;

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
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: points.first,
                zoom: 14,
              ),
              onMapCreated: (c) {
                if (!_mapController.isCompleted) _mapController.complete(c);
                _encuadrar(points);
              },
              polylines: {
                if (routePoints.length > 1)
                  Polyline(
                    polylineId: const PolylineId('ruta'),
                    points: routePoints,
                    width: 5,
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
              },
              markers: {
                if (_branch != null)
                  _pin('local', _branch!, BitmapDescriptor.hueViolet,
                      'Local de recojo'),
                if (_client != null)
                  _pin('cliente', _client!, BitmapDescriptor.hueOrange,
                      'Entrega al cliente'),
                if (_driver != null)
                  _pin('repartidor', _driver!, BitmapDescriptor.hueAzure,
                      'Tú'),
              },
              // Rotar e inclinar solo estorban en un mapa de 220 de alto que
              // se mira de reojo mientras se maneja.
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomControlsEnabled: false,
              // La barra de Google abre su app al tocar un marcador y saca al
              // repartidor de la pantalla del pedido. Los botones de navegar
              // ya están abajo a la derecha.
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
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

  /// Marcador de Google Maps.
  ///
  /// Van por color y no con los iconos de antes porque Google solo acepta
  /// imágenes (`BitmapDescriptor`), no widgets. El `infoWindow` compensa:
  /// al tocarlo dice qué punto es.
  Marker _pin(String id, LatLng punto, double tono, String titulo) {
    return Marker(
      markerId: MarkerId(id),
      position: punto,
      icon: BitmapDescriptor.defaultMarkerWithHue(tono),
      infoWindow: InfoWindow(title: titulo),
    );
  }

  /// Encuadra todos los puntos del pedido la primera vez que se dibuja.
  Future<void> _encuadrar(List<LatLng> puntos) async {
    if (_encuadrado || puntos.length < 2) return;
    _encuadrado = true;

    var surLat = puntos.first.latitude, norteLat = puntos.first.latitude;
    var oesteLng = puntos.first.longitude, esteLng = puntos.first.longitude;
    for (final p in puntos) {
      if (p.latitude < surLat) surLat = p.latitude;
      if (p.latitude > norteLat) norteLat = p.latitude;
      if (p.longitude < oesteLng) oesteLng = p.longitude;
      if (p.longitude > esteLng) esteLng = p.longitude;
    }

    final controlador = await _mapController.future;
    await controlador.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(surLat, oesteLng),
          northeast: LatLng(norteLat, esteLng),
        ),
        48,
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
