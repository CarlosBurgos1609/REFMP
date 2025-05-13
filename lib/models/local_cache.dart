import 'package:hive_flutter/hive_flutter.dart';

class LocalCache {
  static Future<void> saveData(
      String boxName, List<Map<String, dynamic>> data) async {
    final box = await Hive.openBox(boxName);
    await box.put('data', data);
  }

  static Future<List<Map<String, dynamic>>> getData(String boxName) async {
    final box = await Hive.openBox(boxName);
    final data = box.get('data', defaultValue: []);
    return List<Map<String, dynamic>>.from(data);
  }
}
