import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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
      // Asegurar que Hive esté inicializado
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
                'id, name, image, mp3_file, artist, difficulty, instruments(name), songs_level(level(id, name, image, description))')
            .eq('name', widget.songName)
            .maybeSingle();

        debugPrint('Supabase response: $response');

        if (response != null) {
          // Descargar y almacenar el MP3 si hay una URL válida
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

          // Guardar en Hive
          try {
            await box.put(cacheKey, response);
            debugPrint('Song data saved to Hive with key: $cacheKey');
          } catch (e) {
            debugPrint('Error saving to Hive: $e');
          }
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
        // Intentar cargar desde caché
        _loadFromCache(box, cacheKey);
      }
    } else {
      // Cargar desde caché si no hay conexión
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
    switch (difficulty.toLowerCase()) {
      case 'fácil':
        return Colors.green;
      case 'medio':
        return const Color.fromARGB(255, 230, 214, 70);
      case 'difícil':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          "Detalles de la canción",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          setState(() {
            isLoading = true;
          });
          await fetchSongDetails();
        },
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                color: Colors.blue,
              ))
            : song == null
                ? const Center(child: Text("No se encontró la canción."))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: song!['image'] ?? '',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(
                                          color: Colors.blue),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.music_note, size: 100),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                          "Dificultad: ${song!["difficulty"]}",
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: getDifficultyColor(
                                                  song!["difficulty"]))),
                                    ),
                                    Center(
                                      child: Text(
                                        song!['name'],
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text("Artista: ${song!['artist']}",
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 5),
                                    Text(
                                      "Instrumento: ${song!['instruments']?['name'] ?? "Desconocido"}",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: Icon(
                                              isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white),
                                          label: Text(
                                            isPlaying ? "Pausar" : "Reproducir",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                          onPressed: () async {
                                            final localPath =
                                                song!['local_mp3_path'];
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
                                                    await File(localPath)
                                                        .exists()) {
                                                  await _audioPlayer.play(
                                                      DeviceFileSource(
                                                          localPath));
                                                  debugPrint(
                                                      'Playing from local: $localPath');
                                                } else if (url != null &&
                                                    url.isNotEmpty) {
                                                  await _audioPlayer
                                                      .play(UrlSource(url));
                                                  debugPrint(
                                                      'Playing from URL: $url');
                                                } else {
                                                  throw Exception(
                                                      'No audio source available');
                                                }

                                                _timer?.cancel();
                                                _timer = Timer(
                                                    const Duration(seconds: 30),
                                                    () async {
                                                  await _audioPlayer.pause();
                                                  setState(() {
                                                    isPlaying = false;
                                                  });
                                                  debugPrint(
                                                      'Audio paused after 30 seconds');
                                                });
                                              } catch (e) {
                                                debugPrint(
                                                    'Error playing audio: $e');
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
                                          }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                      child: Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(16)),
                                            child: CachedNetworkImage(
                                              imageUrl: level['image'] ?? '',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: 180,
                                              placeholder: (context, url) =>
                                                  const CircularProgressIndicator(
                                                      color: Colors.blue),
                                              errorWidget: (context, url,
                                                      error) =>
                                                  const Icon(
                                                      Icons.image_not_supported,
                                                      size: 80),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              children: [
                                                Text(
                                                  level['name'] ??
                                                      "Nombre desconocido",
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  level['description'] ??
                                                      "Sin descripción.",
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                ),
                                                const SizedBox(height: 10),
                                                ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 20,
                                                        vertical: 12),
                                                  ),
                                                  onPressed: () {
                                                    // Implementar lógica para el juego aquí
                                                    debugPrint(
                                                        'Navigating to game for level: ${level['name']}');
                                                  },
                                                  icon: const Icon(
                                                      Icons
                                                          .sports_esports_rounded,
                                                      color: Colors.white),
                                                  label: const Text(
                                                    "Aprende y Juega",
                                                    style: TextStyle(
                                                        color: Colors.white),
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
    );
  }
}
