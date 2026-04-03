import 'package:equatable/equatable.dart';

class DriverProfile extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final String vehicleType;
  final String? licensePlate;
  final DriverStatus status;
  final bool isActive;
  final DateTime createdAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.vehicleType,
    this.licensePlate,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  DriverProfile copyWith({
    DriverStatus? status,
    bool? isActive,
    String? photoUrl,
    String? phone,
  }) {
    return DriverProfile(
      id: id,
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType,
      licensePlate: licensePlate,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, status, isActive];
}

enum DriverStatus { available, busy, offline }

extension DriverStatusExtension on DriverStatus {
  String get label {
    switch (this) {
      case DriverStatus.available:
        return 'Disponible';
      case DriverStatus.busy:
        return 'Ocupado';
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
      case DriverStatus.offline:
        return 'offline';
    }
  }

  static DriverStatus fromString(String value) {
    switch (value) {
      case 'available':
        return DriverStatus.available;
      case 'busy':
        return DriverStatus.busy;
      default:
        return DriverStatus.offline;
    }
  }
}
