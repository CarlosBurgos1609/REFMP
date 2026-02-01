import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isOnline = true;
  bool _isLoadingFromCache = false;

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
    _loadFromCacheFirst(); // Cargar caché primero (instantáneo)
    _checkNewUserAndInitialize(); // Verificar usuario nuevo y luego inicializar
    fetchUserProfileImage();
  }

  // Verificar si es usuario nuevo y mostrar diálogo de nickname
  Future<void> _checkNewUserAndInitialize() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final box = Hive.box('offline_data');
    final isRegisteredKey = 'user_registered_in_games_${user.id}';

    // Verificar en caché si ya está registrado
    final isAlreadyRegistered = box.get(isRegisteredKey, defaultValue: false);

    if (isAlreadyRegistered) {
      // Ya está registrado, continuar normalmente
      _initializeUserLevel();
      return;
    }

    // Verificar conexión
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      _initializeUserLevel();
      return;
    }

    try {
      // Verificar si existe en users_games
      final existingUser = await supabase
          .from('users_games')
          .select('nickname')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingUser != null) {
        // Ya existe, guardar en caché y continuar
        await box.put(isRegisteredKey, true);
        _initializeUserLevel();
      } else {
        // Usuario nuevo, mostrar diálogo de nickname
        if (mounted) {
          _showNewUserNicknameDialog();
        }
      }
    } catch (e) {
      debugPrint('Error verificando usuario en users_games: $e');
      _initializeUserLevel();
    }
  }

  // Diálogo para que el usuario nuevo ingrese su nickname
  void _showNewUserNicknameDialog() {
    final TextEditingController nicknameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.blue,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  const Text(
                    '¡Bienvenido!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    'Elige un nombre para tu perfil de jugador',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Campo de texto
                  TextField(
                    controller: nicknameController,
                    maxLength: 14,
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Tu nickname (máx. 14 caracteres)',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      counterText: '',
                      prefixIcon: const Icon(Icons.edit, color: Colors.blue),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón de confirmar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final nickname = nicknameController.text.trim();
                        if (nickname.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Por favor ingresa un nickname'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        if (nickname.length > 14) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'El nickname debe tener máximo 14 caracteres'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        await _registerNewUser(nickname);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Comenzar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Registrar usuario nuevo en users_games
  Future<void> _registerNewUser(String nickname) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final box = Hive.box('offline_data');
    final isRegisteredKey = 'user_registered_in_games_${user.id}';

    try {
      // Verificar si el nickname ya existe
      final existingNickname = await supabase
          .from('users_games')
          .select('nickname')
          .eq('nickname', nickname)
          .maybeSingle();

      if (existingNickname != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este nickname ya está en uso. Elige otro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Volver a mostrar el diálogo
        _showNewUserNicknameDialog();
        return;
      }

      // Insertar nuevo usuario
      await supabase.from('users_games').insert({
        'user_id': user.id,
        'nickname': nickname,
        'points_xp_totally': 0,
        'points_xp_weekend': 0,
        'coins': 0,
      });

      // Guardar en caché que ya está registrado
      await box.put(isRegisteredKey, true);
      await box.put('user_nickname_${user.id}', nickname);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido $nickname! Tu perfil ha sido creado.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Continuar con la inicialización
      _initializeUserLevel();
    } catch (e) {
      debugPrint('Error al registrar usuario: $e');

      if (e.toString().contains('23505')) {
        // Error de duplicado
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este nickname ya está en uso. Elige otro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _showNewUserNicknameDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear perfil: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Cargar desde caché inmediatamente para mostrar datos al instante
  void _loadFromCacheFirst() {
    final cachedLevels = _loadLevelsFromCache();
    if (cachedLevels.isNotEmpty) {
      _levelsFuture = Future.value(cachedLevels);
    }
  }

  Future<void> _initializeUserLevel() async {
    final isOnline = await _checkConnectivity();
    if (!isOnline) return; // Si no hay internet, ya mostramos caché

    await _checkAndCreateUserLevel();

    // Actualizar con datos frescos del servidor
    final freshLevels = await fetchLevels();
    if (mounted && freshLevels.isNotEmpty) {
      setState(() {
        _levelsFuture = Future.value(freshLevels);
        _isLoadingFromCache = false;
      });
    }
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

      // Obtener el nivel actual del usuario y calcular progreso en paralelo
      await Future.wait([
        _getCurrentUserLevel(),
        _calculateLevelProgress(),
      ]);
    } catch (e) {
      debugPrint('Error al verificar/crear nivel del usuario: $e');
    }
  }

  // Cache del instrument ID para evitar consultas repetidas
  dynamic _cachedInstrumentId;

  Future<dynamic> _getInstrumentId() async {
    if (_cachedInstrumentId != null) return _cachedInstrumentId;

    final response = await supabase
        .from('instruments')
        .select('id')
        .eq('name', widget.instrumentName)
        .maybeSingle();

    _cachedInstrumentId = response?['id'];
    return _cachedInstrumentId;
  }

  // Obtener el nivel actual del usuario
  Future<void> _getCurrentUserLevel() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final instrumentId = await _getInstrumentId();
      if (instrumentId == null) return;

      // Obtener todos los niveles del usuario para este instrumento
      final userLevels = await supabase
          .from('users_levels')
          .select('level_id, levels!inner(number, instrument_id)')
          .eq('user_id', user.id)
          .eq('levels.instrument_id', instrumentId);

      if (userLevels.isNotEmpty) {
        // Encontrar el nivel más alto manualmente
        int maxLevel = 1;
        for (var ul in userLevels) {
          final levelNumber = ul['levels']['number'] as int;
          if (levelNumber > maxLevel) {
            maxLevel = levelNumber;
          }
        }

        if (mounted) {
          setState(() {
            currentUserLevel = maxLevel;
          });
        }
        debugPrint('Nivel actual del usuario: $currentUserLevel');
      }
    } catch (e) {
      debugPrint('Error al obtener nivel actual: $e');
    }
  }

  // Calcular el progreso de cada nivel - OPTIMIZADO
  Future<void> _calculateLevelProgress() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final instrumentId = await _getInstrumentId();
      if (instrumentId == null) return;

      // Obtener niveles con sus subniveles en una sola consulta
      final levels = await supabase
          .from('levels')
          .select('id, number, sublevels(id)')
          .eq('instrument_id', instrumentId)
          .order('number', ascending: true);

      // Obtener todos los subniveles completados del usuario en una sola consulta
      final completedSublevels = await supabase
          .from('users_sublevels')
          .select('sublevel_id, level_id')
          .eq('user_id', user.id)
          .eq('completed', true);

      // Crear un set de sublevel_ids completados para búsqueda rápida
      final completedSet = <String>{};
      for (var cs in completedSublevels) {
        completedSet.add(cs['sublevel_id']);
      }

      Map<String, double> progress = {};

      for (var level in levels) {
        final levelId = level['id'];
        final sublevels = level['sublevels'] as List;
        final totalCount = sublevels.length;

        if (totalCount > 0) {
          // Contar cuántos subniveles de este nivel están completados
          int completedCount = 0;
          for (var sublevel in sublevels) {
            if (completedSet.contains(sublevel['id'])) {
              completedCount++;
            }
          }

          progress[levelId] = completedCount / totalCount;

          // Si completó todos los subniveles, marcar el nivel como completado
          if (completedCount == totalCount && completedCount > 0) {
            _markLevelAsCompleted(levelId); // Sin await para no bloquear
          }
        } else {
          progress[levelId] = 0.0;
        }
      }

      if (mounted) {
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

          if (mounted) {
            setState(() {
              currentUserLevel = currentLevel['number'] + 1;
            });
          }
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

  // Clave para guardar niveles en caché
  String get _levelsCacheKey => 'levels_${widget.instrumentName}';
  String get _userLevelCacheKey => 'user_level_${widget.instrumentName}';
  String get _levelProgressCacheKey =>
      'level_progress_${widget.instrumentName}';

  Future<List<Map<String, dynamic>>> fetchLevels() async {
    final box = Hive.box('offline_data');
    final isOnline = await _checkConnectivity();

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }

    // Si no hay internet, cargar desde caché
    if (!isOnline) {
      return _loadLevelsFromCache();
    }

    try {
      final instrumentId = await _getInstrumentId();
      if (instrumentId == null) {
        return _loadLevelsFromCache();
      }

      // Obtener los niveles asociados a este instrumento
      final levelsResponse = await supabase
          .from('levels')
          .select('id, name, description, image, number')
          .eq('instrument_id', instrumentId)
          .order('number', ascending: true);

      // Guardar en caché en background (sin await)
      box.put(_levelsCacheKey, jsonEncode(levelsResponse));
      box.put(_userLevelCacheKey, currentUserLevel);
      box.put(_levelProgressCacheKey,
          jsonEncode(levelProgress.map((key, value) => MapEntry(key, value))));

      return levelsResponse;
    } catch (e) {
      debugPrint('Error al obtener niveles: $e');
      // Si hay error, intentar cargar desde caché
      return _loadLevelsFromCache();
    }
  }

  // Cargar niveles desde caché
  List<Map<String, dynamic>> _loadLevelsFromCache() {
    final box = Hive.box('offline_data');
    final cachedData = box.get(_levelsCacheKey);

    // Cargar nivel y progreso del caché
    final cachedUserLevel = box.get(_userLevelCacheKey);
    final cachedProgress = box.get(_levelProgressCacheKey);

    if (cachedUserLevel != null) {
      currentUserLevel = cachedUserLevel;
    }

    if (cachedProgress != null) {
      try {
        final Map<String, dynamic> progressMap = jsonDecode(cachedProgress);
        levelProgress = progressMap
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
      } catch (e) {
        debugPrint('Error al cargar progreso del caché: $e');
      }
    }

    if (cachedData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            _isLoadingFromCache = true;
          });
        }
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Error al decodificar caché: $e');
      }
    }

    return [];
  }

  Future<void> _refreshLevels() async {
    await _checkAndCreateUserLevel();
    await _getCurrentUserLevel();
    await _calculateLevelProgress();
    final newLevels = await fetchLevels();
    if (mounted) {
      setState(() {
        _levelsFuture = Future.value(newLevels);
      });
    }
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
          if (mounted) {
            setState(() {
              profileImageUrl = cachedProfileImage;
            });
          }
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
          if (mounted) {
            setState(() {
              profileImageUrl = response['profile_image'];
            });
          }

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
              // Mostrar mensaje diferente si no hay conexión
              if (!_isOnline) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Sin conexión a internet",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "No hay niveles guardados en caché.\nConéctate a internet para cargar los niveles.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _refreshLevels,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reintentar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }
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
              child: Column(
                children: [
                  // Banner de modo offline
                  if (!_isOnline || _isLoadingFromCache)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      color: Colors.orange.shade100,
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Modo sin conexión - Mostrando datos guardados",
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: levels.length,
                      itemBuilder: (context, index) {
                        final level = levels[index];
                        final levelNumber = level['number'] ?? (index + 1);
                        final canAccess = _canAccessLevel(levelNumber);
                        final progress = levelProgress[level['id']] ?? 0.0;
                        final isCompleted = progress >= 1.0;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
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
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            color: Colors.grey[200],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: level['image'] != null &&
                                                    level['image']
                                                        .toString()
                                                        .isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: level['image'],
                                                    width: 60,
                                                    height: 60,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (context, url) =>
                                                            Container(
                                                      width: 60,
                                                      height: 60,
                                                      color: Colors.grey[300],
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                      width: 60,
                                                      height: 60,
                                                      color:
                                                          Colors.blue.shade100,
                                                      child: const Icon(
                                                        Icons.school,
                                                        size: 30,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 60,
                                                    height: 60,
                                                    color: Colors.blue.shade100,
                                                    child: const Icon(
                                                      Icons.school,
                                                      size: 30,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                          ),
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
                                                    color: Colors.white,
                                                    width: 2),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          level['description'],
                                          style: TextStyle(
                                            color: canAccess
                                                ? Colors.grey
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Barra de progreso
                                        if (canAccess) ...[
                                          LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.grey[300],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
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
                                                : levelNumber ==
                                                        currentUserLevel
                                                    ? 'Nivel actual'
                                                    : 'Completado',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isCompleted
                                                  ? Colors.green
                                                  : levelNumber ==
                                                          currentUserLevel
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
                                              borderRadius:
                                                  BorderRadius.circular(3),
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
                                                builder: (context) =>
                                                    SubnivelesPage(
                                                  levelId: level[
                                                      'id'], // UUID del nivel
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
                                                duration:
                                                    const Duration(seconds: 2),
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
                  ),
                ],
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
