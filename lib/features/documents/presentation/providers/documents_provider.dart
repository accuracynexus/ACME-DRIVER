import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/document_datasource.dart';
import '../../domain/driver_document.dart';

final documentDataSourceProvider = Provider<DocumentDataSource>((ref) {
  return DocumentDataSource(ref.watch(supabaseClientProvider));
});

final driverDocumentsProvider =
    FutureProvider<List<DriverDocument>>((ref) async {
  final id = ref.watch(currentDriverProvider).value?.userId ?? '';
  if (id.isEmpty) return [];
  return ref.watch(documentDataSourceProvider).getDocuments(id);
});
