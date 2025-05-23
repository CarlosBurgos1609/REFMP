import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/game/escenas/subnivels.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LearningPage extends StatefulWidget {
  final String instrumentName;

  const LearningPage({super.key, required this.instrumentName});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  final supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _levelsFuture;
  String searchQuery = "";
  String? profileImageUrl;
  int _selectedIndex = 0;

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MusicPage(instrumentName: widget.instrumentName),
          ),
        );
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
  }

  @override
  void initState() {
    super.initState();
    _levelsFuture = fetchLevels();
    fetchUserProfileImage();
  }

  Future<List<Map<String, dynamic>>> fetchLevels() async {
    // Primero obtenemos el id del instrumento
    final instrumentResponse = await supabase
        .from('instruments') // Traemos los instrumentos
        .select('id')
        .eq('name',
            widget.instrumentName) // Buscamos el instrumento por su nombre
        .maybeSingle(); // Si el instrumento no se encuentra, devolvemos null

    if (instrumentResponse == null)
      return []; // Si no encontramos el instrumento

    final instrumentId = instrumentResponse['id'];

    // Obtener los niveles asociados a este instrumento
    final levelsResponse = await supabase
        .from('levels') // Ahora consultamos en la tabla levels
        .select('id, name, description, image')
        .eq('instrument_id',
            instrumentId) // Filtramos por el id del instrumento
        .order('number', ascending: true); // orden ascendente

    return levelsResponse;
  }

  Future<void> _refreshLevels() async {
    final newLevels = await fetchLevels();
    setState(() {
      _levelsFuture = Future.value(newLevels);
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
              hintText: "Buscar Niveles de ${widget.instrumentName}...",
              hintStyle: const TextStyle(color: Colors.white, fontSize: 14),
              border: InputBorder.none,
              suffixIcon: const Icon(Icons.search, color: Colors.white),
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
                //   MaterialPageRoute(builder: (context) => SongsFormPage()),
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
        future: _levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay niveles disponibles"));
          }

          final levels = snapshot.data!
              .where((level) =>
                  level['name'].toLowerCase().contains(searchQuery) ||
                  level['description'].toLowerCase().contains(searchQuery))
              .toList();

          return RefreshIndicator(
            onRefresh: _refreshLevels,
            color: Colors.blue,
            child: ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: level['image'] != null &&
                              level['image'].toString().isNotEmpty
                          ? Image.network(
                              level['image'],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.school, size: 60),
                            )
                          : const Icon(Icons.school, size: 60),
                    ),
                    title: Text(
                      level['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    subtitle: Text(level['description']),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubnivelesPage(
                            levelId: level['id'], // UUID del nivel
                            levelTitle:
                                level['name'], // Opcional: título para AppBar
                          ),
                        ),
                      );
                    },
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
