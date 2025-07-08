import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:refmp/connections/register_connections.dart';
import 'package:refmp/details/instrumentsDetails.dart';
import 'package:refmp/edit/edit_headquarters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'dart:async';

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

  const HeadquartersInfo({
    super.key,
    required this.id,
    required this.name,
  });

  @override
  State<HeadquartersInfo> createState() => _HeadquartersInfoState();
}

class _HeadquartersInfoState extends State<HeadquartersInfo> {
  late Future<Map<String, dynamic>> sedeFuture;
  late Future<List<Map<String, dynamic>>> instrumentsFuture;
  late Future<Map<String, dynamic>?> directorFuture;
  late Future<List<Map<String, dynamic>>> teachersFuture;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    sedeFuture = _fetchSedeData();
    instrumentsFuture = _fetchInstruments();
    directorFuture = _fetchDirectorData();
    teachersFuture = _fetchTeachers();

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        setState(() {
          _refreshData();
        });
      }
    });
  }

  void _refreshData() async {
    final box = Hive.box('offline_data');
    final cacheKeys = [
      'sedes_data_${widget.id}',
      'sede_instruments_${widget.id}',
      'director_data_${widget.id}',
      'teachers_headquarters_${widget.id}',
      'sedes_data_${widget.id}_timestamp',
      'sede_instruments_${widget.id}_timestamp',
      'director_data_${widget.id}_timestamp',
      'teachers_headquarters_${widget.id}_timestamp',
    ];

    // Limpiar solo las claves de caché de esta sede
    for (var key in cacheKeys) {
      await box.delete(key);
      debugPrint('Cleared cache for key: $key');
    }

    setState(() {
      sedeFuture = _fetchSedeData();
      instrumentsFuture = _fetchInstruments();
      directorFuture = _fetchDirectorData();
      teachersFuture = _fetchTeachers();
    });
  }

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Hive box offline_data opened successfully');
      debugPrint('Current Hive cache: ${Hive.box('offline_data').toMap()}');
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Conectividad: $connectivityResult');

    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Timeout al verificar conexión a internet');
          return [];
        },
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  Future<String> _downloadAndCacheImage(String url, String cacheKey) async {
    final box = Hive.box('offline_data');
    final cachedData = box.get(cacheKey, defaultValue: null);

    if (cachedData != null &&
        cachedData['url'] == url &&
        await File(cachedData['path']).exists()) {
      debugPrint('Using cached image: ${cachedData['path']}');
      return cachedData['path'];
    }

    try {
      if (cachedData != null && await File(cachedData['path']).exists()) {
        await File(cachedData['path']).delete();
        debugPrint('Deleted old cached image: ${cachedData['path']}');
      }

      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      await box.put(cacheKey, {'path': filePath, 'url': url});
      debugPrint('Image downloaded and cached: $filePath for URL: $url');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> _fetchSedeData() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'sedes_data_${widget.id}';
    final cacheTimestampKey = '${cacheKey}_timestamp';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from("sedes")
            .select(
                'id, name, type_headquarters, description, contact_number, address, ubication, photo')
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
              data['local_photo_path'] = null;
            }
          }
          await box.put(cacheKey, data);
          await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
          debugPrint('Sede data saved to Hive with key: $cacheKey');
          return data;
        }
      } catch (e) {
        debugPrint('Error fetching sede data from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey);
    if (cachedData != null) {
      debugPrint('Loaded sede data from cache: $cachedData');
      return Map<String, dynamic>.from(cachedData);
    }

    return {
      'id': widget.id,
      'name': widget.name,
      'type_headquarters': 'No disponible',
      'description': 'Sin descripción',
      'contact_number': 'No disponible',
      'address': 'Dirección no disponible',
      'ubication': '',
      'photo': ''
    };
  }

  Future<List<Map<String, dynamic>>> _fetchInstruments() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'sede_instruments_${widget.id}';
    final cacheTimestampKey = '${cacheKey}_timestamp';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response =
            await Supabase.instance.client.from('sede_instruments').select('''
            instrument_id,
            instruments!inner (
              id,
              name,
              image
            )
          ''').eq('sede_id', widget.id);

        debugPrint(
            'Raw response from Supabase for instruments (sede_id: ${widget.id}): $response');

        // ignore: unnecessary_null_comparison
        if (response == null || response.isEmpty) {
          debugPrint('No instruments found for sede_id: ${widget.id}');
          await box.put(cacheKey, []);
          await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
          return [];
        }

        final data = List<Map<String, dynamic>>.from(response).map((item) {
          final instrumentData = item['instruments'];
          if (instrumentData == null) {
            debugPrint('Null instrument data in item: $item');
            return {
              'id': 0,
              'name': 'Instrumento desconocido',
              'image': '',
            };
          }
          return {
            'id': instrumentData['id'] ?? 0,
            'name': instrumentData['name'] ?? 'Instrumento desconocido',
            'image': instrumentData['image'] ?? '',
          };
        }).toList();

        for (var instrument in data) {
          final image = instrument['image'] ?? '';
          if (image.isNotEmpty) {
            try {
              final localPath = await _downloadAndCacheImage(
                  image, 'instrument_image_${instrument['id']}');
              instrument['local_image_path'] = localPath;
              debugPrint(
                  'Cached image for instrument ${instrument['id']}: $localPath');
            } catch (e) {
              debugPrint(
                  'Error caching instrument image for ID ${instrument['id']}: $e');
              instrument['local_image_path'] = null;
            }
          }
        }

        await box.put(cacheKey, data);
        await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
        debugPrint(
            'Instruments saved to Hive with key: $cacheKey - Data: $data');
        return data;
      } catch (e, stackTrace) {
        debugPrint('Error fetching instruments from Supabase: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    if (cachedData.isNotEmpty) {
      debugPrint('Loaded instruments from cache: $cachedData');
      return List<Map<String, dynamic>>.from(
          cachedData.map((item) => Map<String, dynamic>.from(item)));
    }

    debugPrint('No valid cache or online data available for instruments');
    return [];
  }

  Future<Map<String, dynamic>?> _fetchDirectorData() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'director_data_${widget.id}';
    final cacheTimestampKey = '${cacheKey}_timestamp';
    final isOnline = await _checkConnectivity();

    // Verificar si los datos en caché son válidos
    final cachedData = box.get(cacheKey);
    final cacheTimestamp = box.get(cacheTimestampKey);
    final isCacheValid = cacheTimestamp != null &&
        DateTime.now().difference(DateTime.parse(cacheTimestamp)).inHours < 1;

    if (isOnline && (!isCacheValid || cachedData == null)) {
      try {
        final response = await Supabase.instance.client
            .from('director_headquarters')
            .select('''
            director_id,
            directors!inner (
              id,
              name,
              descripcion,
              image_presentation
            )
          ''')
            .eq('sede_id', widget.id)
            .maybeSingle();

        debugPrint('Raw response from Supabase for director: $response');

        if (response == null || response['directors'] == null) {
          debugPrint('No director found for sede_id: ${widget.id}');
          await box.put(cacheKey, null);
          await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
          return null;
        }

        final directorData = Map<String, dynamic>.from(response['directors']);
        directorData['description'] = directorData['descripcion'];
        debugPrint('Director data fetched: $directorData');

        final image = directorData['image_presentation'] ?? '';
        if (image.isNotEmpty) {
          try {
            final localPath = await _downloadAndCacheImage(
                image, 'director_image_${directorData['id']}');
            directorData['local_image_path'] = localPath;
          } catch (e) {
            debugPrint('Error caching director image: $e');
            directorData['local_image_path'] = null;
          }
        }

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
              instrumentData['local_image_path'] = null;
            }
          }
          directorData['instrument'] = instrumentData;
          debugPrint('Instrument data fetched for director: $instrumentData');
        } else {
          debugPrint('No instrument found for director_id: $directorId');
        }

        await box.put(cacheKey, directorData);
        await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
        debugPrint('Director data saved to Hive with key: $cacheKey');
        return directorData;
      } catch (e, stackTrace) {
        debugPrint('Error fetching director data from Supabase: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }

    debugPrint('Loaded director data from cache: $cachedData');
    return cachedData != null ? Map<String, dynamic>.from(cachedData) : null;
  }

  Future<List<Map<String, dynamic>>> _fetchTeachers() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'teachers_headquarters_${widget.id}';
    final cacheTimestampKey = '${cacheKey}_timestamp';
    final isOnline = await _checkConnectivity();

    // Verificar si los datos en caché son válidos (menos de 1 hora)
    final cachedData = box.get(cacheKey, defaultValue: []);
    final cacheTimestamp = box.get(cacheTimestampKey);
    final isCacheValid = cacheTimestamp != null &&
        DateTime.now().difference(DateTime.parse(cacheTimestamp)).inHours < 1;

    if (isOnline && (!isCacheValid || cachedData.isEmpty)) {
      try {
        final response = await Supabase.instance.client
            .from('teacher_headquarters')
            .select(
                'teachers(id, first_name, last_name, email, image_presentation, description)')
            .eq('sede_id', widget.id);
        debugPrint(
            'Raw teacher_headquarters response for sede_id ${widget.id}: $response');

        // ignore: unnecessary_null_comparison
        if (response == null || response.isEmpty) {
          debugPrint('No teachers found for sede_id: ${widget.id}');
          await box.put(cacheKey, []);
          await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
          return [];
        }

        final data = List<Map<String, dynamic>>.from(response).map((item) {
          final teacher = item['teachers'];
          if (teacher == null) {
            debugPrint('Null teacher object in item: $item');
            return {
              'id': 0,
              'first_name': 'Desconocido',
              'last_name': '',
              'email': '',
              'image_presentation': '',
              'description': 'Sin datos',
              'instruments': [],
            };
          }
          return {
            'id': teacher['id'] ?? 0,
            'first_name': teacher['first_name'] ?? 'Nombre',
            'last_name': teacher['last_name'] ?? 'No disponible',
            'email': teacher['email'] ?? 'Correo no disponible',
            'image_presentation': teacher['image_presentation'] ?? '',
            'description': teacher['description'] ?? 'Sin descripción',
            'instruments': [],
          };
        }).toList();

        for (var teacher in data) {
          final photo = teacher['image_presentation'] ?? '';
          if (photo.isNotEmpty) {
            try {
              final localPath = await _downloadAndCacheImage(
                  photo, 'teacher_photo_${teacher['id']}');
              teacher['local_photo_path'] = localPath;
              debugPrint(
                  'Teacher image cached at: $localPath for ID: ${teacher['id']}');
            } catch (e) {
              debugPrint(
                  'Error caching teacher photo for ID ${teacher['id']}: $e');
              teacher['local_photo_path'] = null;
            }
          }

          try {
            final instrumentResponse = await Supabase.instance.client
                .from('teacher_instruments')
                .select('instruments(id, name, image)')
                .eq('teacher_id', teacher['id']);
            final instruments =
                List<Map<String, dynamic>>.from(instrumentResponse).map((item) {
              return {
                'id': item['instruments']['id'] ?? 0,
                'name':
                    item['instruments']['name'] ?? 'Instrumento desconocido',
                'image': item['instruments']['image'] ?? '',
              };
            }).toList();

            for (var instrument in instruments) {
              final image = instrument['image'] ?? '';
              if (image.isNotEmpty) {
                try {
                  final localPath = await _downloadAndCacheImage(
                      image, 'teacher_instrument_image_${instrument['id']}');
                  instrument['local_image_path'] = localPath;
                  debugPrint(
                      'Instrument image cached at: $localPath for ID: ${instrument['id']}');
                } catch (e) {
                  debugPrint(
                      'Error caching instrument image for ID ${instrument['id']}: $e');
                  instrument['local_image_path'] = null;
                }
              }
            }
            teacher['instruments'] = instruments;
          } catch (e) {
            debugPrint(
                'Error fetching teacher instruments for ID ${teacher['id']}: $e');
            teacher['instruments'] = [];
          }
        }

        await box.put(cacheKey, data);
        await box.put(cacheTimestampKey, DateTime.now().toIso8601String());
        debugPrint('Teachers saved to Hive with key: $cacheKey - Data: $data');
        return data;
      } catch (e) {
        debugPrint(
            'Error fetching teachers from Supabase for sede_id ${widget.id}: $e');
      }
    }

    debugPrint(
        'Loaded teachers from cache for sede_id ${widget.id}: $cachedData');
    return List<Map<String, dynamic>>.from(
        cachedData.map((item) => Map<String, dynamic>.from(item)));
  }

  Future<bool> _canAddEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final user = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (user != null) return true;
    return false;
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

  void _showDescriptionDialogTeachers({
    required String name,
    required String description,
    required String image,
    required List<Map<String, dynamic>> instruments,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        contentPadding: const EdgeInsets.all(16.0),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: image.isNotEmpty && File(image).existsSync()
                        ? Image.file(
                            File(image),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: image,
                            cacheManager: CustomCacheManager.instance,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child:
                                  CircularProgressIndicator(color: Colors.blue),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '| Descripción',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
                if (instruments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '| Instrumentos',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                      height: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50.0),
                        child: Container(
                          color: Colors.transparent,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: instruments.map((instrument) {
                                final instrumentId = instrument['id'] ?? 0;
                                final instrumentName = instrument['name'] ??
                                    'Instrumento desconocido';
                                final instrumentImage =
                                    instrument['local_image_path'] ??
                                        instrument['image'] ??
                                        '';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: GestureDetector(
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
                                              radius: 10,
                                              backgroundColor: Colors.white,
                                            )
                                          : null,
                                      label: Text(
                                        instrumentName,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.blue.shade300,
                                      labelPadding: const EdgeInsets.symmetric(
                                          horizontal: 6.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ))
                ],
              ],
            ),
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
          _refreshData();
          await Future.wait([
            sedeFuture,
            instrumentsFuture,
            directorFuture,
            teachersFuture,
          ]);
        },
        child: FutureBuilder(
          future: Future.wait([
            sedeFuture,
            instrumentsFuture,
            directorFuture,
            teachersFuture,
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              );
            }

            final sedeData = snapshot.data != null && snapshot.data!.isNotEmpty
                ? snapshot.data![0] as Map<String, dynamic>
                : {
                    'id': widget.id,
                    'name': widget.name,
                    'type_headquarters': 'No disponible',
                    'description': 'Sin descripción',
                    'contact_number': 'No disponible',
                    'address': 'Dirección no disponible',
                    'ubication': '',
                    'photo': ''
                  };
            final instruments =
                snapshot.data != null && snapshot.data!.length > 1
                    ? snapshot.data![1] as List<Map<String, dynamic>>
                    : [];
            final directorData =
                snapshot.data != null && snapshot.data!.length > 2
                    ? snapshot.data![2] as Map<String, dynamic>?
                    : null;
            final teachers = snapshot.data != null && snapshot.data!.length > 3
                ? snapshot.data![3] as List<Map<String, dynamic>>
                : [];

            debugPrint('Teachers in build: $teachers');

            final name = sedeData['name'] ?? widget.name;
            final photo =
                sedeData['local_photo_path'] ?? sedeData['photo'] ?? '';
            final typeHeadquarters =
                sedeData['type_headquarters'] ?? 'No disponible';
            final description = sedeData['description'] ?? 'Sin descripción';
            final truncatedDescription = truncateText(description, 50);
            final contactNumber = sedeData['contact_number'] ?? 'No disponible';
            final ubication = sedeData['ubication'] ?? '';

            return Stack(
              children: [
                CustomScrollView(
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
                                    errorBuilder: (context, error,
                                            stackTrace) =>
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
                            const Text(
                              '| Tipo de sede',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(typeHeadquarters,
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 20),
                            const Text(
                              '| Instrumentos',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50.0),
                              child: Container(
                                color: Colors.transparent,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: instruments.isEmpty
                                        ? [
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8.0),
                                              child: Text(
                                                  'No hay instrumentos disponibles'),
                                            ),
                                          ]
                                        : instruments.map((instrument) {
                                            final instrumentName =
                                                instrument['name'] ??
                                                    'Instrumento desconocido';
                                            final instrumentImage = instrument[
                                                    'local_image_path'] ??
                                                instrument['image'] ??
                                                '';
                                            final instrumentId =
                                                instrument['id'] as int? ?? 0;

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  if (instrumentId != 0) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            InstrumentDetailPage(
                                                          instrumentId:
                                                              instrumentId,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            "ID de instrumento no válido"),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Chip(
                                                  avatar:
                                                      instrumentImage.isNotEmpty
                                                          ? CircleAvatar(
                                                              backgroundImage: File(
                                                                          instrumentImage)
                                                                      .existsSync()
                                                                  ? FileImage(File(
                                                                      instrumentImage))
                                                                  : CachedNetworkImageProvider(
                                                                      instrument[
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
                                                    instrumentName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      Colors.blue.shade300,
                                                  labelPadding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20.0),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              '| Descripción',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            GestureDetector(
                              onTap: () => _showDescriptionDialog(description),
                              child: Text(
                                truncatedDescription,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '| Número de contacto',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Text("🇨🇴"),
                                const Text(" +57 "),
                                Text(formatPhoneNumber(contactNumber)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () =>
                                      _copyPhoneNumber(contactNumber),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              '| Ubicación',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                      style: const TextStyle(
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.blue,
                                      ),
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
                            const Text(
                              '| Director',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            directorData == null
                                ? const Text(
                                    'No hay información de director disponible')
                                : Card(
                                    margin: const EdgeInsets.all(10),
                                    elevation: 5,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                      errorBuilder: (context,
                                                              error,
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
                                                      placeholder:
                                                          (context, url) =>
                                                              const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                                color: Colors
                                                                    .blue),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
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
                                              Center(
                                                child: Text(
                                                  directorData['name'] ??
                                                      'Nombre no disponible',
                                                  style: TextStyle(
                                                    color: themeProvider
                                                            .isDarkMode
                                                        ? Color.fromARGB(
                                                            255, 255, 255, 255)
                                                        : Color.fromARGB(
                                                            255, 33, 150, 243),
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              GestureDetector(
                                                onTap: () =>
                                                    _showDescriptionDialog(
                                                        directorData[
                                                                'description'] ??
                                                            'Sin descripción'),
                                                child: Text(
                                                  truncateText(
                                                      directorData[
                                                              'description'] ??
                                                          'Sin descripción',
                                                      30),
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                'Instrumentos:',
                                                style: TextStyle(
                                                  color: themeProvider
                                                          .isDarkMode
                                                      ? Color.fromARGB(
                                                          255, 255, 255, 255)
                                                      : Color.fromARGB(
                                                          255, 33, 150, 243),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Wrap(
                                                spacing: 8.0,
                                                runSpacing: 8.0,
                                                children:
                                                    directorData[
                                                                'instrument'] !=
                                                            null
                                                        ? [
                                                            GestureDetector(
                                                              onTap: () {
                                                                final instrumentId =
                                                                    directorData['instrument']
                                                                            [
                                                                            'id'] ??
                                                                        0;
                                                                if (instrumentId !=
                                                                    0) {
                                                                  Navigator
                                                                      .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              InstrumentDetailPage(
                                                                        instrumentId:
                                                                            instrumentId,
                                                                      ),
                                                                    ),
                                                                  );
                                                                } else {
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                          "ID de instrumento no válido"),
                                                                    ),
                                                                  );
                                                                }
                                                              },
                                                              child: Chip(
                                                                avatar: (() {
                                                                  final localPath =
                                                                      directorData[
                                                                              'instrument']
                                                                          [
                                                                          'local_image_path'];
                                                                  final networkImage =
                                                                      directorData['instrument']
                                                                              [
                                                                              'image'] ??
                                                                          '';

                                                                  if (localPath !=
                                                                          null &&
                                                                      localPath
                                                                          .toString()
                                                                          .isNotEmpty) {
                                                                    final file =
                                                                        File(
                                                                            localPath);
                                                                    return CircleAvatar(
                                                                      backgroundImage: file
                                                                              .existsSync()
                                                                          ? FileImage(
                                                                              file)
                                                                          : CachedNetworkImageProvider(
                                                                              networkImage,
                                                                              cacheManager: CustomCacheManager.instance,
                                                                            ),
                                                                      radius:
                                                                          12,
                                                                      backgroundColor:
                                                                          Colors
                                                                              .white,
                                                                    );
                                                                  } else if (networkImage
                                                                      .isNotEmpty) {
                                                                    return CircleAvatar(
                                                                      backgroundImage:
                                                                          CachedNetworkImageProvider(
                                                                        networkImage,
                                                                        cacheManager:
                                                                            CustomCacheManager.instance,
                                                                      ),
                                                                      radius:
                                                                          12,
                                                                      backgroundColor:
                                                                          Colors
                                                                              .white,
                                                                    );
                                                                  } else {
                                                                    return null;
                                                                  }
                                                                })(),
                                                                label: Text(
                                                                  directorData[
                                                                              'instrument']
                                                                          [
                                                                          'name'] ??
                                                                      'Instrumento desconocido',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                backgroundColor:
                                                                    Colors.blue
                                                                        .shade300,
                                                                labelPadding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            8.0),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              20.0),
                                                                ),
                                                              ),
                                                            ),
                                                          ]
                                                        : [
                                                            const Text(
                                                                'No hay instrumento asignado'),
                                                          ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 10),
                            Divider(
                              height: 40,
                              thickness: 2,
                              color: themeProvider.isDarkMode
                                  ? const Color.fromARGB(255, 34, 34, 34)
                                  : const Color.fromARGB(255, 236, 234, 234),
                            ),
                            const Text(
                              '| Profesores',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            teachers.isEmpty
                                ? const Text('No hay profesores asociados')
                                : TeacherCarousel(
                                    teachers:
                                        teachers.cast<Map<String, dynamic>>(),
                                    themeProvider: themeProvider,
                                    showDescriptionDialog:
                                        _showDescriptionDialogTeachers,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canAddEvent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          if (snapshot.hasData && snapshot.data == true) {
            return FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () async {
                // Navegar a EditHeadquarters y esperar el resultado
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHeadquarters(
                      id: widget.id,
                      name: widget.name,
                      initialSedeData: {}, // Asegúrate de que esto sea válido según el constructor
                    ),
                  ),
                );

                // Si el resultado es true, refresca los datos
                if (result == true) {
                  _refreshData();
                }
              },
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            );
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}

class TeacherCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final ThemeProvider themeProvider;
  final Function({
    required String name,
    required String description,
    required String image,
    required List<Map<String, dynamic>> instruments,
  }) showDescriptionDialog;

  const TeacherCarousel({
    super.key,
    required this.teachers,
    required this.themeProvider,
    required this.showDescriptionDialog,
  });

  @override
  State<TeacherCarousel> createState() => _TeacherCarouselState();
}

class _TeacherCarouselState extends State<TeacherCarousel> {
  late final PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('Teachers data in carousel: ${widget.teachers}');
    _pageController = PageController(viewportFraction: 0.9);
    if (widget.teachers.isNotEmpty) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (widget.teachers.isNotEmpty) {
        setState(() {
          _currentPage = (_currentPage + 1) % widget.teachers.length;
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        });
      }
    });
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
    if (widget.teachers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(10.0),
        child: Text(
          'No hay profesores asociados',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final cardHeight = min(550.0, MediaQuery.of(context).size.height * 0.7);

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.teachers.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                debugPrint('Current page changed to: $index');
              });
            },
            itemBuilder: (context, index) {
              final data = widget.teachers[index];
              final name =
                  '${data['first_name'] ?? 'Nombre'} ${data['last_name'] ?? 'No disponible'}';
              final image =
                  data['local_photo_path'] ?? data['image_presentation'] ?? '';
              final description = data['description'] ?? 'Sin descripción';
              final instruments = (data['instruments'] as List?)
                      ?.map((item) => Map<String, dynamic>.from(item ?? {}))
                      .toList() ??
                  [];

              debugPrint(
                  'Rendering teacher: $name, Image: $image, Instruments: $instruments');

              return GestureDetector(
                onTap: () {
                  debugPrint('Tapped on teacher: $name');
                  widget.showDescriptionDialog(
                    name: name,
                    description: description,
                    image: image,
                    instruments: instruments,
                  );
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: SizedBox(
                          height: 280,
                          child: image.isNotEmpty && File(image).existsSync()
                              ? Image.file(
                                  File(image),
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.fitWidth,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        'Error loading file image: $error');
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : CachedNetworkImage(
                                  imageUrl: data['image_presentation'] ?? '',
                                  cacheManager: CustomCacheManager.instance,
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.fitWidth,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.blue),
                                  ),
                                  errorWidget: (context, url, error) {
                                    debugPrint(
                                        'Error loading network image: $error');
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      width: double.infinity,
                                      height: 250,
                                      fit: BoxFit.fill,
                                    );
                                  },
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: widget.themeProvider.isDarkMode
                                        ? const Color.fromARGB(
                                            255, 255, 255, 255)
                                        : const Color.fromARGB(
                                            255, 33, 150, 243),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                truncateText(description, 40),
                                style: const TextStyle(fontSize: 12),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '| Instrumentos',
                                style: TextStyle(
                                  color: widget.themeProvider.isDarkMode
                                      ? const Color.fromARGB(255, 255, 255, 255)
                                      : const Color.fromARGB(255, 33, 150, 243),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 40,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50.0),
                                  child: Container(
                                    color: Colors.transparent,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: instruments.isEmpty
                                            ? [
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                                  child: Text(
                                                      'No hay instrumentos asignados'),
                                                )
                                              ]
                                            : instruments.map((instrument) {
                                                final instrumentId =
                                                    instrument['id'] ?? 0;
                                                final instrumentName =
                                                    instrument['name'] ??
                                                        'Instrumento desconocido';
                                                final instrumentImage =
                                                    instrument[
                                                            'local_image_path'] ??
                                                        instrument['image'] ??
                                                        '';

                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4.0),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      if (instrumentId != 0) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                InstrumentDetailPage(
                                                              instrumentId:
                                                                  instrumentId,
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                                "ID de instrumento no válido"),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Chip(
                                                      avatar:
                                                          instrumentImage
                                                                  .isNotEmpty
                                                              ? CircleAvatar(
                                                                  backgroundImage: File(
                                                                              instrumentImage)
                                                                          .existsSync()
                                                                      ? FileImage(
                                                                          File(
                                                                              instrumentImage))
                                                                      : CachedNetworkImageProvider(
                                                                          instrument['image'] ??
                                                                              '',
                                                                          cacheManager:
                                                                              CustomCacheManager.instance,
                                                                        ),
                                                                  radius: 10,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white,
                                                                )
                                                              : null,
                                                      label: Text(
                                                        instrumentName,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.blue.shade300,
                                                      labelPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 6.0),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20.0),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.teachers.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index ? Colors.blue : Colors.grey[400],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
