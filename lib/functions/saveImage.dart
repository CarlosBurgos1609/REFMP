import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<String> downloadAndSaveImage(String imageUrl, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');

  if (await file.exists()) return file.path;

  try {
    final response = await Dio().get(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    await file.writeAsBytes(response.data);
    return file.path;
  } catch (e) {
    throw Exception("Error al descargar imagen: $e");
  }
}
