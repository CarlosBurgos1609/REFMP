import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    fetchSongDetails();
  }

  Future<void> fetchSongDetails() async {
    final response = await supabase
        .from('songs')
        .select(
            'id, name, image, mp3_file, artist, difficulty, instruments(name), songs_level(level(id, name, image, description))')
        .eq('name', widget.songName)
        .maybeSingle();

    if (response != null) {
      setState(() {
        song = response;
        levels =
            response['songs_level'].map((entry) => entry['levels']).toList();
        isLoading = false;
      });
    } else {
      setState(() {
        song = null;
        levels = [];
        isLoading = false;
      });
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                              child: Image.network(
                                song!['image'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
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
                      const SizedBox(height: 10),
                      levels.isEmpty
                          ? const Text("No hay niveles disponibles.")
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
                                          child: Image.network(
                                            level['image'] ?? '',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 180,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
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
                                                    fontWeight: FontWeight.bold,
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
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  shape: RoundedRectangleBorder(
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
                                                  // Aquí puedes manejar la navegación o la lógica del botón
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
    );
  }
}
