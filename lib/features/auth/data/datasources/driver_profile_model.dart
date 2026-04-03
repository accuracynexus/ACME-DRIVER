import '../../domain/entities/driver_profile.dart';

class DriverProfileModel extends DriverProfile {
  const DriverProfileModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.email,
    required super.phone,
    super.photoUrl,
    required super.vehicleType,
    super.licensePlate,
    required super.status,
    required super.isActive,
    required super.createdAt,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'moto',
      licensePlate: json['license_plate'] as String?,
      status: DriverStatusExtension.fromString(json['status'] as String? ?? 'offline'),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'status': status.value,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
