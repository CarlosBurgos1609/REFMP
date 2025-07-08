import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:refmp/details/instrumentsDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

Timer? _timer;

class PlayPage extends StatefulWidget {
  final String songName;

  const PlayPage({super.key, required this.songName});

  @override
  _PlayPageState createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? song;
  List<dynamic> levels = [];
  bool isLoading = true;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeHiveAndFetch();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        _timer?.cancel();
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeHiveAndFetch() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }
      debugPrint('Hive box offline_data opened successfully');
      await fetchSongDetails();
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      setState(() {
        isLoading = false;
      });
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

  Future<String> _downloadAndCacheMp3(String url, String songId) async {
    final box = Hive.box('offline_data');
    final cacheKey = 'mp3_$songId';
    final cachedPath = box.get(cacheKey);

    if (cachedPath != null && await File(cachedPath).exists()) {
      debugPrint('Usando MP3 en caché: $cachedPath');
      return cachedPath;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/$songId.mp3';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        await box.put(cacheKey, filePath);
        debugPrint('MP3 descargado y almacenado en: $filePath');
        return filePath;
      } else {
        throw Exception('Error al descargar MP3: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading MP3: $e');
      rethrow;
    }
  }

  Future<void> fetchSongDetails() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'song_${widget.songName}';
    final isOnline = await _checkConnectivity();

    debugPrint('Fetching song: ${widget.songName}, Online: $isOnline');

    if (isOnline) {
      try {
        final response = await supabase
            .from('songs')
            .select(
                'id, name, image, mp3_file, artist, difficulty, instruments(name, image, id), songs_level(level(id, name, image, description))')
            .eq('name', widget.songName)
            .maybeSingle();

        debugPrint('Supabase response: $response');

        if (response != null) {
          if (response['mp3_file'] != null && response['mp3_file'].isNotEmpty) {
            try {
              final localPath = await _downloadAndCacheMp3(
                  response['mp3_file'], response['id'].toString());
              response['local_mp3_path'] = localPath;
            } catch (e) {
              debugPrint('Error al descargar MP3: $e');
            }
          }

          setState(() {
            song = response;
            levels = response['songs_level'] != null
                ? response['songs_level']
                    .map((entry) => entry['level'])
                    .where((level) => level != null)
                    .toList()
                : [];
            isLoading = false;
          });

          await box.put(cacheKey, response);
          debugPrint('Song data saved to Hive with key: $cacheKey');
        } else {
          setState(() {
            song = null;
            levels = [];
            isLoading = false;
          });
          debugPrint('No song found in Supabase');
        }
      } catch (e) {
        debugPrint('Error fetching song from Supabase: $e');
        _loadFromCache(box, cacheKey);
      }
    } else {
      _loadFromCache(box, cacheKey);
    }
  }

  void _loadFromCache(Box box, String cacheKey) {
    final cachedSong = box.get(cacheKey);
    debugPrint('Cached song: $cachedSong');
    if (cachedSong != null) {
      setState(() {
        song = Map<String, dynamic>.from(cachedSong);
        levels = cachedSong['songs_level'] != null
            ? cachedSong['songs_level']
                .map((entry) => Map<String, dynamic>.from(entry['level']))
                .where((level) => level != null)
                .toList()
            : [];
        isLoading = false;
      });
      debugPrint('Loaded song from cache: ${song!['name']}');
    } else {
      setState(() {
        song = null;
        levels = [];
        isLoading = false;
      });
      debugPrint('No cached song found');
    }
  }

  Color getDifficultyColor(String difficulty) {
    final normalizedDifficulty = difficulty.trim().toLowerCase();
    debugPrint('Normalized difficulty: $normalizedDifficulty');
    switch (normalizedDifficulty) {
      case 'fácil':
      case 'facil':
      case 'Fácil':
        return Colors.green.withOpacity(0.9);
      case 'medio':
      case 'Media':
        return const Color.fromARGB(255, 230, 214, 70);
      case 'difícil':
      case 'dificil':
      case 'Difícil':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          setState(() {
            isLoading = true;
          });
          await fetchSongDetails();
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : song == null
                ? const Center(child: Text("No se encontró la canción."))
                : CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 320.0,
                        floating: false,
                        pinned: true,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(2, 1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        backgroundColor: Colors.blue,
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            song!['name'] ?? 'Cargando...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          centerTitle: true,
                          titlePadding: const EdgeInsets.only(bottom: 16.0),
                          background: CachedNetworkImage(
                            imageUrl: song!['image'] ?? '',
                            cacheManager: CustomCacheManager.instance,
                            fit: BoxFit.fitWidth,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover),
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
                                '| Detalles',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  // color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.6),
                                      width: 2.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '| Artista',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12.0),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.7),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                                0.2), // Color de la sombra con opacidad
                                            spreadRadius:
                                                2, // Dispersión de la sombra
                                            blurRadius:
                                                4, // Desenfoque de la sombra
                                            offset: const Offset(0,
                                                2), // Desplazamiento (x, y) de la sombra
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        song!['artist'] ?? 'Desconocido',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '| Dificultad',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: getDifficultyColor(
                                            song!['difficulty'] ??
                                                'Desconocida'),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                                0.2), // Color de la sombra con opacidad
                                            spreadRadius:
                                                2, // Dispersión de la sombra
                                            blurRadius:
                                                4, // Desenfoque de la sombra
                                            offset: const Offset(0,
                                                2), // Desplazamiento (x, y) de la sombra
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        song!['difficulty'] ?? 'Desconocida',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),

                                    const SizedBox(height: 10),
                                    const Text(
                                      '| Instrumento',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Contenedor para Instrumento (centrado)
                                    SizedBox(
                                      width: double.infinity,
                                      child: GestureDetector(
                                        onTap: () {
                                          final instrumentId =
                                              song!['instruments']?['id'] ?? 0;
                                          if (instrumentId != 0) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    InstrumentDetailPage(
                                                        instrumentId:
                                                            instrumentId),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "ID de instrumento no válido")),
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0, vertical: 8.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade300,
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                    0.2), // Color de la sombra con opacidad
                                                spreadRadius:
                                                    2, // Dispersión de la sombra
                                                blurRadius:
                                                    4, // Desenfoque de la sombra
                                                offset: const Offset(0,
                                                    2), // Desplazamiento (x, y) de la sombra
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (song!['instruments']?['image']
                                                      ?.isNotEmpty ??
                                                  false)
                                                CircleAvatar(
                                                  backgroundImage:
                                                      CachedNetworkImageProvider(
                                                    song!['instruments']
                                                            ['image'] ??
                                                        '',
                                                    cacheManager:
                                                        CustomCacheManager
                                                            .instance,
                                                  ),
                                                  radius: 14,
                                                  backgroundColor: Colors.white,
                                                ),
                                              const SizedBox(width: 8),
                                              Text(
                                                song!['instruments']?['name'] ??
                                                    'Desconocido',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Botón de Reproducir (más grande y consistente)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  label: Text(
                                    isPlaying ? "Pausar" : "Reproducir",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  onPressed: () async {
                                    final localPath = song!['local_mp3_path'];
                                    final url = song!['mp3_file'];

                                    if (localPath == null &&
                                        (url == null || url.isEmpty)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "No hay archivo de audio disponible.")),
                                      );
                                      return;
                                    }

                                    if (isPlaying) {
                                      await _audioPlayer.pause();
                                      _timer?.cancel();
                                    } else {
                                      try {
                                        if (localPath != null &&
                                            await File(localPath).exists()) {
                                          await _audioPlayer.play(
                                              DeviceFileSource(localPath));
                                          debugPrint(
                                              'Playing from local: $localPath');
                                        } else if (url != null &&
                                            url.isNotEmpty) {
                                          await _audioPlayer
                                              .play(UrlSource(url));
                                          debugPrint('Playing from URL: $url');
                                        } else {
                                          throw Exception(
                                              'No audio source available');
                                        }

                                        _timer?.cancel();
                                        _timer =
                                            Timer(const Duration(seconds: 30),
                                                () async {
                                          await _audioPlayer.pause();
                                          setState(() {
                                            isPlaying = false;
                                          });
                                          debugPrint(
                                              'Audio paused after 30 seconds');
                                        });
                                      } catch (e) {
                                        debugPrint('Error playing audio: $e');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  "Error al reproducir el audio: $e")),
                                        );
                                        return;
                                      }
                                    }

                                    setState(() {
                                      isPlaying = !isPlaying;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.blue, thickness: 2),
                              const SizedBox(height: 10),
                              const Center(
                                child: Text(
                                  "Niveles disponibles:",
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 20),
                              levels.isEmpty
                                  ? const Center(
                                      child: Text(
                                          "No se encontraron niveles disponibles."))
                                  : Column(
                                      children: levels.map((level) {
                                        return Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 4,
                                            child: Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                        level['image'] ?? '',
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 180,
                                                    placeholder: (context,
                                                            url) =>
                                                        const CircularProgressIndicator(
                                                            color: Colors.blue),
                                                    errorWidget: (context, url,
                                                            error) =>
                                                        const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 80),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        level['name'] ??
                                                            "Nombre desconocido",
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.blue,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        level['description'] ??
                                                            "Sin descripción.",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize: 15),
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      ElevatedButton.icon(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.blue,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      20,
                                                                  vertical: 12),
                                                        ),
                                                        onPressed: () {
                                                          debugPrint(
                                                              'Navigating to game for level: ${level['name']}');
                                                        },
                                                        icon: const Icon(
                                                            Icons
                                                                .sports_esports_rounded,
                                                            color:
                                                                Colors.white),
                                                        label: const Text(
                                                          "Aprende y Juega",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

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
