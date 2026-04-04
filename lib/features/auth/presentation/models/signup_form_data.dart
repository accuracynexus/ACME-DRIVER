class SignUpFormData {
  // Step 1: Personal Info
  String fullName = '';
  String email = '';
  String phone = '';
  String password = '';
  String identificationNumber = '';
  String identificationType = 'cedula'; // cedula, pasaporte, licencia

  // Step 2: Vehicle Info
  String vehicleType = 'moto'; // moto, bicicleta, auto
  String licensePlate = '';
  String licenseNumber = '';

  // Step 3: Banking & Address
  String address = '';
  String bankAccount = '';

  // Step 4: Permissions
  bool locationEnabled = false;
  bool notificationsEnabled = false;

  Map<String, dynamic> toMetadata() {
    return {
      'fullName': fullName,
      'phone': phone,
      'identificationNumber': identificationNumber,
      'identificationType': identificationType,
      'vehicleType': vehicleType,
      'licensePlate': licensePlate,
      'licenseNumber': licenseNumber,
      'address': address,
      'bankAccount': bankAccount,
      'locationEnabled': locationEnabled,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  Map<String, dynamic> toProfileData(String userId) {
    return {
      'id': userId,
      'full_name': fullName,
      'role': 'driver',
      'phone': phone,
      'address': address,
      'identification_number': identificationNumber,
      'identification_type': identificationType,
      'notifications_enabled': notificationsEnabled,
      'location_enabled': locationEnabled,
    };
  }

  Map<String, dynamic> toDriverData(String userId) {
    return {
      'user_id': userId,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'license_number': licenseNumber,
      'bank_account': bankAccount,
      'status': 'offline',
      'is_active': true,
      'is_verified': false,
    };
  }
}
