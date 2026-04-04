import '../../domain/entities/driver_profile.dart';

class DriverProfileModel extends DriverProfile {
  const DriverProfileModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.email,
    required super.phone,
    super.photoUrl,
    super.address,
    super.identificationNumber,
    super.identificationType,
    required super.vehicleType,
    super.licensePlate,
    super.licenseNumber,
    super.bankAccount,
    required super.notificationsEnabled,
    required super.locationEnabled,
    required super.status,
    required super.isActive,
    required super.rating,
    required super.totalDeliveries,
    required super.earnings,
    required super.isVerified,
    required super.createdAt,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      address: json['address'] as String?,
      identificationNumber: json['identification_number'] as String?,
      identificationType: json['identification_type'] as String? ?? 'cedula',
      vehicleType: json['vehicle_type'] as String? ?? 'moto',
      licensePlate: json['license_plate'] as String?,
      licenseNumber: json['license_number'] as String?,
      bankAccount: json['bank_account'] as String?,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      locationEnabled: json['location_enabled'] as bool? ?? false,
      status: DriverStatusExtension.fromString(json['status'] as String? ?? 'offline'),
      isActive: json['is_active'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: json['total_deliveries'] as int? ?? 0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
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
      'address': address,
      'identification_number': identificationNumber,
      'identification_type': identificationType,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'license_number': licenseNumber,
      'bank_account': bankAccount,
      'notifications_enabled': notificationsEnabled,
      'location_enabled': locationEnabled,
      'status': status.value,
      'is_active': isActive,
      'rating': rating,
      'total_deliveries': totalDeliveries,
      'earnings': earnings,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
