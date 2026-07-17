import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/app_exceptions.dart';
import '../../shared/providers/supabase_provider.dart';

final evidenceServiceProvider = Provider<EvidenceService>((ref) {
  return EvidenceService(ref.watch(supabaseClientProvider));
});

/// Sube fotos de evidencia de entrega al bucket `driver-documents`
/// (carpeta del propio driver, permitida por RLS) y registra la fila
/// en `order_evidences` con una URL firmada de larga duración.
class EvidenceService {
  final SupabaseClient _client;

  EvidenceService(this._client);

  static const _bucket = 'driver-documents';
  static const _signedUrlSeconds = 60 * 60 * 24 * 365 * 5; // 5 años

  /// Devuelve la URL firmada de la foto subida.
  Future<String> uploadDeliveryPhoto({
    required String orderId,
    required XFile image,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppAuthException('Sesión expirada');

    try {
      final path =
          '$uid/evidence-$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _client.storage.from(_bucket).uploadBinary(
            path,
            await image.readAsBytes(),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final signedUrl = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlSeconds);

      await _client.from('order_evidences').insert({
        'order_id': orderId,
        'driver_id': uid,
        'evidence_type': 'delivery_photo',
        'file_url': signedUrl,
        if (note != null && note.isNotEmpty) 'note': note,
      });

      return signedUrl;
    } catch (e) {
      throw OrderException('No se pudo subir la evidencia: $e');
    }
  }
}
