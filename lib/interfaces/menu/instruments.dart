import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/instrumentsDetails.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

// Custom Cache Manager for CachedNetworkImage
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
    ),
  );
}

class InstrumentsPage extends StatefulWidget {
  const InstrumentsPage({super.key, required this.title});
  final String title;

  @override
  State<InstrumentsPage> createState() => _InstrumentsPageState();
}

class _InstrumentsPageState extends State<InstrumentsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchInstruments() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'instruments_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase
            .from('instruments')
            .select('*')
            .order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, data);
        for (var instrument in data) {
          final imageUrl = instrument['image'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        return data;
      } catch (e) {
        debugPrint('Error fetching instruments: $e');
        final cachedData = box.get(cacheKey, defaultValue: []);
        return List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));
      }
    } else {
      final cachedData = box.get(cacheKey, defaultValue: []);
      return List<Map<String, dynamic>>.from(
          cachedData.map((item) => Map<String, dynamic>.from(item)));
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Conectividad: $connectivityResult');
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  String truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length > wordLimit) {
      return '${words.take(wordLimit).join(' ')}...';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: Colors.blue,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              FutureBuilder(
                future: fetchInstruments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error al cargar los datos"));
                  }
                  final instruments = snapshot.data ?? [];

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: instruments.length,
                    itemBuilder: (context, index) {
                      final instrument = instruments[index];
                      final description = truncateText(
                          instrument['description'] ?? "Sin descripción", 9);
                      final instrumentId =
                          instrument['id'] as int? ?? 0; // Default to 0 if null

                      return GestureDetector(
                        onTap: () {
                          if (instrumentId != 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InstrumentDetailPage(
                                    instrumentId: instrumentId),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("ID de instrumento no válido")),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          margin: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: instrument['image']?.isNotEmpty ?? false
                                ? SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CachedNetworkImage(
                                      imageUrl: instrument['image'],
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(
                                              color: Colors.blue),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.image_not_supported,
                                              size: 40),
                                    ),
                                  )
                                : const Icon(Icons.image_not_supported,
                                    size: 40),
                            title: Text(
                              instrument['name'] ?? "Nombre desconocido",
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                            subtitle: Text(description,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
