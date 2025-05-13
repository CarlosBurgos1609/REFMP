import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/games/play.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

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

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // evitar recargar la misma página

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MusicPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 2:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => TournamentPage(instrumentName: widget.instrumentName),
        //   ),
        // );
        break;
      case 3:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => RewardsPage(instrumentName: widget.instrumentName),
        //   ),
        // );
        break;
      case 4:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _songsFuture = fetchSongs();
    fetchUserProfileImage();
  }

  Future<List<Map<String, dynamic>>> fetchSongs() async {
    final instrumentResponse = await supabase
        .from('instruments')
        .select('id')
        .eq('name', widget.instrumentName)
        .maybeSingle();

    if (instrumentResponse == null) {
      return [];
    }

    int instrumentId = instrumentResponse['id'];

    final response = await supabase
        .from('songs')
        .select('id, name, image, mp3_file, artist, difficulty, instrument')
        .eq('instrument', instrumentId)
        .order('name', ascending: true);

    return response.isNotEmpty ? List<Map<String, dynamic>>.from(response) : [];
  }

  Future<void> _refreshSongs() async {
    final newSongs = await fetchSongs();
    setState(() {
      _songsFuture = Future.value(newSongs);
    });
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint('Conectividad: $connectivityResult');
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        final box = Hive.box('offline_data');
        const cacheKey = 'user_profile_image';
        final cachedProfileImage = box.get(cacheKey, defaultValue: null);
        if (cachedProfileImage != null) {
          setState(() {
            profileImageUrl = cachedProfileImage;
          });
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

          final box = Hive.box('offline_data');
          await box.put('user_profile_image', response['profile_image']);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  void playSong(String url) async {
    if (isPlaying && currentSong == url) {
      await _audioPlayer.pause();
      setState(() {
        isPlaying = false;
        currentSong = null;
      });
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url), position: Duration.zero);
      await _audioPlayer.setPlaybackRate(1.0);
      _audioPlayer.setReleaseMode(ReleaseMode.stop);
      setState(() {
        isPlaying = true;
        currentSong = url;
      });
      Future.delayed(const Duration(seconds: 20), () {
        if (isPlaying && currentSong == url) {
          _audioPlayer.stop();
          setState(() {
            isPlaying = false;
            currentSong = null;
          });
        }
      });
    }
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
            return const SizedBox(); // o un indicador de carga pequeño
          }

          if (snapshot.hasData && snapshot.data == true) {
            return FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //       builder: (context) => RegisterGraduateForm()),
                // );
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          } else {
            return const SizedBox(); // no mostrar nada si no tiene permiso
          }
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
                          child: Image.network(
                            song['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.music_note, size: 60),
                          ),
                        ),
                        Icon(
                          (isPlaying && currentSong == song['mp3_file'])
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
                                      child: Image.network(
                                        song['image'],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
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
                                            song['name'],
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            "Artista: ${song['artist']}",
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
                                                  song['difficulty']),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              song['difficulty'],
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
                      child: Text(song['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song['artist']),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getDifficultyColor(song['difficulty']),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            song['difficulty'],
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
                                PlayPage(songName: song["name"]),
                          ),
                        );
                      },
                      icon: const Icon(Icons.music_note, color: Colors.white),
                      label: const Text("Tocar",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                    onTap: () => playSong(song['mp3_file']),
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
        profileImageUrl:
            profileImageUrl, // Ya no será 'student' sino la URL real
      ),
    );
  }
}
