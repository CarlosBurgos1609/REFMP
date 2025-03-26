import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrumpetPage extends StatefulWidget {
  final String songName;

  const TrumpetPage({super.key, required this.songName});

  @override
  _TrumpetPageState createState() => _TrumpetPageState();
}

class _TrumpetPageState extends State<TrumpetPage> {
  final supabase = Supabase.instance.client;
  final AudioPlayer audioPlayer = AudioPlayer();
  Map<String, dynamic>? song;
  bool isLoading = true;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
    ]);
    fetchSongDetails();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> fetchSongDetails() async {
    final response = await supabase
        .from('songs')
        .select(
            'id, name, image, artist, difficulty, mp3_file, instruments(name)')
        .eq('name', widget.songName)
        .maybeSingle();

    if (response != null) {
      setState(() {
        song = response;
        isLoading = false;
        if (song!['mp3_file'] != null) {
          audioPlayer.setSourceUrl(song!['mp3_file']);
          audioPlayer.play(UrlSource(song!['mp3_file']));
          isPlaying = true;
        }
      });
    } else {
      setState(() {
        song = null;
        isLoading = false;
      });
    }
  }

  void showPauseMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pausa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                audioPlayer.resume();
                setState(() => isPlaying = true);
              },
              child: const Text("Reanudar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Salir"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/pasto.png',
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : song == null
                  ? const Center(child: Text("No se encontró la canción."))
                  : Column(
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            song!['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            song!['artist'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(20),
                              ),
                              onPressed: showPauseMenu,
                              child:
                                  const Icon(Icons.pause, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset(
                                'assets/images/refmmp.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const Spacer(),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                song!['image'],
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.music_note, size: 50),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: Colors.black12,
                            child: const Center(
                              child: Text(
                                "Aquí bajará la tonada en forma de partitura",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTrumpetButton(Colors.yellow),
                            const SizedBox(width: 50),
                            _buildTrumpetButton(Colors.blue),
                            const SizedBox(width: 50),
                            _buildTrumpetButton(Colors.red),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/trumpet.png',
                          width: 200,
                          height: 100,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildTrumpetButton(Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        padding: const EdgeInsets.all(30),
      ),
      onPressed: () {},
      child: const SizedBox.shrink(),
    );
  }
}
