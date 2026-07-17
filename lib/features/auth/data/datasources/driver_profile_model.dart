import '../../domain/entities/driver_profile.dart';

class DriverProfileModel extends DriverProfile {
  const DriverProfileModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.email,
    required super.phone,
    super.avatarUrl,
    super.dni,
    super.licenseNumber,
    required super.vehicleType,
    super.vehicleTypeName,
    super.licensePlate,
    required super.notificationsEnabled,
    required super.locationEnabled,
    required super.status,
    super.isOnline,
    super.currentOrderId,
    required super.isActive,
    required super.isVerified,
    required super.rating,
    required super.createdAt,
  });

  /// Combina las filas de profiles, drivers, driver_current_state y vehicles.
  factory DriverProfileModel.fromRows({
    required Map<String, dynamic> profile,
    Map<String, dynamic>? driver,
    Map<String, dynamic>? state,
    Map<String, dynamic>? vehicleType,
    Map<String, dynamic>? vehicle,
  }) {
    return DriverProfileModel(
      id: profile['user_id'] as String,
      userId: profile['user_id'] as String,
      fullName: profile['full_name'] as String? ?? '',
      email: profile['email'] as String? ?? '',
      phone: profile['phone'] as String? ?? '',
      avatarUrl: profile['avatar_url'] as String?,
      dni: profile['dni'] as String?,
      licenseNumber: driver?['license_number'] as String?,
      vehicleType: vehicleType?['code'] as String? ?? '',
      vehicleTypeName: vehicleType?['name'] as String? ?? '',
      licensePlate: vehicle?['plate'] as String?,
      notificationsEnabled: profile['notifications_enabled'] as bool? ?? false,
      locationEnabled: profile['location_enabled'] as bool? ?? false,
      status: DriverStatusExtension.fromString(state?['status'] as String?),
      isOnline: state?['is_online'] as bool? ?? false,
      currentOrderId: state?['current_order_id'] as String?,
      isActive: profile['is_active'] as bool? ?? false,
      isVerified: driver?['is_verified'] as bool? ?? false,
      rating: (driver?['rating_avg'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(profile['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
