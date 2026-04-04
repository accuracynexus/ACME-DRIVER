import 'package:equatable/equatable.dart';

class DriverProfile extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final String? address;
  final String? identificationNumber;
  final String? identificationType;
  final String vehicleType;
  final String? licensePlate;
  final String? licenseNumber;
  final String? bankAccount;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final DriverStatus status;
  final bool isActive;
  final double rating;
  final int totalDeliveries;
  final double earnings;
  final bool isVerified;
  final DateTime createdAt;

  const DriverProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.address,
    this.identificationNumber,
    this.identificationType,
    required this.vehicleType,
    this.licensePlate,
    this.licenseNumber,
    this.bankAccount,
    required this.notificationsEnabled,
    required this.locationEnabled,
    required this.status,
    required this.isActive,
    required this.rating,
    required this.totalDeliveries,
    required this.earnings,
    required this.isVerified,
    required this.createdAt,
  });

  DriverProfile copyWith({
    DriverStatus? status,
    bool? isActive,
    String? photoUrl,
    String? phone,
    bool? notificationsEnabled,
    bool? locationEnabled,
  }) {
    return DriverProfile(
      id: id,
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address,
      identificationNumber: identificationNumber,
      identificationType: identificationType,
      vehicleType: vehicleType,
      licensePlate: licensePlate,
      licenseNumber: licenseNumber,
      bankAccount: bankAccount,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      rating: rating,
      totalDeliveries: totalDeliveries,
      earnings: earnings,
      isVerified: isVerified,
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
