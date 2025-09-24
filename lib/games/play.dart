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
  final String songId; // ID de la canción
  final String songName; // Nombre de la canción

  const PlayPage({
    super.key,
    required this.songId,
    required this.songName,
  });

  @override
  _PlayPageState createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? song;
  List<dynamic> levels = [];
  bool isLoading = true;
  bool isFavorite = false;

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
      if (!Hive.isBoxOpen('pending_favorite_actions')) {
        await Hive.openBox('pending_favorite_actions');
      }
      debugPrint(
          'Hive boxes offline_data and pending_favorite_actions opened successfully');
      await fetchSongDetails();
      // Sync pending favorite actions if online
      if (await _checkConnectivity()) {
        await _syncPendingFavorites();
      }
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

  // Actualizar la función fetchSongDetails para corregir la consulta:

  Future<void> fetchSongDetails() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'song_${widget.songId}_${widget.songName}';
    final isOnline = await _checkConnectivity();

    debugPrint(
        'Fetching song - ID: ${widget.songId}, Name: ${widget.songName}, Online: $isOnline');

    if (isOnline) {
      try {
        // Determinar si el ID es numérico o UUID
        bool isNumericId = RegExp(r'^\d+$').hasMatch(widget.songId);

        PostgrestFilterBuilder query = supabase
            .from('songs')
            .select(
                'id, name, image, mp3_file, artist, difficulty, instrument, instruments(name, image, id)'); // Removido songs_level

        // Aplicar filtros según el tipo de ID
        if (isNumericId) {
          // ID numérico - buscar por ID como entero y nombre
          query = query
              .eq('id', int.parse(widget.songId))
              .eq('name', widget.songName);
        } else {
          // UUID - buscar por ID como string y nombre
          query = query
              .eq('id', widget.songId)  // No parsear como int
              .eq('name', widget.songName);
        }

        final response = await query.maybeSingle();

        debugPrint('Supabase response: $response');

        if (response != null) {
          await _processSongResponse(response, box, cacheKey);
        } else {
          // Si no se encuentra por ID y nombre exactos, intentar solo por ID
          PostgrestFilterBuilder fallbackQuery = supabase
              .from('songs')
              .select(
                  'id, name, image, mp3_file, artist, difficulty, instrument, instruments(name, image, id)'); // Removido songs_level

          if (isNumericId) {
            fallbackQuery = fallbackQuery.eq('id', int.parse(widget.songId));
          } else {
            fallbackQuery = fallbackQuery.eq('id', widget.songId); // No parsear como int
          }

          final fallbackResponse = await fallbackQuery.maybeSingle();

          if (fallbackResponse != null) {
            debugPrint('Found song by ID only: ${fallbackResponse['name']}');
            await _processSongResponse(fallbackResponse, box, cacheKey);
          } else {
            setState(() {
              song = null;
              levels = [];
              isFavorite = false;
              isLoading = false;
            });
            debugPrint('No song found with ID: ${widget.songId}');
          }
        }
      } catch (e) {
        debugPrint('Error fetching song from Supabase: $e');
        _loadFromCache(box, cacheKey);
      }
    } else {
      _loadFromCache(box, cacheKey);
    }
  }

  // Actualizar también _processSongResponse para manejar la ausencia de levels:
  Future<void> _processSongResponse(Map<String, dynamic> response, Box box, String cacheKey) async {
    // Verificar propiedad de la canción
    final user = supabase.auth.currentUser;
    if (user != null) {
      final userSongResponse = await supabase
          .from('user_songs')
          .select('user_id')
          .eq('user_id', user.id)
          .eq('song_id', response['id'].toString())
          .maybeSingle();

      final hasOwnership = userSongResponse != null;
      response['has_ownership'] = hasOwnership;

      // Si no posee la canción, mostrar mensaje y redirigir
      if (!hasOwnership) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Debes comprar esta canción para acceder a ella completamente.'),
              backgroundColor: Colors.red,
            ),
          );
        });
        return;
      }

      debugPrint('User owns this song: $hasOwnership');
    } else {
      response['has_ownership'] = false;
    }

    if (response['mp3_file'] != null && response['mp3_file'].isNotEmpty) {
      try {
        final localPath = await _downloadAndCacheMp3(
            response['mp3_file'], response['id'].toString());
        response['local_mp3_path'] = localPath;
      } catch (e) {
        debugPrint('Error al descargar MP3: $e');
      }
    }

    // Verificar favoritos
    final favoriteResponse = await supabase
        .from('songs_favorite')
        .select('song_id')
        .eq('user_id', user?.id ?? '')
        .eq('song_id', response['id'])
        .maybeSingle();

    response['is_favorite'] = favoriteResponse != null;

    // Intentar obtener niveles por separado (opcional)
    try {
      final levelsResponse = await supabase
          .from('levels') // Usar el nombre correcto de la tabla
          .select('id, name, image, description')
          .eq('song_id', response['id']); // Ajustar según tu estructura

      response['levels'] = levelsResponse;
      debugPrint('Found ${levelsResponse.length} levels for song');
    } catch (e) {
      debugPrint('No levels found or error fetching levels: $e');
      response['levels'] = [];
    }

    setState(() {
      song = response;
      levels = response['levels'] ?? []; // Usar la nueva estructura
      isFavorite = response['is_favorite'] ?? false;
      isLoading = false;
    });

    await box.put(cacheKey, response);
    debugPrint('Song data saved to Hive with key: $cacheKey');
  }

  // Actualizar _loadFromCache para manejar la nueva estructura:
  void _loadFromCache(Box box, String cacheKey) {
    final cachedSong = box.get(cacheKey);
    debugPrint('Cached song: $cachedSong');
    if (cachedSong != null) {
      setState(() {
        song = Map<String, dynamic>.from(cachedSong);
        levels = cachedSong['levels'] != null
            ? List<Map<String, dynamic>>.from(
                cachedSong['levels'].map((level) => Map<String, dynamic>.from(level))
              )
            : [];
        isFavorite = cachedSong['is_favorite'] ?? false;
        isLoading = false;
      });
      debugPrint('Loaded song from cache: ${song!['name']}');
    } else {
      setState(() {
        song = null;
        levels = [];
        isFavorite = false;
        isLoading = false;
      });
      debugPrint('No cached song found');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, inicia sesión para agregar favoritos.')),
      );
      return;
    }

    if (song == null || song!['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Canción no válida.')),
      );
      return;
    }

    final pendingBox = Hive.box('pending_favorite_actions');
    final isOnline = await _checkConnectivity();

    // Update favorite state immediately
    setState(() {
      isFavorite = !isFavorite;
      song!['is_favorite'] = isFavorite;
    });

    // Update cache with new favorite status

    if (isOnline) {
      try {
        if (isFavorite) {
          await supabase.from('songs_favorite').insert({
            'user_id': user.id,
            'song_id': song!['id'],
          });
          debugPrint('Song added to favorites');
        } else {
          await supabase
              .from('songs_favorite')
              .delete()
              .eq('user_id', user.id)
              .eq('song_id', song!['id']);
          debugPrint('Song removed from favorites');
        }
      } catch (e) {
        debugPrint('Error toggling favorite online: $e');
        // Queue the action if online attempt fails
        await pendingBox.add({
          'user_id': user.id,
          'song_id': song!['id'],
          'action': isFavorite ? 'add' : 'remove',
          'timestamp': DateTime.now().toIso8601String(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Acción guardada para sincronizar cuando estés en línea')),
        );
      }
    } else {
      // Queue the action when offline
      await pendingBox.add({
        'user_id': user.id,
        'song_id': song!['id'],
        'action': isFavorite ? 'add' : 'remove',
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('Favorite action queued offline');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Acción guardada para sincronizar cuando estés en línea')),
      );
    }
  }

  Future<void> _syncPendingFavorites() async {
    final pendingBox = Hive.box('pending_favorite_actions');
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in for syncing favorites');
      return;
    }

    final pendingActions = pendingBox.values.toList();
    if (pendingActions.isEmpty) {
      debugPrint('No pending favorite actions to sync');
      return;
    }

    try {
      for (var action in pendingActions) {
        final userId = action['user_id'];
        final songId = action['song_id'];
        final actionType = action['action'];

        if (userId != user.id) {
          debugPrint('Skipping action for different user: $userId');
          continue;
        }

        try {
          if (actionType == 'add') {
            await supabase.from('songs_favorite').insert({
              'user_id': userId,
              'song_id': songId,
            });
            debugPrint('Synced add favorite for song: $songId');
          } else if (actionType == 'remove') {
            await supabase
                .from('songs_favorite')
                .delete()
                .eq('user_id', userId)
                .eq('song_id', songId);
            debugPrint('Synced remove favorite for song: $songId');
          }
        } catch (e) {
          debugPrint('Error syncing favorite action for song $songId: $e');
          continue; // Continue with next action
        }

        // Remove the processed action
        final index = pendingBox.values.toList().indexOf(action);
        await pendingBox.deleteAt(index);
        debugPrint('Removed synced action from pending_favorite_actions');
      }
    } catch (e) {
      debugPrint('Error processing pending favorite actions: $e');
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
          if (await _checkConnectivity()) {
            await _syncPendingFavorites();
          }
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : song == null
                ? const Center(child: Text("No se encontró la canción."))
                : CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 390.0,
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
                        actions: [
                          IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_outlined,
                              color: isFavorite ? Colors.red : Colors.white,
                              size: 32,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, -2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            onPressed: _toggleFavorite,
                          ),
                        ],
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
                            fit: BoxFit.cover,
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
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
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
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
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
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                spreadRadius: 2,
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
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
                                  ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20.0),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 48,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "¡Próximamente niveles disponibles!",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Los niveles para esta canción estarán disponibles pronto. Por ahora puedes disfrutar escuchándola.",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
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
                                                            error) => Container(
                                                      height: 180,
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons.image_not_supported,
                                                        size: 80,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        level['name'] ??
                                                            "Nivel sin nombre",
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
                                                            "Sin descripción disponible.",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize: 15),
                                                      ),
                                                      const SizedBox(height: 10),
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
