import 'package:equatable/equatable.dart';

/// Tipos de documento requeridos para habilitar a un repartidor.
enum DocType { license, dniFront, dniBack, vehiclePhoto }

extension DocTypeX on DocType {
  String get value {
    switch (this) {
      case DocType.license:
        return 'license';
      case DocType.dniFront:
        return 'dni_front';
      case DocType.dniBack:
        return 'dni_back';
      case DocType.vehiclePhoto:
        return 'vehicle_photo';
    }
  }

  String get label {
    switch (this) {
      case DocType.license:
        return 'Licencia de conducir';
      case DocType.dniFront:
        return 'DNI (frente)';
      case DocType.dniBack:
        return 'DNI (reverso)';
      case DocType.vehiclePhoto:
        return 'Foto del vehículo';
    }
  }

  static DocType? fromString(String? v) {
    for (final t in DocType.values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

class DriverDocument extends Equatable {
  final String id;
  final String documentType;
  final String? documentNumber;
  final String fileUrl;
  final String status; // pending | approved | rejected
  final DateTime? expiresAt;

  const DriverDocument({
    required this.id,
    required this.documentType,
    this.documentNumber,
    required this.fileUrl,
    required this.status,
    this.expiresAt,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        id: j['id'] as String,
        documentType: j['document_type'] as String,
        documentNumber: j['document_number'] as String?,
        fileUrl: j['file_url'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        expiresAt: j['expires_at'] == null
            ? null
            : DateTime.tryParse(j['expires_at'].toString()),
      );

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'En revisión';
    }
  }

  @override
  List<Object?> get props => [id, status];
}
