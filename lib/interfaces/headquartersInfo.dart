// ignore_for_file: unnecessary_null_comparison

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:refmp/interfaces/instrumentsDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class HeadquartersInfo extends StatefulWidget {
  final String id;
  final String name;

  const HeadquartersInfo({
    super.key,
    required this.id,
    required this.name,
  });

  @override
  State<HeadquartersInfo> createState() => _HeadquartersInfoState();
}

class _HeadquartersInfoState extends State<HeadquartersInfo> {
  @override
  void initState() {
    super.initState();
    _precacheImages();
  }

  Future<void> _precacheImages() async {
    final isOnline = await _checkConnectivity();
    if (isOnline) {
      final sedeData = await _fetchSedeData();
      final instruments = await _fetchInstruments();
      final photo = sedeData['photo'] ?? '';
      if (photo.isNotEmpty) {
        // No usamos CustomCacheManager; CachedNetworkImage maneja el caché internamente
        await precacheImage(CachedNetworkImageProvider(photo), context);
      }
      for (var instrument in instruments) {
        final image = instrument['image'] ?? '';
        if (image.isNotEmpty) {
          await precacheImage(CachedNetworkImageProvider(image), context);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _fetchSedeData() async {
    final box = await Hive.openBox('offline_data');
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
          debugPrint('Fetched sede data from Supabase: $data');
          await box.put(cacheKey, data);
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
    final box = await Hive.openBox('offline_data');
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
        final data = List<Map<String, dynamic>>.from(response)
            .map((item) => {
                  'id': item['instruments']['id'] ?? 0,
                  'name':
                      item['instruments']['name'] ?? 'Instrumento desconocido',
                  'image': item['instruments']['image'] ?? '',
                })
            .toList();
        debugPrint('Fetched instruments from Supabase: $data');
        await box.put(cacheKey, data);
        return data;
      } catch (e) {
        debugPrint('Error fetching instruments from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    debugPrint('Loaded instruments from cache: $cachedData');
    return List<Map<String, dynamic>>.from(cachedData);
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
        future: Future.wait([_fetchSedeData(), _fetchInstruments()]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }

          // Manejo robusto de datos offline
          final sedeData = snapshot.data != null && snapshot.data!.isNotEmpty
              ? snapshot.data![0] as Map<String, dynamic>
              : {'name': widget.name};
          final instruments = snapshot.data != null && snapshot.data!.length > 1
              ? snapshot.data![1] as List<Map<String, dynamic>>
              : [];

          final name = sedeData['name'] ?? widget.name;
          final photo = sedeData['photo'] ?? '';
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
                      ? CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/refmmp.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de sede:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(typeHeadquarters),
                      const SizedBox(height: 20),
                      const Text(
                        'Descripción:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(description),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openMap(address),
                              child: Text(
                                address,
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Número de contacto:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(contactNumber),
                      const SizedBox(height: 20),
                      const Text(
                        'Instrumentos:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                                    instrument['image'] ?? '';
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
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                              instrumentImage,
                                            ),
                                            radius: 12,
                                          )
                                        : null,
                                    label: Text(
                                      instrumentName,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.blue.shade100,
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                  ),
                                );
                              }).toList(),
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
