// ignore_for_file: unnecessary_null_comparison

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:refmp/interfaces/instrumentsDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

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

class HeadquartersInfo extends StatefulWidget {
  final String id;
  final String name;
  final Map<String, dynamic>? sedeData;

  const HeadquartersInfo({
    super.key,
    required this.id,
    required this.name,
    this.sedeData,
  });

  @override
  State<HeadquartersInfo> createState() => _HeadquartersInfoState();
}

class _HeadquartersInfoState extends State<HeadquartersInfo> {
  late Future<Map<String, dynamic>> sedeFuture;
  late Future<List<Map<String, dynamic>>> instrumentsFuture;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    sedeFuture = _fetchSedeData();
    instrumentsFuture = _fetchInstruments();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        setState(() {
          sedeFuture = _fetchSedeData();
          instrumentsFuture = _fetchInstruments();
        });
      }
    });
  }

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Hive box offline_data opened successfully');
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

  Future<String> _downloadAndCacheImage(String url, String cacheKey) async {
    final box = Hive.box('offline_data');
    final cachedPath = box.get(cacheKey);

    if (cachedPath != null && await File(cachedPath).exists()) {
      debugPrint('Using cached image: $cachedPath');
      return cachedPath;
    }

    try {
      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      await box.put(cacheKey, filePath);
      debugPrint('Image downloaded and cached: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> _fetchSedeData() async {
    if (widget.sedeData != null) {
      return widget.sedeData!;
    }

    final box = Hive.box('offline_data');
    final cacheKey = 'sedes_data_${widget.id}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from("sedes")
            .select()
            .eq('id', widget.id)
            .maybeSingle();
        if (response != null) {
          final data = Map<String, dynamic>.from(response);
          final photo = data['photo'] ?? '';
          if (photo.isNotEmpty) {
            try {
              final localPath =
                  await _downloadAndCacheImage(photo, 'photo_$cacheKey');
              data['local_photo_path'] = localPath;
            } catch (e) {
              debugPrint('Error caching sede photo: $e');
            }
          }
          await box.put(cacheKey, data);
          debugPrint('Sede data saved to Hive with key: $cacheKey');
          return data;
        }
      } catch (e) {
        debugPrint('Error fetching sede data from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: {'name': widget.name});
    debugPrint('Loaded sede data from cache: $cachedData');
    return Map<String, dynamic>.from(cachedData);
  }

  Future<List<Map<String, dynamic>>> _fetchInstruments() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'sede_instruments_${widget.id}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response =
            await Supabase.instance.client.from('sede_instruments').select('''
              instruments (
                id,
                name,
                image
              )
            ''').eq('sede_id', widget.id);
        final data = List<Map<String, dynamic>>.from(response).map((item) {
          final image = item['instruments']['image'] ?? '';
          return {
            'id': item['instruments']['id'] ?? 0,
            'name': item['instruments']['name'] ?? 'Instrumento desconocido',
            'image': image,
          };
        }).toList();

        for (var instrument in data) {
          final image = instrument['image'] ?? '';
          if (image.isNotEmpty) {
            try {
              final localPath = await _downloadAndCacheImage(
                  image, 'instrument_image_${instrument['id']}');
              instrument['local_image_path'] = localPath;
            } catch (e) {
              debugPrint('Error caching instrument image: $e');
            }
          }
        }
        await box.put(cacheKey, data);
        debugPrint('Instruments saved to Hive with key: $cacheKey');
        return data;
      } catch (e) {
        debugPrint('Error fetching instruments from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    debugPrint('Loaded instruments from cache: $cachedData');
    return List<Map<String, dynamic>>.from(
        cachedData.map((item) => Map<String, dynamic>.from(item)));
  }

  void _openMap(String address) async {
    final uri = Uri.parse('https://maps.google.com/?q=$address');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el mapa")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: Future.wait([sedeFuture, instrumentsFuture]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }

          final sedeData = snapshot.data != null && snapshot.data!.isNotEmpty
              ? snapshot.data![0] as Map<String, dynamic>
              : {'name': widget.name};
          final instruments = snapshot.data != null && snapshot.data!.length > 1
              ? snapshot.data![1] as List<Map<String, dynamic>>
              : [];

          final name = sedeData['name'] ?? widget.name;
          final photo = sedeData['local_photo_path'] ?? sedeData['photo'] ?? '';
          final typeHeadquarters =
              sedeData['type_headquarters'] ?? 'No disponible';
          final description = sedeData['description'] ?? 'Sin descripción';
          final address = sedeData['address'] ?? 'Dirección no disponible';
          final contactNumber = sedeData['contact_number'] ?? 'No disponible';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                backgroundColor: Colors.blue,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16.0),
                  background: photo.isNotEmpty
                      ? (File(photo).existsSync()
                          ? Image.file(
                              File(photo),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset('assets/images/refmmp.png',
                                      fit: BoxFit.cover),
                            )
                          : CachedNetworkImage(
                              imageUrl: sedeData['photo'] ?? '',
                              cacheManager: CustomCacheManager.instance,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover),
                            ))
                      : Image.asset('assets/images/refmmp.png',
                          fit: BoxFit.cover),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('| Tipo de sede',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(typeHeadquarters, style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 20),
                      const Text('| Instrumentos',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: instruments.isEmpty
                            ? [const Text('No hay instrumentos disponibles')]
                            : instruments.map((instrument) {
                                final instrumentName = instrument['name'] ??
                                    'Instrumento desconocido';
                                final instrumentImage =
                                    instrument['local_image_path'] ??
                                        instrument['image'] ??
                                        '';
                                final instrumentId =
                                    instrument['id'] as int? ?? 0;

                                return GestureDetector(
                                  onTap: () {
                                    if (instrumentId != 0) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              InstrumentDetailPage(
                                            instrumentId: instrumentId,
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "ID de instrumento no válido"),
                                        ),
                                      );
                                    }
                                  },
                                  child: Chip(
                                    avatar: instrumentImage.isNotEmpty
                                        ? CircleAvatar(
                                            backgroundImage: File(
                                                        instrumentImage)
                                                    .existsSync()
                                                ? FileImage(
                                                    File(instrumentImage))
                                                : CachedNetworkImageProvider(
                                                    instrument['image'] ?? '',
                                                    cacheManager:
                                                        CustomCacheManager
                                                            .instance,
                                                  ),
                                            radius: 12,
                                            backgroundColor: Colors.white,
                                          )
                                        : null,
                                    label: Text(
                                      instrumentName,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white),
                                    ),
                                    backgroundColor: Colors.blue.shade300,
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                  ),
                                );
                              }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('| Descripción',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(description),
                      const SizedBox(height: 20),
                      const Text('| Número de contacto',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(contactNumber),
                      const SizedBox(height: 20),
                      const Text('| Ubicación',
                          style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openMap(address),
                              child: Text(address,
                                  style: const TextStyle(color: Colors.blue)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
