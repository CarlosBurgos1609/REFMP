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
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';

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
  late Future<Map<String, dynamic>?> directorFuture;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _refreshData();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        setState(() {
          _refreshData();
        });
      }
    });
  }

  void _refreshData() {
    sedeFuture = _fetchSedeData();
    instrumentsFuture = _fetchInstruments();
    directorFuture = _fetchDirectorData();
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
    final cachedData = box.get(cacheKey, defaultValue: null);

    // Check if cached data exists and matches the current URL
    if (cachedData != null &&
        cachedData['url'] == url &&
        await File(cachedData['path']).exists()) {
      debugPrint('Using cached image: ${cachedData['path']}');
      return cachedData['path'];
    }

    // If URL has changed or no cache exists, download the new image
    try {
      // Delete old cached file if it exists
      if (cachedData != null && await File(cachedData['path']).exists()) {
        await File(cachedData['path']).delete();
        debugPrint('Deleted old cached image: ${cachedData['path']}');
      }

      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      // Store both the file path and the URL in the cache
      await box.put(cacheKey, {'path': filePath, 'url': url});
      debugPrint('Image downloaded and cached: $filePath for URL: $url');
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

  Future<Map<String, dynamic>?> _fetchDirectorData() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'director_data_${widget.id}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        // Fetch director data directly from director_headquarters with related director info
        final response = await Supabase.instance.client
            .from('director_headquarters')
            .select('''
            directors (
              id,
              name,
              descripcion,
              image_presentation
            )
          ''')
            .eq('sede_id', widget.id)
            .maybeSingle();

        if (response == null || response['directors'] == null) {
          debugPrint('No director found for sede_id: ${widget.id}');
          await box.put(cacheKey, null);
          return null;
        }

        final directorData = Map<String, dynamic>.from(response['directors']);
        // Map 'descripcion' to 'description' for consistency in the app
        directorData['description'] = directorData['descripcion'];
        debugPrint('Director data fetched: $directorData');

        // Cache the director's image if it exists
        final image = directorData['image_presentation'] ?? '';
        if (image.isNotEmpty) {
          try {
            final localPath = await _downloadAndCacheImage(
                image, 'director_image_${directorData['id']}');
            directorData['local_image_path'] = localPath;
          } catch (e) {
            debugPrint('Error caching director image: $e');
          }
        }

        // Fetch the instrument associated with the director (optional)
        final directorId = directorData['id'];
        final instrumentResponse = await Supabase.instance.client
            .from('director_instruments')
            .select('''
            instruments (
              id,
              name,
              image
            )
          ''')
            .eq('director_id', directorId)
            .maybeSingle();

        if (instrumentResponse != null &&
            instrumentResponse['instruments'] != null) {
          final instrumentData =
              Map<String, dynamic>.from(instrumentResponse['instruments']);
          final instrumentImage = instrumentData['image'] ?? '';
          if (instrumentImage.isNotEmpty) {
            try {
              final localPath = await _downloadAndCacheImage(instrumentImage,
                  'director_instrument_image_${instrumentData['id']}');
              instrumentData['local_image_path'] = localPath;
            } catch (e) {
              debugPrint('Error caching director instrument image: $e');
            }
          }
          directorData['instrument'] = instrumentData;
          debugPrint('Instrument data fetched for director: $instrumentData');
        } else {
          debugPrint('No instrument found for director_id: $directorId');
        }

        await box.put(cacheKey, directorData);
        debugPrint('Director data saved to Hive with key: $cacheKey');
        return directorData;
      } catch (e) {
        debugPrint('Error fetching director data from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey);
    debugPrint('Loaded director data from cache: $cachedData');
    return cachedData != null ? Map<String, dynamic>.from(cachedData) : null;
  }

  void _openMap(String? ubication) async {
    if (ubication == null || ubication.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ubicación no disponible")),
      );
      return;
    }
    final uri = Uri.parse(ubication);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el mapa")),
      );
    }
  }

  void _showDescriptionDialog(String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'Descripción Completa',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blue),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 400,
            minHeight: 50,
          ),
          child: SingleChildScrollView(
            child: Text(description),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  String truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length > wordLimit) {
      return '${words.take(wordLimit).join(' ')}...';
    }
    return text;
  }

  String formatPhoneNumber(String number) {
    if (number.length >= 10) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

  void _copyPhoneNumber(String number) {
    final cleanNumber = number.replaceAll(' ', '');
    Clipboard.setData(ClipboardData(text: cleanNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Número copiado al portapapeles")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          setState(() {
            _refreshData();
          });
          await Future.wait([sedeFuture, instrumentsFuture, directorFuture]);
        },
        child: FutureBuilder(
          future: Future.wait([sedeFuture, instrumentsFuture, directorFuture]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              );
            }

            final sedeData = snapshot.data != null && snapshot.data!.isNotEmpty
                ? snapshot.data![0] as Map<String, dynamic>
                : {'name': widget.name};
            final instruments =
                snapshot.data != null && snapshot.data!.length > 1
                    ? snapshot.data![1] as List<Map<String, dynamic>>
                    : [];
            final directorData =
                snapshot.data != null && snapshot.data!.length > 2
                    ? snapshot.data![2] as Map<String, dynamic>?
                    : null;

            final name = sedeData['name'] ?? widget.name;
            final photo =
                sedeData['local_photo_path'] ?? sedeData['photo'] ?? '';
            final typeHeadquarters =
                sedeData['type_headquarters'] ?? 'No disponible';
            final description = sedeData['description'] ?? 'Sin descripción';
            final truncatedDescription = truncateText(description, 50);
            final contactNumber = sedeData['contact_number'] ?? 'No disponible';
            final ubication = sedeData['ubication'] ?? '';

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
                                errorWidget: (context, url, error) =>
                                    Image.asset('assets/images/refmmp.png',
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
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                        const SizedBox(height: 15),
                        const Text('| Descripción',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _showDescriptionDialog(description),
                          child: Text(
                            truncatedDescription,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('| Número de contacto',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Text("🇨🇴"),
                            const Text(" +57 "),
                            Text(formatPhoneNumber(contactNumber)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => _copyPhoneNumber(contactNumber),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Text('| Ubicación',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.location_on),
                            const SizedBox(width: 5),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openMap(ubication),
                                child: Text(
                                  sedeData['address'] ??
                                      'Dirección no disponible',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const Text('| Director',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        directorData == null
                            ? const Text(
                                'No hay información de director disponible')
                            : Card(
                                margin: const EdgeInsets.all(10),
                                elevation: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: directorData[
                                                          'local_image_path'] !=
                                                      null &&
                                                  File(directorData[
                                                          'local_image_path'])
                                                      .existsSync()
                                              ? Image.file(
                                                  File(directorData[
                                                      'local_image_path']),
                                                  width: double.infinity,
                                                  fit: BoxFit.fitWidth,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Image.asset(
                                                    'assets/images/refmmp.png',
                                                    width: double.infinity,
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: directorData[
                                                          'image_presentation'] ??
                                                      '',
                                                  cacheManager:
                                                      CustomCacheManager
                                                          .instance,
                                                  width: double.infinity,
                                                  fit: BoxFit.fitWidth,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.blue),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/refmmp.png',
                                                    width: double.infinity,
                                                    fit: BoxFit.fitWidth,
                                                  ),
                                                ),
                                        );
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            directorData['name'] ??
                                                'Nombre no disponible',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          GestureDetector(
                                            onTap: () => _showDescriptionDialog(
                                                directorData['description'] ??
                                                    'Sin descripción'),
                                            child: Text(
                                              truncateText(
                                                  directorData['description'] ??
                                                      'Sin descripción',
                                                  30),
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          if (directorData['instrument'] !=
                                              null) ...[
                                            const SizedBox(height: 5),
                                            Chip(
                                              avatar: directorData['instrument']
                                                          [
                                                          'local_image_path'] !=
                                                      null
                                                  ? CircleAvatar(
                                                      backgroundImage: File(
                                                                  directorData[
                                                                          'instrument']
                                                                      [
                                                                      'local_image_path'])
                                                              .existsSync()
                                                          ? FileImage(File(
                                                              directorData[
                                                                      'instrument']
                                                                  [
                                                                  'local_image_path']))
                                                          : CachedNetworkImageProvider(
                                                              directorData[
                                                                          'instrument']
                                                                      [
                                                                      'image'] ??
                                                                  '',
                                                              cacheManager:
                                                                  CustomCacheManager
                                                                      .instance,
                                                            ),
                                                      radius: 12,
                                                      backgroundColor:
                                                          Colors.white,
                                                    )
                                                  : null,
                                              label: Text(
                                                directorData['instrument']
                                                        ['name'] ??
                                                    'Instrumento desconocido',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white),
                                              ),
                                              backgroundColor:
                                                  Colors.blue.shade300,
                                              labelPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
