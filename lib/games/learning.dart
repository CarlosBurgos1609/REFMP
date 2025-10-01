import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/game/escenas/subnivels.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/routes/menu.dart';
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
  int currentUserLevel = 1;
  Map<String, double> levelProgress = {};

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
    _initializeUserLevel();
    fetchUserProfileImage();
  }

  Future<void> _initializeUserLevel() async {
    await _checkAndCreateUserLevel();
    _levelsFuture = fetchLevels();
  }

  // Verificar y crear el nivel del usuario si no existe
  Future<void> _checkAndCreateUserLevel() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Verificar si el usuario ya tiene un nivel registrado
      final existingLevel = await supabase
          .from('users_levels')
          .select('level_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLevel == null) {
        // Obtener el primer nivel del instrumento
        final instrumentResponse = await supabase
            .from('instruments')
            .select('id')
            .eq('name', widget.instrumentName)
            .maybeSingle();

        if (instrumentResponse != null) {
          final firstLevel = await supabase
              .from('levels')
              .select('id')
              .eq('instrument_id', instrumentResponse['id'])
              .order('number', ascending: true)
              .limit(1)
              .maybeSingle();

          if (firstLevel != null) {
            // Crear el registro del usuario en el nivel 1
            await supabase.from('users_levels').insert({
              'user_id': user.id,
              'level_id': firstLevel['id'],
              'completed': false,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            debugPrint('Usuario registrado en nivel 1');
          }
        }
      }

      // Obtener el nivel actual del usuario
      await _getCurrentUserLevel();
      await _calculateLevelProgress();
    } catch (e) {
      debugPrint('Error al verificar/crear nivel del usuario: $e');
    }
  }

  // Obtener el nivel actual del usuario
  Future<void> _getCurrentUserLevel() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final instrumentResponse = await supabase
          .from('instruments')
          .select('id')
          .eq('name', widget.instrumentName)
          .maybeSingle();

      if (instrumentResponse != null) {
        final userLevels = await supabase
            .from('users_levels')
            .select('level_id, levels!inner(number)')
            .eq('user_id', user.id)
            .eq('levels.instrument_id', instrumentResponse['id'])
            .order('levels.number', ascending: false)
            .limit(1)
            .maybeSingle();

        if (userLevels != null) {
          setState(() {
            currentUserLevel = userLevels['levels']['number'];
          });
          debugPrint('Nivel actual del usuario: $currentUserLevel');
        }
      }
    } catch (e) {
      debugPrint('Error al obtener nivel actual: $e');
    }
  }

  // Calcular el progreso de cada nivel
  Future<void> _calculateLevelProgress() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final instrumentResponse = await supabase
          .from('instruments')
          .select('id')
          .eq('name', widget.instrumentName)
          .maybeSingle();

      if (instrumentResponse != null) {
        final levels = await supabase
            .from('levels')
            .select('id, number')
            .eq('instrument_id', instrumentResponse['id'])
            .order('number', ascending: true);

        Map<String, double> progress = {};

        for (var level in levels) {
          final levelId = level['id'];

          // Obtener total de subniveles para este nivel
          final totalSublevels = await supabase
              .from('sublevels')
              .select('id')
              .eq('level_id', levelId)
              .count();

          if (totalSublevels.count > 0) {
            // Obtener subniveles completados por el usuario
            final completedSublevels = await supabase
                .from('users_sublevels')
                .select('sublevel_id')
                .eq('user_id', user.id)
                .eq('completed', true)
                .count();

            progress[levelId] = completedSublevels.count / totalSublevels.count;

            // Si completó todos los subniveles, marcar el nivel como completado
            if (completedSublevels.count == totalSublevels.count) {
              await _markLevelAsCompleted(levelId);
            }
          } else {
            progress[levelId] = 0.0;
          }
        }

        setState(() {
          levelProgress = progress;
        });
      }
    } catch (e) {
      debugPrint('Error al calcular progreso: $e');
    }
  }

  // Marcar nivel como completado y desbloquear el siguiente
  Future<void> _markLevelAsCompleted(String levelId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Marcar nivel actual como completado
      await supabase
          .from('users_levels')
          .update({
            'completed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('level_id', levelId);

      // Obtener el siguiente nivel
      final currentLevel = await supabase
          .from('levels')
          .select('number, instrument_id')
          .eq('id', levelId)
          .maybeSingle();

      if (currentLevel != null) {
        final nextLevel = await supabase
            .from('levels')
            .select('id')
            .eq('instrument_id', currentLevel['instrument_id'])
            .eq('number', currentLevel['number'] + 1)
            .maybeSingle();

        if (nextLevel != null) {
          // Verificar si ya existe el registro del siguiente nivel
          final existingNextLevel = await supabase
              .from('users_levels')
              .select('level_id')
              .eq('user_id', user.id)
              .eq('level_id', nextLevel['id'])
              .maybeSingle();

          if (existingNextLevel == null) {
            // Crear el registro del siguiente nivel
            await supabase.from('users_levels').insert({
              'user_id': user.id,
              'level_id': nextLevel['id'],
              'completed': false,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          }

          setState(() {
            currentUserLevel = currentLevel['number'] + 1;
          });
          debugPrint('Nivel ${currentLevel['number'] + 1} desbloqueado');
        }
      }
    } catch (e) {
      debugPrint('Error al marcar nivel completado: $e');
    }
  }

  // Verificar si el usuario puede acceder a un nivel
  bool _canAccessLevel(int levelNumber) {
    return levelNumber <= currentUserLevel;
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
        .select('id, name, description, image, number')
        .eq('instrument_id',
            instrumentId) // Filtramos por el id del instrumento
        .order('number', ascending: true); // orden ascendente

    return levelsResponse;
  }

  Future<void> _refreshLevels() async {
    await _checkAndCreateUserLevel();
    await _getCurrentUserLevel();
    await _calculateLevelProgress();
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
    return WillPopScope(
      onWillPop: () async {
        Menu.currentIndexNotifier.value = 0;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              title: 'Inicio',
            ),
          ),
        );
        return false;
      },
      child: Scaffold(
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
            onPressed: () {
              Menu.currentIndexNotifier.value = 0;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    title: 'Inicio',
                  ),
                ),
              );
            },
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
                  final levelNumber = level['number'] ?? (index + 1);
                  final canAccess = _canAccessLevel(levelNumber);
                  final progress = levelProgress[level['id']] ?? 0.0;
                  final isCompleted = progress >= 1.0;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Stack(
                      children: [
                        // Overlay para niveles bloqueados
                        if (!canAccess)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.lock,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Contenido principal
                        Column(
                          children: [
                            ListTile(
                              leading: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: level['image'] != null &&
                                            level['image'].toString().isNotEmpty
                                        ? Image.network(
                                            level['image'],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(Icons.school,
                                                        size: 60),
                                          )
                                        : const Icon(Icons.school, size: 60),
                                  ),
                                  // Indicador de completado
                                  if (isCompleted)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Nivel $levelNumber: ${level['name']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: canAccess
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  if (canAccess)
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCompleted
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    level['description'],
                                    style: TextStyle(
                                      color: canAccess
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Barra de progreso
                                  if (canAccess) ...[
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isCompleted
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                      minHeight: 6,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isCompleted
                                          ? '¡Nivel completado!'
                                          : levelNumber == currentUserLevel
                                              ? 'Nivel actual'
                                              : 'Completado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCompleted
                                            ? Colors.green
                                            : levelNumber == currentUserLevel
                                                ? Colors.blue
                                                : Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Completa el nivel anterior para desbloquear',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: canAccess
                                  ? Icon(Icons.arrow_forward_ios,
                                      color: Colors.blue)
                                  : Icon(Icons.lock_outline,
                                      color: Colors.grey),
                              onTap: canAccess
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SubnivelesPage(
                                            levelId:
                                                level['id'], // UUID del nivel
                                            levelTitle: level[
                                                'name'], // Opcional: título para AppBar
                                          ),
                                        ),
                                      ).then((_) {
                                        // Refrescar progreso cuando regrese de subniveles
                                        _calculateLevelProgress();
                                      });
                                    }
                                  : () {
                                      // Mostrar mensaje de nivel bloqueado
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Debes completar el nivel ${levelNumber - 1} primero'),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ],
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
        ),
      ),
    );
  }
}
