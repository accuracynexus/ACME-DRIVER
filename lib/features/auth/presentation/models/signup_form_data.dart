import 'dart:typed_data';
import '../../../../core/extensions/extensions.dart';
import '../../../documents/domain/driver_document.dart';

class PickedDoc {
  final Uint8List bytes;
  final String extension;
  final String contentType;
  const PickedDoc(this.bytes, this.extension, this.contentType);
}

class SignUpFormData {
  // Paso 1 · Datos personales
  String fullName = '';
  String email = '';
  String phone = '';
  String password = '';
  String dni = '';

  // Paso 2 · Vehículo (vehicle_types.code: bicycle/motorcycle/car/walker)
  String vehicleTypeCode = 'motorcycle';
  String licenseNumber = '';
  String plate = '';
  String brand = '';
  String model = '';

  // Paso 3 · Documentos (se suben tras crear la cuenta)
  final Map<DocType, PickedDoc> documents = {};

  // Paso 4 · Permisos y términos
  bool locationEnabled = false;
  bool notificationsEnabled = false;
  bool acceptedTerms = false;

  bool get isMotorized =>
      vehicleTypeCode == 'motorcycle' || vehicleTypeCode == 'car';

  /// Documentos requeridos según el tipo de vehículo.
  List<DocType> get requiredDocs => [
        DocType.dniFront,
        DocType.dniBack,
        if (isMotorized) DocType.license,
        if (isMotorized) DocType.vehiclePhoto,
      ];

  bool isStep1Valid() =>
      fullName.trim().isNotEmpty &&
      email.isValidEmail &&
      phone.isValidPhone &&
      dni.isValidIdentificationNumber &&
      password.isStrongPassword;

  bool isStep2Valid() {
    if (isMotorized) {
      if (!plate.isValidLicensePlate) return false;
      if (!licenseNumber.isValidLicenseNumber) return false;
    }
    return true;
  }

  bool isStep3Valid() =>
      requiredDocs.every((d) => documents.containsKey(d));

  bool isStep4Valid() => acceptedTerms;

  Map<String, dynamic> toMetadata() => {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'dni': dni.trim(),
        'vehicleTypeCode': vehicleTypeCode,
        'licenseNumber': licenseNumber.trim().isEmpty ? null : licenseNumber.trim(),
        'plate': plate.trim().isEmpty ? null : plate.trim().toUpperCase(),
        'brand': brand.trim().isEmpty ? null : brand.trim(),
        'model': model.trim().isEmpty ? null : model.trim(),
        'color': null,
        'birthday': null,
        'notificationsEnabled': notificationsEnabled,
        'locationEnabled': locationEnabled,
      };
}
