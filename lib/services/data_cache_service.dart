import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataCacheService {
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchWithCache({
    required String table,
    required String boxName,
    String? select,
    String? orderBy,
    bool ascending = true,
  }) async {
    final box = await Hive.openBox(boxName);

    try {
      final query = _client.from(table).select(select ?? '*');
      if (orderBy != null) {
        query.order(orderBy, ascending: ascending);
      }
      final result = await query;

      // Guardar localmente
      await box.put('data', result);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      // Retornar datos desde Hive si hay error
      final localData = box.get('data', defaultValue: []);
      return List<Map<String, dynamic>>.from(localData);
    }
  }
}
