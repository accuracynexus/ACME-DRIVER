import '../../domain/entities/driver_profile.dart';

class DriverProfileModel extends DriverProfile {
  const DriverProfileModel({
    required super.userId,
    required super.fullName,
    required super.email,
    required super.phone,
    super.avatarUrl,
    super.dni,
    super.birthday,
    required super.isActive,
    required super.notificationsEnabled,
    required super.locationEnabled,
    required super.isVerified,
    required super.ratingAvg,
    super.licenseNumber,
    super.documentNumber,
    super.vehicleTypeId,
    super.vehicleTypeName,
    super.plate,
    super.vehicleBrand,
    super.vehicleModel,
    required super.state,
    required super.isOnline,
    super.currentOrderId,
    super.lastLat,
    super.lastLng,
    super.joinedAt,
  });

  /// Construye el perfil a partir de un mapa combinado (profiles + drivers +
  /// driver_current_state + vehicle + vehicle_type).
  factory DriverProfileModel.fromMerged(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    double? toD(dynamic v) => v == null ? null : (v as num).toDouble();

    return DriverProfileModel(
      userId: j['user_id'] as String,
      fullName: j['full_name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      avatarUrl: j['avatar_url'] as String?,
      dni: j['dni'] as String?,
      birthday: parseDate(j['birthday']),
      isActive: j['is_active'] as bool? ?? false,
      notificationsEnabled: j['notifications_enabled'] as bool? ?? false,
      locationEnabled: j['location_enabled'] as bool? ?? false,
      isVerified: j['is_verified'] as bool? ?? false,
      ratingAvg: toD(j['rating_avg']) ?? 5.0,
      licenseNumber: j['license_number'] as String?,
      documentNumber: j['document_number'] as String?,
      vehicleTypeId: j['vehicle_type_id'] as String?,
      vehicleTypeName: j['vehicle_type_name'] as String?,
      plate: j['plate'] as String?,
      vehicleBrand: j['vehicle_brand'] as String?,
      vehicleModel: j['vehicle_model'] as String?,
      state: DriverStateX.fromString(j['state'] as String?),
      isOnline: j['is_online'] as bool? ?? false,
      currentOrderId: j['current_order_id'] as String?,
      lastLat: toD(j['last_lat']),
      lastLng: toD(j['last_lng']),
      joinedAt: parseDate(j['joined_at']),
    );
  }
}
