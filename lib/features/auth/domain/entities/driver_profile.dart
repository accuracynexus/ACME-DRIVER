import 'package:equatable/equatable.dart';

/// Estado operativo en tiempo real del repartidor (tabla driver_current_state).
enum DriverState { offline, available, busy, paused }

extension DriverStateX on DriverState {
  String get value {
    switch (this) {
      case DriverState.offline:
        return 'offline';
      case DriverState.available:
        return 'available';
      case DriverState.busy:
        return 'busy';
      case DriverState.paused:
        return 'paused';
    }
  }

  String get label {
    switch (this) {
      case DriverState.offline:
        return 'Desconectado';
      case DriverState.available:
        return 'Disponible';
      case DriverState.busy:
        return 'En entrega';
      case DriverState.paused:
        return 'En pausa';
    }
  }

  static DriverState fromString(String? v) {
    switch (v) {
      case 'available':
        return DriverState.available;
      case 'busy':
        return DriverState.busy;
      case 'paused':
        return DriverState.paused;
      default:
        return DriverState.offline;
    }
  }
}

/// Perfil completo del repartidor: combina profiles + drivers +
/// driver_current_state + vehículo principal.
class DriverProfile extends Equatable {
  // profiles
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? dni;
  final DateTime? birthday;
  final bool isActive;
  final bool notificationsEnabled;
  final bool locationEnabled;

  // drivers
  final bool isVerified;
  final double ratingAvg;
  final String? licenseNumber;
  final String? documentNumber;
  final String? vehicleTypeId;
  final String? vehicleTypeName;

  // vehículo principal
  final String? plate;
  final String? vehicleBrand;
  final String? vehicleModel;

  // driver_current_state
  final DriverState state;
  final bool isOnline;
  final String? currentOrderId;
  final double? lastLat;
  final double? lastLng;

  final DateTime? joinedAt;

  const DriverProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.dni,
    this.birthday,
    required this.isActive,
    required this.notificationsEnabled,
    required this.locationEnabled,
    required this.isVerified,
    required this.ratingAvg,
    this.licenseNumber,
    this.documentNumber,
    this.vehicleTypeId,
    this.vehicleTypeName,
    this.plate,
    this.vehicleBrand,
    this.vehicleModel,
    required this.state,
    required this.isOnline,
    this.currentOrderId,
    this.lastLat,
    this.lastLng,
    this.joinedAt,
  });

  /// El repartidor puede operar (conectarse, recibir pedidos) solo si está
  /// verificado por el administrador y su cuenta está activa.
  bool get isApproved => isVerified && isActive;

  @override
  List<Object?> get props =>
      [userId, isVerified, isActive, state, isOnline, currentOrderId];
}
