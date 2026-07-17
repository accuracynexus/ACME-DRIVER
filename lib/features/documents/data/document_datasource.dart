import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/driver_document.dart';

class DocumentDataSource {
  final SupabaseClient _client;
  DocumentDataSource(this._client);

  Future<List<DriverDocument>> getDocuments(String driverId) async {
    final data = await _client
        .from(AppConstants.driverDocumentsTable)
        .select()
        .eq('driver_id', driverId);
    return (data as List)
        .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sube el archivo al bucket privado y registra el documento (RPC).
  Future<void> uploadAndSubmit({
    required String type,
    required Uint8List bytes,
    required String extension,
    String contentType = 'image/jpeg',
    String? documentNumber,
    DateTime? expiresAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('No autenticado');

    final path =
        '$uid/${type}_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from(AppConstants.driverDocumentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    await _client.rpc(AppConstants.rpcSubmitDriverDocument, params: {
      'p_document_type': type,
      'p_file_url': path,
      'p_document_number': documentNumber,
      'p_expires_at': expiresAt?.toIso8601String(),
    });
  }
}
