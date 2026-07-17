import 'package:equatable/equatable.dart';

/// Perfil combinado del repartidor: profiles + drivers + driver_current_state.
class DriverProfile extends Equatable {
  final String id; // user_id (auth.uid)
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? dni;
  final String? licenseNumber;
  final String vehicleType; // código: motorcycle, bicycle, car, walker
  final String vehicleTypeName; // nombre legible: Motocicleta, ...
  final String? licensePlate;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final DriverStatus status; // driver_current_state.status
  final bool isOnline;
  final String? currentOrderId;
  final bool isActive; // profiles.is_active
  final bool isVerified; // drivers.is_verified
  final double rating;
  final DateTime createdAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.dni,
    this.licenseNumber,
    required this.vehicleType,
    this.vehicleTypeName = '',
    this.licensePlate,
    required this.notificationsEnabled,
    required this.locationEnabled,
    required this.status,
    this.isOnline = false,
    this.currentOrderId,
    required this.isActive,
    required this.isVerified,
    required this.rating,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, status, isOnline, isActive, currentOrderId];
}

enum DriverStatus { available, busy, paused, offline }

extension DriverStatusExtension on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.available:
        return 'Disponible';
      case DriverStatus.busy:
        return 'Ocupado';
      case DriverStatus.paused:
        return 'En pausa';
      case DriverStatus.offline:
        return 'Desconectado';
    }
  }

  String get value {
    switch (this) {
      case DriverStatus.available:
        return 'available';
      case DriverStatus.busy:
        return 'busy';
      case DriverStatus.paused:
        return 'paused';
      case DriverStatus.offline:
        return 'offline';
    }
  }

  static DriverStatus fromString(String? value) {
    switch (value) {
      case 'available':
        return DriverStatus.available;
      case 'busy':
        return DriverStatus.busy;
      case 'paused':
        return DriverStatus.paused;
      default:
        return DriverStatus.offline;
    }
  }
}
