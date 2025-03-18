import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class TrumpetPage extends StatefulWidget {
  const TrumpetPage({super.key});

  @override
  State<TrumpetPage> createState() => _TrumpetPageState();
}

class _TrumpetPageState extends State<TrumpetPage> {
  final supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  String? currentSong;

  Future<List<Map<String, dynamic>>> fetchSongs() async {
    final response = await supabase
        .from('songs')
        .select('id, name, image, mp3_file, artist');

    if (response.isNotEmpty) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
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
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        isPlaying = true;
        currentSong = url;
      });
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
      appBar: AppBar(title: const Text("Canciones de Trompeta")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchSongs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay canciones disponibles."));
          }

          final songs = snapshot.data!;
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: ClipRRect(
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
                  title: Text(song['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(song['artist']),
                  trailing: IconButton(
                    icon: Icon(
                      (isPlaying && currentSong == song['mp3_file'])
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      size: 32,
                      color: Colors.blueAccent,
                    ),
                    onPressed: () => playSong(song['mp3_file']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
