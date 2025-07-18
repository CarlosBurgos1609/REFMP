import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/details/headquartersInfo.dart';
import 'dart:math'; // Importado para usar min

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

class InstrumentDetailPage extends StatefulWidget {
  final int instrumentId;
  const InstrumentDetailPage({super.key, required this.instrumentId});

  @override
  State<InstrumentDetailPage> createState() => _InstrumentDetailPageState();
}

class _InstrumentDetailPageState extends State<InstrumentDetailPage> {
  late Future<Map<String, dynamic>> instrumentFuture;
  late Future<List<Map<String, dynamic>>> headquartersFuture;
  late Future<List<Map<String, dynamic>>> teachersFuture;
  final SupabaseClient supabase = Supabase.instance.client;

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

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Hive box offline_data opened successfully');
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
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

  Future<Map<String, dynamic>> _fetchInstrumentData() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'instrument_${widget.instrumentId}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase
            .from('instruments')
            .select('id, name, description, image')
            .eq('id', widget.instrumentId)
            .order('name', ascending: true)
            .single();
        final data = Map<String, dynamic>.from(response);
        final image = data['image'] ?? '';
        if (image.isNotEmpty) {
          try {
            final localPath =
                await _downloadAndCacheImage(image, 'image_$cacheKey');
            data['local_image_path'] = localPath;
          } catch (e) {
            debugPrint('Error caching instrument image: $e');
          }
        }
        await box.put(cacheKey, data);
        debugPrint('Instrument data saved to Hive with key: $cacheKey');
        return data;
      } catch (e) {
        debugPrint('Error fetching instrument data from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: {'name': 'Cargando...'});
    debugPrint('Loaded instrument data from cache: $cachedData');
    return Map<String, dynamic>.from(cachedData);
  }

  Future<List<Map<String, dynamic>>> _fetchHeadquarters() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'headquarters_instrument_${widget.instrumentId}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase
            .from('sede_instruments')
            .select('sedes(id, name, address, photo)')
            .eq('instrument_id', widget.instrumentId);
        final data = List<Map<String, dynamic>>.from(response).map((item) {
          return {
            'id': item['sedes']['id'] ?? 0,
            'name': item['sedes']['name'] ?? 'Sede desconocida',
            'address': item['sedes']['address'] ?? 'Dirección no disponible',
            'photo': item['sedes']['photo'] ?? '',
          };
        }).toList();

        for (var hq in data) {
          final photo = hq['photo'] ?? '';
          if (photo.isNotEmpty) {
            try {
              final localPath =
                  await _downloadAndCacheImage(photo, 'hq_photo_${hq['id']}');
              hq['local_photo_path'] = localPath;
            } catch (e) {
              debugPrint('Error caching headquarters photo: $e');
            }
          }
        }
        await box.put(cacheKey, data);
        debugPrint('Headquarters saved to Hive with key: $cacheKey');
        return data;
      } catch (e) {
        debugPrint('Error fetching headquarters from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    debugPrint('Loaded headquarters from cache: $cachedData');
    return List<Map<String, dynamic>>.from(
        cachedData.map((item) => Map<String, dynamic>.from(item)));
  }

  Future<List<Map<String, dynamic>>> _fetchTeachers() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'teachers_instrument_${widget.instrumentId}';
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase
            .from('teacher_instruments')
            .select(
                'teachers(id, first_name, last_name, email, image_presentation, description)')
            .eq('instrument_id', widget.instrumentId);
        final data = List<Map<String, dynamic>>.from(response).map((item) {
          final teacher = item['teachers'];
          return {
            'id': teacher['id'] ?? 0,
            'first_name': teacher['first_name'] ?? 'Nombre',
            'last_name': teacher['last_name'] ?? 'No disponible',
            'email': teacher['email'] ?? 'Correo no disponible',
            'image_presentation': teacher['image_presentation'] ?? '',
            'description': teacher['description'] ?? 'Sin descripción',
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
              teacher['local_photo_path'] =
                  null; // Ensure it's set to null on error
            }
          }

          try {
            final instrumentResponse = await supabase
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
                  instrument['local_image_path'] =
                      null; // Ensure it's set to null on error
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
        debugPrint('Teachers saved to Hive with key: $cacheKey - Data: $data');
        return data;
      } catch (e) {
        debugPrint('Error fetching teachers from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    debugPrint('Loaded teachers from cache: $cachedData');
    return List<Map<String, dynamic>>.from(
        cachedData.map((item) => Map<String, dynamic>.from(item)));
  }

  void _showDescriptionDialog({
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
        contentPadding: const EdgeInsets.all(16.0), // Padding uniforme
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                0.6, // Máximo 60% de la altura de la pantalla
            maxWidth:
                MediaQuery.of(context).size.width * 0.8, // Máximo 80% del ancho
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen del profesor
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 300, // Altura fija para la imagen
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
                // Nombre del profesor
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 18, // Reducido de 20 a 18
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                // Descripción completa
                const Text(
                  '| Descripción',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 14, // Reducido de 16 a 14
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12), // Reducido de 14 a 12
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
                    height: 40, // Altura fija para los chips
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: instruments.map((instrument) {
                          final instrumentId = instrument['id'] ?? 0;
                          final instrumentName =
                              instrument['name'] ?? 'Instrumento desconocido';
                          final instrumentImage =
                              instrument['local_image_path'] ??
                                  instrument['image'] ??
                                  '';

                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("ID de instrumento no válido"),
                                    ),
                                  );
                                }
                              },
                              child: Chip(
                                avatar: instrumentImage.isNotEmpty
                                    ? CircleAvatar(
                                        backgroundImage: File(instrumentImage)
                                                .existsSync()
                                            ? FileImage(File(instrumentImage))
                                            : CachedNetworkImageProvider(
                                                instrument['image'] ?? '',
                                                cacheManager:
                                                    CustomCacheManager.instance,
                                              ),
                                        radius: 10, // Reducido de 12 a 10
                                        backgroundColor: Colors.white,
                                      )
                                    : null,
                                label: Text(
                                  instrumentName,
                                  style: const TextStyle(
                                    fontSize: 10, // Reducido de 12 a 10
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.blue.shade300,
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 6.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
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

  void _showDescriptionDialogInstrument({
    required String name,
    required String description,
    required String image,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        contentPadding: const EdgeInsets.all(16.0), // Padding uniforme
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
                // Imagen del instrumento
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 200, // Altura fija para la imagen
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
                // Nombre del instrumento
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
                // Descripción completa
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

  void _refreshData() {
    instrumentFuture = _fetchInstrumentData();
    headquartersFuture = _fetchHeadquarters();
    teachersFuture = _fetchTeachers();
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
          await Future.wait(
              [instrumentFuture, headquartersFuture, teachersFuture]);
        },
        child: FutureBuilder(
          future: Future.wait(
              [instrumentFuture, headquartersFuture, teachersFuture]),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              );
            }

            final instrumentData =
                snapshot.data != null && snapshot.data!.isNotEmpty
                    ? snapshot.data![0] as Map<String, dynamic>
                    : {'name': 'Cargando...'};
            final headquarters =
                snapshot.data != null && snapshot.data!.length > 1
                    ? snapshot.data![1] as List<Map<String, dynamic>>
                    : [];
            final teachers = snapshot.data != null && snapshot.data!.length > 2
                ? snapshot.data![2] as List<Map<String, dynamic>>
                : [];

            final name = instrumentData['name'] ?? 'Cargando...';
            final image = instrumentData['local_image_path'] ??
                instrumentData['image'] ??
                '';
            final description =
                instrumentData['description'] ?? 'Sin descripción';
            final truncatedDescription = truncateText(description, 50);

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 400.0,
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
                    background: image.isNotEmpty
                        ? (File(image).existsSync()
                            ? Image.file(
                                File(image),
                                fit: BoxFit.fitWidth,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset('assets/images/refmmp.png',
                                        fit: BoxFit.fitWidth),
                              )
                            : CachedNetworkImage(
                                imageUrl: instrumentData['image'] ?? '',
                                cacheManager: CustomCacheManager.instance,
                                fit: BoxFit.fitWidth,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                                errorWidget: (context, url, error) =>
                                    Image.asset('assets/images/refmmp.png',
                                        fit: BoxFit.fitWidth),
                              ))
                        : Image.asset('assets/images/refmmp.png',
                            fit: BoxFit.fitWidth),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('| Descripción',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _showDescriptionDialogInstrument(
                            name: name,
                            description: description,
                            image: image,
                          ),
                          child: Text(
                            truncatedDescription,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const SizedBox(height: 3),
                        const Text('| Sedes',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: headquarters.isEmpty
                                ? [
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('No hay sedes asociadas'),
                                    )
                                  ]
                                : headquarters.map((hq) {
                                    final hqName =
                                        hq['name'] ?? 'Sede desconocida';
                                    final hqImage = hq['local_photo_path'] ??
                                        hq['photo'] ??
                                        '';
                                    final hqId = hq['id'] as int? ?? 0;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          if (hqId != 0) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    HeadquartersInfo(
                                                  id: hqId.toString(),
                                                  name: hqName,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    "ID de sede no válido"),
                                              ),
                                            );
                                          }
                                        },
                                        child: Chip(
                                          avatar: hqImage.isNotEmpty
                                              ? CircleAvatar(
                                                  backgroundImage: File(hqImage)
                                                          .existsSync()
                                                      ? FileImage(File(hqImage))
                                                      : CachedNetworkImageProvider(
                                                          hq['photo'] ?? '',
                                                          cacheManager:
                                                              CustomCacheManager
                                                                  .instance,
                                                        ),
                                                  radius: 12,
                                                  backgroundColor: Colors.white,
                                                )
                                              : null,
                                          label: Text(
                                            hqName,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white),
                                          ),
                                          backgroundColor: Colors.blue.shade300,
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8.0),
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
                        const SizedBox(height: 5),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const SizedBox(height: 3),
                        const Text('| Profesores',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        teachers.isEmpty
                            ? const Text('No hay profesores asociados')
                            : TeacherCarousel(
                                teachers: teachers.cast<Map<String, dynamic>>(),
                                themeProvider: themeProvider,
                                showDescriptionDialog: _showDescriptionDialog,
                              )
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
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
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
    final cardHeight = min(550.0,
        MediaQuery.of(context).size.height * 0.7); // Reducido de 610 a 550

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

              return GestureDetector(
                onTap: () => widget.showDescriptionDialog(
                  name: name,
                  description: description,
                  image: image,
                  instruments: instruments,
                ),
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
                      // Imagen del profesor (reducida a 250 píxeles)
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/refmmp.png',
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                  ),
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
                                  errorWidget: (context, url, error) =>
                                      Image.asset(
                                    'assets/images/refmmp.png',
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                        ),
                      ),
                      // Contenido (reducido a 300 píxeles)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre
                              Center(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: widget.themeProvider.isDarkMode
                                        ? const Color.fromARGB(
                                            255, 255, 255, 255)
                                        : const Color.fromARGB(
                                            255, 33, 150, 243),
                                    fontSize: 16, // Reducido de 18 a 16
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 3), // Reducido de 5 a 3
                              // Descripción truncada
                              Text(
                                truncateText(description,
                                    40), // Reducido de 30 a 20 palabras
                                style: const TextStyle(
                                    fontSize: 12), // Reducido de 14 a 12
                                maxLines: 5, // Reducido de 3 a 2
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3), // Reducido de 5 a 3
                              // Título de instrumentos
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
                              const SizedBox(height: 2), // Reducido de 3 a 2
                              // Instrumentos
                              SizedBox(
                                height: 40, // Altura fija para los chips
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
                                            final instrumentImage = instrument[
                                                    'local_image_path'] ??
                                                instrument['image'] ??
                                                '';

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
                                                              radius:
                                                                  10, // Reducido de 12 a 10
                                                              backgroundColor:
                                                                  Colors.white,
                                                            )
                                                          : null,
                                                  label: Text(
                                                    instrumentName,
                                                    style: const TextStyle(
                                                        fontSize:
                                                            10, // Reducido de 12 a 10
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      Colors.blue.shade300,
                                                  labelPadding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal:
                                                          6.0), // Reducido de 8 a 6
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
