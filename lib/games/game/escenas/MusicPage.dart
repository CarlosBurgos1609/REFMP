import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/forms/songsForm.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/games/play.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MusicPage extends StatefulWidget {
  final String instrumentName;

  const MusicPage({super.key, required this.instrumentName});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  String? currentSong;
  String searchQuery = "";
  String? profileImageUrl;

  Future<List<Map<String, dynamic>>>? _songsFuture;

  int _selectedIndex = 1; // 0: Aprende, 1: Canciones, 2: Torneo, 3: Recompensas

  @override
  void initState() {
    super.initState();
    _initializeHiveAndFetch();
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
        currentSong = null;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initializeHiveAndFetch() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }
      debugPrint('Hive box offline_data opened successfully');
      setState(() {
        _songsFuture = fetchSongs();
      });
      await fetchUserProfileImage();
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
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

  Future<List<Map<String, dynamic>>> fetchSongs() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'songs_${widget.instrumentName}';
    final isOnline = await _checkConnectivity();

    debugPrint(
        'Fetching songs for instrument: ${widget.instrumentName}, Online: $isOnline');

    if (isOnline) {
      try {
        final instrumentResponse = await supabase
            .from('instruments')
            .select('id')
            .eq('name', widget.instrumentName)
            .maybeSingle();

        if (instrumentResponse == null) {
          debugPrint('No instrument found for: ${widget.instrumentName}');
          return [];
        }

        int instrumentId = instrumentResponse['id'];

        final response = await supabase
            .from('songs')
            .select('id, name, image, mp3_file, artist, difficulty, instrument')
            .eq('instrument', instrumentId)
            .order('name', ascending: true);

        debugPrint('Supabase songs response: ${response.length} songs');

        if (response.isNotEmpty) {
          List<Map<String, dynamic>> songs =
              List<Map<String, dynamic>>.from(response);
          // Descargar y almacenar MP3 para cada canción
          for (var song in songs) {
            if (song['mp3_file'] != null && song['mp3_file'].isNotEmpty) {
              try {
                final localPath = await _downloadAndCacheMp3(
                    song['mp3_file'], song['id'].toString());
                song['local_mp3_path'] = localPath;
              } catch (e) {
                debugPrint(
                    'Error downloading MP3 for song ${song['name']}: $e');
              }
            }
          }

          // Guardar en Hive
          try {
            await box.put(cacheKey, songs);
            debugPrint('Songs saved to Hive with key: $cacheKey');
          } catch (e) {
            debugPrint('Error saving songs to Hive: $e');
          }

          return songs;
        } else {
          debugPrint('No songs found for instrument ID: $instrumentId');
          return [];
        }
      } catch (e) {
        debugPrint('Error fetching songs from Supabase: $e');
        // Intentar cargar desde caché
        return _loadSongsFromCache(box, cacheKey);
      }
    } else {
      // Cargar desde caché si no hay conexión
      return _loadSongsFromCache(box, cacheKey);
    }
  }

  Future<List<Map<String, dynamic>>> _loadSongsFromCache(
      Box box, String cacheKey) async {
    final cachedSongs = box.get(cacheKey);
    debugPrint('Cached songs: $cachedSongs');
    if (cachedSongs != null) {
      return List<Map<String, dynamic>>.from(
          cachedSongs.map((song) => Map<String, dynamic>.from(song)));
    } else {
      debugPrint('No cached songs found for key: $cacheKey');
      return [];
    }
  }

  Future<void> _refreshSongs() async {
    setState(() {
      _songsFuture = fetchSongs();
    });
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return;
      }

      final box = Hive.box('offline_data');
      final isOnline = await _checkConnectivity();
      const cacheKey = 'user_profile_image';

      if (!isOnline) {
        final cachedProfileImage = box.get(cacheKey);
        if (cachedProfileImage != null) {
          setState(() {
            profileImageUrl = cachedProfileImage;
          });
          debugPrint('Loaded profile image from cache: $cachedProfileImage');
        }
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents'
      ];

      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && response['profile_image'] != null) {
          setState(() {
            profileImageUrl = response['profile_image'];
          });
          await box.put(cacheKey, response['profile_image']);
          debugPrint(
              'Profile image saved to cache: ${response['profile_image']}');
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  void playSong(Map<String, dynamic> song) async {
    final localPath = song['local_mp3_path'];
    final url = song['mp3_file'];

    if (localPath == null && (url == null || url.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay archivo de audio disponible.")),
      );
      return;
    }

    try {
      if (isPlaying && currentSong == (localPath ?? url)) {
        await _audioPlayer.pause();
        setState(() {
          isPlaying = false;
          currentSong = null;
        });
        debugPrint('Paused song: ${song['name']}');
      } else {
        await _audioPlayer.stop();
        if (localPath != null && await File(localPath).exists()) {
          await _audioPlayer.play(DeviceFileSource(localPath));
          debugPrint('Playing from local: $localPath');
        } else if (url != null && url.isNotEmpty) {
          await _audioPlayer.play(UrlSource(url));
          debugPrint('Playing from URL: $url');
        } else {
          throw Exception('No audio source available');
        }
        await _audioPlayer.setPlaybackRate(1.0);
        _audioPlayer.setReleaseMode(ReleaseMode.stop);
        setState(() {
          isPlaying = true;
          currentSong = localPath ?? url;
        });
        // Pausar después de 20 segundos
        Future.delayed(const Duration(seconds: 20), () {
          if (isPlaying && currentSong == (localPath ?? url)) {
            _audioPlayer.stop();
            setState(() {
              isPlaying = false;
              currentSong = null;
            });
            debugPrint('Song ${song['name']} stopped after 20 seconds');
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing song ${song['name']}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al reproducir la canción: $e")),
      );
    }
  }

  Future<bool> _canAddEvent() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user logged in for _canAddEvent');
      return false;
    }

    final box = Hive.box('offline_data');
    final isOnline = await _checkConnectivity();
    final cacheKey = 'can_add_event_$userId';

    if (isOnline) {
      try {
        final user = await supabase
            .from('users')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (user != null) {
          await box.put(cacheKey, true);
          debugPrint('User has permission to add events, cached: true');
          return true;
        } else {
          await box.put(cacheKey, false);
          debugPrint('User does not have permission, cached: false');
          return false;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return box.get(cacheKey, defaultValue: false);
      }
    } else {
      final cachedPermission = box.get(cacheKey, defaultValue: false);
      debugPrint('Loaded permission from cache: $cachedPermission');
      return cachedPermission;
    }
  }

  Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'fácil':
        return Colors.green;
      case 'medio':
        return Colors.yellow;
      case 'difícil':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LearningPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 1:
        // No hacer nada, ya estamos en MusicPage
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CupPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ObjetsPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfilePageGame(instrumentName: widget.instrumentName),
          ),
        );
        break;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: SizedBox(
          width: double.infinity,
          child: TextField(
            decoration: InputDecoration(
              hintText: "Buscar Canciones de ${widget.instrumentName} ...",
              hintStyle: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              border: InputBorder.none,
              suffixIcon: const Icon(
                Icons.search,
                color: Colors.white,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() {
                searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SongsFormPage()),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox();
        },
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay canciones disponibles"));
          }

          final songs = snapshot.data!
              .where((song) => song['name'].toLowerCase().contains(searchQuery))
              .toList();

          return RefreshIndicator(
            color: Colors.blue,
            onRefresh: _refreshSongs,
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: song['image'] ?? '',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(
                                    color: Colors.blue),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.music_note, size: 60),
                          ),
                        ),
                        Icon(
                          (isPlaying &&
                                  currentSong ==
                                      (song['local_mp3_path'] ??
                                          song['mp3_file']))
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    title: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) {
                            return SingleChildScrollView(
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: song['image'] ?? '',
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(
                                                color: Colors.blue),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.music_note,
                                                size: 100),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(13.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song['name'] ?? 'Sin nombre',
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            "Artista: ${song['artist'] ?? 'Sin artista'}",
                                            style:
                                                const TextStyle(fontSize: 20),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: getDifficultyColor(
                                                  song['difficulty'] ??
                                                      'Desconocida'),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              song['difficulty'] ??
                                                  'Desconocida',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Text(
                        song['name'] ?? 'Sin nombre',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song['artist'] ?? 'Sin artista'),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getDifficultyColor(
                                song['difficulty'] ?? 'Desconocida'),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            song['difficulty'] ?? 'Desconocida',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PlayPage(songName: song['name']),
                          ),
                        );
                      },
                      icon: const Icon(Icons.music_note, color: Colors.white),
                      label: const Text(
                        'Tocar',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    onTap: () => playSong(song),
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
