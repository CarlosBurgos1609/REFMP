import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // NUEVO: Para cache robusto
import 'package:hive_flutter/hive_flutter.dart'; // NUEVO: Para cache offline
import 'package:connectivity_plus/connectivity_plus.dart'; // NUEVO: Para verificar conectividad
import 'package:supabase_flutter/supabase_flutter.dart'; // Para guardar XP y monedas
import '../game/dialogs/back_dialog.dart';
import '../game/dialogs/pause_dialog.dart';
import '../../models/song_note.dart';
import '../../models/chromatic_note.dart'; // NUEVA importación
import '../../services/note_audio_service.dart'; // NUEVO: Servicio de audio
import '../../services/continuous_audio_controller.dart'; // NUEVO: Controlador de audio continuo
import '../../services/database_service.dart';
import '../game/dialogs/congratulations_dialog.dart';

// NUEVO: Sistema de cache robusto como objects.dart
class AudioCacheManager {
  static const key = 'audioCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // Cache de audio por 7 días
      maxNrOfCacheObjects: 500, // Más objetos para audio
      fileService: HttpFileService(),
    ),
  );
}

// Clase para representar una nota que cae
class FallingNote {
  final int piston; // 1, 2, o 3 (para retrocompatibilidad)
  final SongNote? songNote; // Nota musical de la base de datos (nueva)
  final ChromaticNote? chromaticNote; // NUEVA: datos de chromatic_scale
  double y; // Posición Y actual
  final double startTime; // Tiempo cuando empezó a caer
  bool isHit; // Si ya fue golpeada
  bool isMissed; // Si se perdió la nota

  FallingNote({
    required this.piston,
    this.songNote,
    this.chromaticNote, // NUEVA: opcional
    required this.y,
    required this.startTime,
    this.isHit = false,
    this.isMissed = false,
  });

  // Obtener los pistones requeridos para esta nota
  List<int> get requiredPistons {
    if (chromaticNote != null) {
      return chromaticNote!.requiredPistons;
    }
    return songNote?.pistonCombination ?? [piston];
  }

  // Obtener el nombre de la nota musical
  String get noteName {
    if (chromaticNote != null) {
      return chromaticNote!.englishName;
    }
    return songNote?.noteName ?? '$piston';
  }

  // Verificar si los pistones presionados coinciden
  bool matchesPistons(Set<int> pressedPistons) {
    if (chromaticNote != null) {
      return chromaticNote!.matchesPistonCombination(pressedPistons);
    }
    if (songNote != null) {
      return songNote!.matchesPistonCombination(pressedPistons);
    } else {
      // Lógica original para notas simples
      return pressedPistons.contains(piston);
    }
  }

  // Verificar si es una nota libre (todos en "Aire")
  bool get isOpenNote {
    if (chromaticNote != null) {
      return chromaticNote!.isOpenNote;
    }
    return requiredPistons.isEmpty;
  }

  // Obtener el texto a mostrar en la nota
  String get displayText {
    if (chromaticNote != null) {
      return chromaticNote!.englishName;
    }
    return noteName;
  }

  // Obtener color basado en los pistones requeridos o si es nota libre
  Color get noteColor {
    if (isOpenNote) {
      return Colors.grey; // Nota libre (aire)
    }

    if (chromaticNote != null) {
      return chromaticNote!.noteColor;
    }

    final pistons = requiredPistons;
    if (pistons.isEmpty) {
      return Colors.white; // Sin pistones (nota natural)
    } else if (pistons.length == 1) {
      switch (pistons.first) {
        case 1:
          return Colors.red;
        case 2:
          return Colors.green;
        case 3:
          return Colors.blue;
        default:
          return Colors.white;
      }
    } else {
      // Combinación de pistones - color mezclado
      return Colors.orange;
    }
  }
}

class BegginnerGamePage extends StatefulWidget {
  final String songName;
  final String? songId;
  final String? songImageUrl;
  final String? profileImageUrl;
  final String?
      songDifficulty; // Dificultad de la canción desde la base de datos

  const BegginnerGamePage({
    super.key,
    required this.songName,
    this.songId,
    this.songImageUrl,
    this.profileImageUrl,
    this.songDifficulty,
  });

  @override
  State<BegginnerGamePage> createState() => _BegginnerGamePageState();

  // NUEVO: Método estático para forzar actualización de una canción específica
  static Future<void> forceUpdateSong(String songId) async {
    try {
      print('🔄 Static force update for song: $songId');

      if (Hive.isBoxOpen('offline_data')) {
        final box = Hive.box('offline_data');
        final songCacheKey = 'song_${songId}_complete';
        await box.delete(songCacheKey);
        print('🗑️ Cleared cache for song: $songId');
      }

      // Cargar datos frescos
      final freshNotes = await DatabaseService.getSongNotes(songId);
      print('✅ Loaded ${freshNotes.length} fresh notes for song: $songId');
    } catch (e) {
      print('❌ Error in static force update: $e');
    }
  }
}

class _BegginnerGamePageState extends State<BegginnerGamePage>
    with TickerProviderStateMixin {
  bool showLogo = true;
  bool showCountdown = false;
  int countdownNumber = 3;
  Timer? logoTimer;
  Timer? countdownTimer;

  // NUEVO: Lista para manejar los timers programados de las notas
  List<Timer> _scheduledNoteTimers = [];

  // Estado de los pistones (sin prevención de capturas por pistones)
  Set<int> pressedPistons = <int>{};

  // Sombras de pistones (indica qué pistones deben presionarse ahora)
  Map<int, Color> pistonShadows = {}; // {pistonNumber: shadowColor}

  // Controlador de animación para la rotación de la imagen de la canción
  late AnimationController _rotationController;

  // Variables para el sistema de puntuación y rendimiento
  int currentScore = 0; // Puntuación actual
  int experiencePoints = 0; // Puntos de experiencia (empiezan en 0)
  int totalNotes = 0; // Total de notas tocadas
  int correctNotes = 0; // Notas correctas
  double get accuracy => totalNotes == 0 ? 1.0 : correctNotes / totalNotes;

  // Variables para el sistema Guitar Hero
  List<FallingNote> fallingNotes = [];
  List<SongNote> songNotes = []; // Notas cargadas de la base de datos
  Timer? noteSpawner;
  Timer? gameUpdateTimer;
  late AnimationController _noteAnimationController;
  bool isGameActive = false;
  bool isGamePaused = false;
  bool isLoadingSong = false;
  bool isPreloadingAudio = false; // NUEVO: Estado de precarga de audio
  int audioCacheProgress = 0; // NUEVO: Progreso de descarga (0-100)
  bool _audioCacheCompleted = false; // NUEVO: Si el cache de audio se completó
  Timer? _logoExitTimer; // NUEVO: Timer para salir del logo
  Timer? _endGameTimer; // NUEVO: Timer para mostrar diálogo final
  final Map<String, bool> _audioLoadStatus =
      {}; // NUEVO: Estado de carga de cada audio
  int currentNoteIndex = 0; // Índice de la próxima nota a mostrar
  int gameStartTime = 0; // Tiempo cuando empezó el juego (en milisegundos)
  String?
      lastPlayedNote; // Última nota musical tocada (para mostrar en el contenedor)

  // NUEVO: Sistema de feedback visual
  String? feedbackText; // "Perfecto", "Bien", "Erronea"
  Color? feedbackColor; // Color del feedback
  double feedbackOpacity = 0.0; // Opacidad para animación
  Timer? feedbackTimer; // Timer para ocultar feedback

  // NUEVO: Controlador de audio continuo
  final ContinuousAudioController _audioController =
      ContinuousAudioController();
  bool _isAudioContinuous =
      false; // CAMBIADO: Inicialmente deshabilitado para pruebas
  bool _playerIsOnTrack = true; // Si el jugador está tocando correctamente

  // Configuración del juego
  static const double noteSpeed =
      150.0; // REDUCIDO: pixels por segundo para mejor control
  @Deprecated(
      'Ya no se usa - la detección ahora es basada en distancia del centro')
  // ignore: unused_field
  static const double hitTolerance =
      80.0; // AUMENTADO: Tolerancia para hits más fáciles con la nueva velocidad

  // Sistema de recompensas fijas para nivel principiante según tabla
  // Canciones Fáciles: 10 monedas, Medias: 15 monedas, Difíciles: 20 monedas
  int get coinsPerCorrectNote {
    final String difficulty =
        (widget.songDifficulty ?? 'fácil').toLowerCase().trim();

    // Usar dificultad real de la base de datos según la tabla
    switch (difficulty) {
      case 'fácil':
      case 'facil':
        return 10; // Canciones fáciles en nivel principiante
      case 'medio':
      case 'media':
        return 15; // Canciones medias en nivel principiante
      case 'difícil':
      case 'dificil':
        return 20; // Canciones difíciles en nivel principiante
      default:
        return 10; // Default a fácil
    }
  }

  // Monedas que se van a ganar en este nivel (fijas, no cambian durante el juego)
  int get totalCoins => coinsPerCorrectNote;

  int get experiencePerCorrectNote =>
      1; // Principiante: +1 exp por nota correcta

  @override
  void initState() {
    super.initState();
    _setupScreen();
    _initializeAnimations();
    _initializeHive(); // NUEVO: Inicializar Hive
    _initializeAudio(); // NUEVO: Inicializar servicio de audio
    _runOfflineDiagnostics(); // NUEVO: Diagnóstico offline completo
    _loadSongData(); // Cargar datos musicales
    _startLogoTimer(); // MOVIDO: iniciar timer después de cargar datos
  }

  // NUEVO: Inicializar Hive si no está abierto
  Future<void> _initializeHive() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        print('📂 Opening Hive offline_data box...');
        await Hive.openBox('offline_data');
        print('✅ Hive box opened successfully');
      } else {
        print('✅ Hive box already open');
      }

      // DEBUG: Mostrar información del cache al inicializar
      final box = Hive.box('offline_data');
      final totalKeys = box.keys.length;
      final songKeys = box.keys
          .where((key) =>
              key.toString().startsWith('song_') &&
              key.toString().endsWith('_complete'))
          .length;
      final audioKeys =
          box.keys.where((key) => key.toString().startsWith('audio_')).length;

      print('📊 Hive cache status:');
      print('   📝 Total keys: $totalKeys');
      print('   🎵 Song caches: $songKeys');
      print('   🔊 Audio caches: $audioKeys');
    } catch (e) {
      print('❌ Error initializing Hive: $e');
    }
  }

  // NUEVO: Ejecutar diagnósticos offline completos al inicializar
  Future<void> _runOfflineDiagnostics() async {
    print('🔍 === RUNNING OFFLINE DIAGNOSTICS ===');

    try {
      // Información del juego actual
      print('🎮 Game Info:');
      print('   🆔 Song ID: ${widget.songId}');
      print('   🎵 Song Name: ${widget.songName}');
      print('   🎯 Expected cache key: song_${widget.songId}_complete');
      print('');

      // Verificar estado de Hive
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      // Estadísticas del cache
      final box = Hive.box('offline_data');
      final allKeys = box.keys.toList();
      final songKeys = allKeys
          .where((key) =>
              key.toString().startsWith('song_') &&
              key.toString().endsWith('_complete'))
          .toList();
      final audioKeys =
          allKeys.where((key) => key.toString().startsWith('audio_')).toList();

      print('📊 Cache Statistics:');
      print('   📝 Total entries: ${allKeys.length}');
      print('   🎵 Song caches: ${songKeys.length}');
      print('   🔊 Audio caches: ${audioKeys.length}');
      print('');

      // Verificar si la canción actual está cacheada
      final expectedKey = 'song_${widget.songId}_complete';
      final isCurrentSongCached = box.containsKey(expectedKey);

      print('🎯 Current Song Status:');
      print('   📦 Is cached: ${isCurrentSongCached ? "✅ YES" : "❌ NO"}');

      if (isCurrentSongCached) {
        final songData = box.get(expectedKey);
        if (songData != null) {
          print('   📝 Cached name: ${songData['song_name'] ?? 'unknown'}');
          print('   🎼 Cached notes: ${songData['notes_count'] ?? 0}');
          print(
              '   📅 Cache date: ${DateTime.fromMillisecondsSinceEpoch(songData['cached_timestamp'] ?? 0)}');
          print('   📂 Cache version: ${songData['version'] ?? 'unknown'}');
        }
      } else {
        print('   💡 Song needs to be played online first to cache offline');
      }
      print('');

      // Listar todas las canciones cacheadas
      if (songKeys.isNotEmpty) {
        print('🎵 Available Cached Songs:');
        for (var key in songKeys.take(5)) {
          // Mostrar solo las primeras 5
          final songData = box.get(key);
          if (songData != null) {
            final songId = songData['song_id'] ?? 'unknown';
            final songName = songData['song_name'] ?? 'unknown';
            final notesCount = songData['notes_count'] ?? 0;
            print('   🎵 $songName (ID: $songId) - $notesCount notes');
          }
        }
        if (songKeys.length > 5) {
          print('   ... and ${songKeys.length - 5} more cached songs');
        }
      } else {
        print('🎵 No cached songs found');
        print('   💡 Play songs online first to enable offline mode');
      }
    } catch (e) {
      print('❌ Error running offline diagnostics: $e');
    }

    print('🔍 === END OFFLINE DIAGNOSTICS ===');
    print('');
  }

  // NUEVO: Inicializar el servicio de audio
  Future<void> _initializeAudio() async {
    try {
      await NoteAudioService.initialize();

      // NUEVO: Inicializar controlador de audio continuo
      await _audioController.initialize();

      // NUEVO: Limpiar cache offline antiguo
      await _BegginnerGamePageState.cleanOldOfflineCache();

      // Verificar tamaño del caché y limpiar si es muy grande
      final cacheSizeMB = await NoteAudioService.getCacheSizeMB();
      print('📊 Audio cache size: ${cacheSizeMB.toStringAsFixed(1)} MB');

      if (cacheSizeMB > 50) {
        // Si el caché supera 50MB
        print('🧹 Cache too large, clearing old files...');
        await NoteAudioService.clearOldCache();
      }

      // NUEVO: Mostrar información del cache offline
      final cacheInfo = await _BegginnerGamePageState.getOfflineCacheInfo();
      print('📱 Offline cache info:');
      print('   🎵 Songs cached: ${cacheInfo['total_songs']}');
      print('   🔊 Audio files cached: ${cacheInfo['total_audio_files']}');

      print('✅ Audio services initialized successfully');
    } catch (e) {
      print('❌ Error initializing audio service: $e');
    }
  } // Cargar datos de la canción desde la base de datos

  Future<void> _loadSongData() async {
    print('🔄 Loading song data...');
    print('📋 Song ID: ${widget.songId}');
    print('🎵 Song Name: ${widget.songName}');

    setState(() {
      isLoadingSong = true;
    });

    // MEJORADO: Sistema inteligente que verifica cambios en la base de datos
    if (widget.songId != null && widget.songId!.isNotEmpty) {
      // NUEVO: Verificar conectividad PRIMERO antes de intentar cargar
      bool isOnline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.first != ConnectivityResult.none) {
          final result = await InternetAddress.lookup('google.com');
          isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        }
      } catch (e) {
        print('❌ Error checking connectivity: $e');
        isOnline = false;
      }

      print('🌐 Internet connection: ${isOnline ? "ONLINE" : "OFFLINE"}');

      // Si está OFFLINE, cargar SOLO desde caché y terminar
      if (!isOnline) {
        print('📱 OFFLINE MODE: Loading from cache only...');
        await _loadSongFromOfflineCache();

        if (songNotes.isNotEmpty) {
          print('✅ Loaded ${songNotes.length} notes from offline cache');
          setState(() {
            isLoadingSong = false;
          });
          return; // CRÍTICO: Salir aquí si está offline
        } else {
          print('❌ No cached data found for offline mode');
          setState(() {
            isLoadingSong = false;
          });
          return;
        }
      }

      // Si está ONLINE, intentar cargar desde caché primero y luego verificar actualizaciones
      print('🔍 Loading from offline cache first...');
      await _loadSongFromOfflineCache();

      print('🔍 Checking for database updates...');
      final hasUpdates = await _checkForDatabaseUpdates();

      if (hasUpdates) {
        print('🆕 Database changes detected! Loading fresh data...');
        await _loadFreshDataFromDatabase();
      } else {
        print('✅ Cache is up to date with database');
      }

      // Si después de verificar actualizaciones tenemos datos, validar calidad
      if (songNotes.isNotEmpty) {
        print('✅ Using song data (${songNotes.length} notes)');
        setState(() {
          isLoadingSong = false;
        });
        return;
      }

      // Si no hay datos después de verificar actualizaciones, intentar la base de datos como fallback
      try {
        print('🔍 Loading fresh data from database...');
        songNotes = await DatabaseService.getSongNotes(widget.songId!);

        if (songNotes.isNotEmpty) {
          print(
              '✅ Loaded ${songNotes.length} notes from database for song: ${widget.songName}');

          // Mostrar información detallada de las primeras notas
          for (int i = 0;
              i < (songNotes.length < 5 ? songNotes.length : 5);
              i++) {
            final note = songNotes[i];
            print(
                '🎵 Note $i: ${note.noteName} (chromatic_id: ${note.chromaticId}) - Pistons: ${note.pistonCombination} - URL: ${note.noteUrl}');

            // NUEVO: Verificar si la información cromática está cargada
            if (note.chromaticNote != null) {
              print(
                  '   ✅ ChromaticNote loaded: ${note.chromaticNote!.englishName} (${note.chromaticNote!.spanishName})');
              print('   🎺 Pistons: ${note.chromaticNote!.requiredPistons}');
              print('   🔗 Audio URL: ${note.chromaticNote!.noteUrl}');
            } else {
              print(
                  '   ❌ ChromaticNote NOT loaded for chromatic_id: ${note.chromaticId}');
            }
          }

          // NUEVO: Cargar canción en el controlador de audio continuo
          if (_isAudioContinuous && widget.songId != null) {
            bool songLoaded = await _audioController.loadSong(widget.songId!);
            if (songLoaded) {
              print('✅ Song loaded in continuous audio controller');

              // Configurar callbacks para el controlador
              _audioController.onNoteStart = (note) {
                print('🎵 Continuous audio: Note started - ${note.noteName}');
              };

              _audioController.onNoteEnd = (note) {
                print('✅ Continuous audio: Note ended - ${note.noteName}');
              };

              _audioController.onSongComplete = () {
                print('🎉 Continuous audio: Song completed');
                _endGame();
              };
            } else {
              print(
                  '⚠️ Failed to load song in continuous audio controller, falling back to individual notes');
              _isAudioContinuous = false;
            }
          }

          // NUEVO: Cachear las notas cargadas para uso offline
          print('💾 Caching loaded notes for offline use...');
          await _cacheSongDataOffline();

          // NUEVO: Precargar TODOS los audios durante el logo
          _precacheAllAudioFiles();

          currentNoteIndex = 0;
        } else {
          print('⚠️ No notes found in database for this song');
          // Intentar cargar desde cache offline como fallback
          await _loadSongFromOfflineCache();
        }
      } catch (e) {
        print('❌ Error loading song data from database: $e');
        // Intentar cargar desde cache offline como fallback
        await _loadSongFromOfflineCache();
      }
    } else {
      print('⚠️ No song ID provided, attempting to load from cache');
      await _loadSongFromOfflineCache();
    }

    setState(() {
      isLoadingSong = false;
    });
  }

  // NUEVO: Cargar canción desde cache offline cuando falla la base de datos
  Future<void> _loadSongFromOfflineCache() async {
    print('📱 === LOADING FROM OFFLINE CACHE ===');

    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID for offline cache lookup');
      songNotes = [];
      return;
    }

    try {
      if (!Hive.isBoxOpen('offline_data')) {
        print('📂 Opening Hive offline_data box...');
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';
      print('🔑 Looking for cache key: $songCacheKey');

      // DEBUG: Mostrar todas las claves disponibles en cache
      final allKeys = box.keys.toList();
      print('📋 Available cache keys (${allKeys.length} total):');
      for (var key in allKeys) {
        print('   - $key');
      }

      final cachedSongData = box.get(songCacheKey, defaultValue: null);

      if (cachedSongData == null) {
        print('❌ No cached data found for key: $songCacheKey');
        songNotes = [];
        return;
      }

      print('✅ Found cached data for song: ${widget.songId}');
      print('📊 Cache data keys: ${cachedSongData.keys.toList()}');

      if (cachedSongData['notes_data'] != null) {
        print('📱 Loading song from offline cache...');

        // Reconstruir songNotes desde cache
        songNotes = [];
        final notesData = (cachedSongData['notes_data'] as List).cast<Map>();

        for (var noteData in notesData) {
          // Convertir Map<dynamic, dynamic> a Map<String, dynamic>
          final noteMap = Map<String, dynamic>.from(noteData);

          // Crear SongNote desde datos cached
          final songNote = SongNote(
            id: noteMap['note_id']?.toString() ?? '',
            songId: widget.songId ?? '',
            startTimeMs: noteMap['start_time_ms'] ?? 0,
            durationMs: noteMap['duration_ms'] ?? 1000,
            beatPosition: (noteMap['beat_position'] ?? 0.0) is int
                ? (noteMap['beat_position'] ?? 0.0).toDouble()
                : noteMap['beat_position'] ?? 0.0,
            measureNumber: noteMap['measure_number'] ?? 1,
            noteType: noteMap['note_type'] ?? 'quarter',
            velocity: noteMap['velocity'] ?? 80,
            chromaticId: noteMap['chromatic_id'],
            createdAt: DateTime.fromMillisecondsSinceEpoch(
                noteMap['created_at'] ?? DateTime.now().millisecondsSinceEpoch),
          );

          // NUEVO: Restaurar ChromaticNote desde cache offline si está disponible
          if (noteMap['chromatic_note_data'] != null) {
            final chromaticData = Map<String, dynamic>.from(
                noteMap['chromatic_note_data'] as Map);
            final chromaticNote = ChromaticNote(
              id: chromaticData['id'] ?? 0,
              instrumentId: chromaticData['instrument_id'] ?? 0,
              englishName: chromaticData['english_name'] ?? 'Unknown',
              spanishName: chromaticData['spanish_name'] ?? 'Desconocida',
              octave: chromaticData['octave'] ?? 3,
              alternative: chromaticData['alternative'],
              piston1: chromaticData['piston_1'] ?? 'Aire',
              piston2: chromaticData['piston_2'] ?? 'Aire',
              piston3: chromaticData['piston_3'] ?? 'Aire',
              noteUrl: chromaticData['note_url'],
            );
            songNote.setChromaticNote(chromaticNote);
            print(
                '🎵 Restored ChromaticNote for offline: ${chromaticNote.englishName}');
          } else {
            print(
                '⚠️ No ChromaticNote data in cache for note ${noteMap['note_id']}');
            // Intentar usar los datos básicos si están disponibles
            if (noteMap['note_name'] != null &&
                noteMap['note_name'] != 'Unknown') {
              print('   📝 Using basic cached data: ${noteMap['note_name']}');
            }
          }

          songNotes.add(songNote);
        }

        print(
            '✅ Successfully loaded ${songNotes.length} notes from offline cache');
        print(
            '   📅 Cache timestamp: ${DateTime.fromMillisecondsSinceEpoch(cachedSongData['cached_timestamp'] ?? 0)}');
        print('   📂 Cache version: ${cachedSongData['version'] ?? 'unknown'}');
        print('   🎵 Song name: ${cachedSongData['song_name'] ?? 'unknown'}');
        print(
            '   🎯 Song difficulty: ${cachedSongData['song_difficulty'] ?? 'unknown'}');

        // NUEVO: Verificar estado de las notas cargadas desde cache
        _debugOfflineNoteStatus();

        // NUEVO: Precargar TODOS los audios durante el logo
        _precacheAllAudioFiles();

        currentNoteIndex = 0;
      } else {
        print('❌ No offline cache found for song ${widget.songId}');

        // DEBUG: Mostrar qué canciones están disponibles en cache
        await _debugAvailableCachedSongs();

        songNotes = []; // Lista vacía
      }
    } catch (e) {
      print('❌ Error loading song from offline cache: $e');
      songNotes = []; // Lista vacía en caso de error
    }

    print('📱 === END OFFLINE CACHE LOADING ===');
  }

  // NUEVO: Debug de canciones disponibles en cache offline
  Future<void> _debugAvailableCachedSongs() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songKeys = box.keys
          .where((key) =>
              key.toString().startsWith('song_') &&
              key.toString().endsWith('_complete'))
          .toList();

      print('🎵 === AVAILABLE CACHED SONGS ===');
      print('📊 Total cached songs: ${songKeys.length}');

      if (songKeys.isEmpty) {
        print('❌ No songs found in offline cache');
        print('💡 Make sure to play songs online first to cache them');
      } else {
        for (var key in songKeys) {
          final songData = box.get(key);
          if (songData != null) {
            final songId = songData['song_id'] ?? 'unknown';
            final songName = songData['song_name'] ?? 'unknown';
            final notesCount = songData['notes_count'] ?? 0;
            final cachedTime = DateTime.fromMillisecondsSinceEpoch(
                songData['cached_timestamp'] ?? 0);

            print('🎵 Cached song:');
            print('   🆔 ID: $songId');
            print('   📝 Name: $songName');
            print('   🎼 Notes: $notesCount');
            print('   📅 Cached: ${cachedTime.toString()}');
            print('   🔑 Cache key: $key');
            print('');
          }
        }
      }

      print('🔍 Current song ID: ${widget.songId}');
      print('🔑 Expected cache key: song_${widget.songId}_complete');
      print('🎵 === END CACHED SONGS DEBUG ===');
    } catch (e) {
      print('❌ Error debugging cached songs: $e');
    }
  }

  // MEJORADO: Verificar si hay cambios en la base de datos comparado con el cache
  Future<bool> _checkForDatabaseUpdates() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID to check for updates');
      return false;
    }

    try {
      // Obtener información del cache actual
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';
      final cachedData = box.get(songCacheKey, defaultValue: null);

      if (cachedData == null) {
        print('📝 No cache found, need to load fresh data');
        return true;
      }

      // Información del cache
      final cachedTimestamp = cachedData['cached_timestamp'] ?? 0;
      final cachedNotesCount = cachedData['notes_count'] ?? 0;
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;

      print('📊 Cache Analysis:');
      print(
          '   📅 Cache timestamp: ${DateTime.fromMillisecondsSinceEpoch(cachedTimestamp)}');
      print('   🎵 Cached notes count: $cachedNotesCount');
      print(
          '   ⏰ Cache age: ${(cacheAge / (1000 * 60 * 60)).toStringAsFixed(1)} hours');

      // MEJORADO: Verificar la base de datos si el cache tiene más de 30 minutos
      // O si no tenemos notas cargadas actualmente
      if (cacheAge > (1000 * 60 * 30) || songNotes.isEmpty) {
        // 30 minutes
        print('⏰ Cache is old or no notes loaded, checking database...');

        try {
          // Verificar si tenemos conexión con timeout más corto
          final timeoutDuration = Duration(seconds: 10);

          // Intentar obtener datos frescos de la base de datos con timeout
          final freshNotes = await DatabaseService.getSongNotes(widget.songId!)
              .timeout(timeoutDuration);

          print('🌐 Database Analysis:');
          print('   🎵 Database notes count: ${freshNotes.length}');

          // Si no hay datos en la base de datos, mantener cache
          if (freshNotes.isEmpty) {
            print('⚠️ Database returned no notes, keeping cache');
            return false;
          }

          // Comparar cantidad de notas
          if (freshNotes.length != cachedNotesCount) {
            print(
                '🆕 Note count changed! Cache: $cachedNotesCount, DB: ${freshNotes.length}');
            return true;
          }

          // Verificar calidad de datos (ChromaticNote)
          if (freshNotes.isNotEmpty) {
            int freshNotesWithChromatic = 0;
            int cachedNotesWithChromatic = 0;

            for (var note in freshNotes) {
              if (note.chromaticNote != null) {
                freshNotesWithChromatic++;
              }
            }

            // Verificar las notas cargadas actualmente en lugar de songNotes vacías
            if (songNotes.isNotEmpty) {
              for (var note in songNotes) {
                if (note.chromaticNote != null) {
                  cachedNotesWithChromatic++;
                }
              }
            } else {
              // Si no hay notas cargadas, asumir que necesitamos actualizar
              print('📝 No current notes loaded, need to update');
              return true;
            }

            final freshQuality = freshNotesWithChromatic / freshNotes.length;
            final cachedQuality = songNotes.isNotEmpty
                ? cachedNotesWithChromatic / songNotes.length
                : 0.0;

            print('📈 Quality comparison:');
            print(
                '   🌐 DB ChromaticNote ratio: ${(freshQuality * 100).toStringAsFixed(1)}%');
            print(
                '   💾 Cache ChromaticNote ratio: ${(cachedQuality * 100).toStringAsFixed(1)}%');

            // Si la calidad de la base de datos es significativamente mejor
            if (freshQuality > cachedQuality + 0.1) {
              // 10% better
              print('🆕 Database has better quality data!');
              return true;
            }
          }

          // NUEVO: Actualizar timestamp del cache si los datos están actualizados
          cachedData['last_checked'] = DateTime.now().millisecondsSinceEpoch;
          await box.put(songCacheKey, cachedData);

          print('✅ Cache is up to date with database');
          return false;
        } catch (e) {
          print('❌ Error checking database: $e');
          print('🔄 Assuming cache is current due to network error');
          return false; // Si no hay conexión, usar cache
        }
      } else {
        print('✅ Cache is recent, no need to check database');
        return false;
      }
    } catch (e) {
      print('❌ Error checking for database updates: $e');
      return false;
    }
  }

  // MEJORADO: Cargar datos frescos de la base de datos y actualizar cache
  Future<void> _loadFreshDataFromDatabase() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID to load fresh data');
      return;
    }

    try {
      print('🔄 Loading fresh data from database...');

      // NUEVO: Timeout para evitar esperas indefinidas
      final timeoutDuration = Duration(seconds: 15);
      final freshNotes = await DatabaseService.getSongNotes(widget.songId!)
          .timeout(timeoutDuration);

      if (freshNotes.isNotEmpty) {
        print('✅ Fresh data loaded successfully');
        print('   🎵 Notes loaded: ${freshNotes.length}');

        // Actualizar songNotes con los datos frescos
        songNotes = freshNotes;

        // Verificar calidad de los datos frescos
        int notesWithChromatic = 0;
        int notesWithAudio = 0;
        for (var note in freshNotes) {
          if (note.chromaticNote != null) {
            notesWithChromatic++;
          }
          if (note.noteUrl != null && note.noteUrl!.isNotEmpty) {
            notesWithAudio++;
          }
        }

        final chromaticQuality = notesWithChromatic / freshNotes.length;
        final audioQuality = notesWithAudio / freshNotes.length;

        print('📈 Fresh data quality analysis:');
        print(
            '   🎵 ChromaticNote coverage: ${(chromaticQuality * 100).toStringAsFixed(1)}%');
        print(
            '   🔊 Audio URL coverage: ${(audioQuality * 100).toStringAsFixed(1)}%');

        // MEJORADO: SIEMPRE cachear los datos para uso offline
        print('💾 Updating cache for offline use (quality checks removed)...');

        // Actualizar cache offline con los datos frescos
        await _cacheSongDataOffline();

        // Reset del índice de notas
        currentNoteIndex = 0;

        print('🎉 Cache updated successfully for offline use');
        print('   📊 Cached ${freshNotes.length} notes');
        print(
            '   📊 ChromaticNote coverage: ${(chromaticQuality * 100).toStringAsFixed(1)}%');
        print(
            '   📊 Audio URL coverage: ${(audioQuality * 100).toStringAsFixed(1)}%');

        // Precargar audios si están disponibles (sin bloquear el caché)
        if (audioQuality > 0) {
          print('🔊 Starting audio precaching...');
          _precacheAllAudioFiles(); // Sin await para no bloquear
        } else {
          print('⚠️ No audio URLs available for precaching');
        }
      } else {
        print('⚠️ No fresh data available from database');
      }
    } on TimeoutException {
      print('⏰ Database query timeout, continuing with cached data');
    } catch (e) {
      print('❌ Error loading fresh data from database: $e');
      print('💾 Continuing with cached data...');
    }
  }

  // NUEVO: Debug del estado de las notas cargadas desde cache offline
  void _debugOfflineNoteStatus() {
    print('🔍 === DEBUG OFFLINE NOTES STATUS ===');
    print('📊 Total notes loaded: ${songNotes.length}');

    int notesWithChromatic = 0;
    int notesWithAudio = 0;

    for (int i = 0; i < songNotes.length; i++) {
      final note = songNotes[i];
      final hasChromatic = note.chromaticNote != null;
      final hasAudio = note.noteUrl != null && note.noteUrl!.isNotEmpty;

      if (hasChromatic) notesWithChromatic++;
      if (hasAudio) notesWithAudio++;

      print('  📝 Note ${i + 1}:');
      print('     🏷️  Name: ${note.noteName}');
      print(
          '     🎯  ChromaticNote: ${hasChromatic ? "✅ Loaded" : "❌ Missing"}');
      print('     🔊  Audio URL: ${hasAudio ? "✅ Available" : "❌ Missing"}');
      print('     🎹  Pistons: ${note.pistonCombination}');

      if (hasChromatic) {
        print('     📋  English: ${note.chromaticNote!.englishName}');
        print('     🇪🇸  Spanish: ${note.chromaticNote!.spanishName}');
      }
      print(''); // Línea en blanco
    }

    print('📈 Summary:');
    print(
        '   🎵 Notes with ChromaticNote: ${notesWithChromatic}/${songNotes.length}');
    print('   🔊 Notes with Audio: ${notesWithAudio}/${songNotes.length}');

    if (notesWithChromatic < songNotes.length) {
      print(
          '⚠️ WARNING: ${songNotes.length - notesWithChromatic} notes missing ChromaticNote data!');
    }

    if (notesWithAudio < songNotes.length) {
      print(
          '⚠️ WARNING: ${songNotes.length - notesWithAudio} notes missing audio URLs!');
    }

    print('🔍 === END DEBUG ===');
  }

  // NUEVO: Método robusto de descarga y cache de audio (similar a objects.dart)
  Future<String?> _downloadAndCacheAudio(String url, String cacheKey) async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
    }

    final box = Hive.box('offline_data');
    final cachedData = box.get(cacheKey, defaultValue: null);

    // Verificar si ya está en cache y el archivo existe
    if (cachedData != null &&
        cachedData['url'] == url &&
        cachedData['path'] != null &&
        File(cachedData['path']).existsSync()) {
      print('🎵 Using cached audio: ${cachedData['path']}');
      _audioLoadStatus[cacheKey] = true;
      return cachedData['path'];
    }

    // Validar URL
    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) {
      print('❌ Invalid audio URL: $url');
      _audioLoadStatus[cacheKey] = false;
      return null;
    }

    try {
      print('📥 Downloading audio: $url');

      // Usar el cache manager robusto
      final fileInfo =
          await AudioCacheManager.instance.downloadFile(url).timeout(
                const Duration(seconds: 8), // Timeout de 8 segundos
              );

      final filePath = fileInfo.file.path;

      // Guardar en Hive para persistencia offline
      await box.put(cacheKey, {
        'path': filePath,
        'url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Audio cached successfully: $filePath');
      _audioLoadStatus[cacheKey] = true;
      return filePath;
    } catch (e) {
      print('❌ Error caching audio $url: $e');
      _audioLoadStatus[cacheKey] = false;
      return null;
    }
  }

  // NUEVO: Precargar TODOS los audios Y la canción completa durante la pantalla del logo (SISTEMA ROBUSTO OFFLINE)
  Future<void> _precacheAllAudioFiles() async {
    try {
      setState(() {
        isPreloadingAudio = true;
        audioCacheProgress = 0;
      });

      print('🎵 Starting robust audio and song precaching...');

      if (songNotes.isEmpty) {
        print('⚠️ No notes to precache');
        setState(() {
          isPreloadingAudio = false;
          audioCacheProgress = 100;
          _audioCacheCompleted = true;
        });
        // Proceder inmediatamente al countdown si no hay notas
        _proceedToCountdown();
        return;
      }

      // Paso 1: Cache de la canción completa de la base de datos
      await _cacheSongDataOffline();

      // Paso 2: Obtener todas las URLs únicas de audio de las notas
      final Set<String> uniqueAudioUrls = {};
      for (var note in songNotes) {
        if (note.noteUrl != null && note.noteUrl!.isNotEmpty) {
          uniqueAudioUrls.add(note.noteUrl!);
        }
      }

      print('📥 Found ${uniqueAudioUrls.length} unique audio files to cache');

      // Paso 3: Cache de audios de notas
      if (uniqueAudioUrls.isEmpty) {
        setState(() {
          isPreloadingAudio = false;
          audioCacheProgress = 100;
          _audioCacheCompleted = true;
        });
        _proceedToCountdown();
        return;
      }

      // Descargar audios uno por uno con sistema robusto
      int processedCount = 0;
      int successCount = 0;

      for (String url in uniqueAudioUrls) {
        final cacheKey = 'audio_${url.hashCode}';

        try {
          final cachedPath = await _downloadAndCacheAudio(url, cacheKey);
          if (cachedPath != null) {
            successCount++;
            print(
                '✅ Cached audio (${processedCount + 1}/${uniqueAudioUrls.length}): Success');
          } else {
            print(
                '⚠️ Failed to cache audio (${processedCount + 1}/${uniqueAudioUrls.length}): ${url.split('/').last}');
          }
        } catch (e) {
          print(
              '❌ Error caching audio (${processedCount + 1}/${uniqueAudioUrls.length}): $e');
        }

        processedCount++;

        if (mounted) {
          setState(() {
            audioCacheProgress =
                ((processedCount / uniqueAudioUrls.length) * 100).round();
          });
        }
      }

      if (mounted) {
        setState(() {
          isPreloadingAudio = false;
          audioCacheProgress = 100;
          _audioCacheCompleted = true;
        });
      }

      print('🎉 Complete caching finished!');
      print('   📱 Song data: ✅ Cached offline');
      print(
          '   � Audio files: ${successCount}/${uniqueAudioUrls.length} cached successfully');

      // Proceder al countdown ahora que el cache está completo
      _proceedToCountdown();
    } catch (e) {
      print('❌ Error during complete precaching: $e');
      if (mounted) {
        setState(() {
          isPreloadingAudio = false;
          audioCacheProgress = 100;
          _audioCacheCompleted = true;
        });
      }
      // Proceder al countdown aunque haya errores
      _proceedToCountdown();
    }
  }

  // NUEVO: Cache offline de los datos completos de la canción para funcionamiento offline
  Future<void> _cacheSongDataOffline() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('⚠️ No song ID to cache');
      return;
    }

    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';

      print('💾 Caching complete song data for offline use...');

      // MEJORADO: Crear estructura completa de datos de la canción para cache offline
      final now = DateTime.now().millisecondsSinceEpoch;

      // Analizar calidad de los datos antes de cachear
      int notesWithChromatic = 0;
      int notesWithAudio = 0;

      for (var note in songNotes) {
        if (note.chromaticNote != null) notesWithChromatic++;
        if (note.noteUrl != null && note.noteUrl!.isNotEmpty) notesWithAudio++;
      }

      final chromaticQuality =
          songNotes.isNotEmpty ? notesWithChromatic / songNotes.length : 0.0;
      final audioQuality =
          songNotes.isNotEmpty ? notesWithAudio / songNotes.length : 0.0;

      final songCacheData = {
        'song_id': widget.songId,
        'song_name': widget.songName,
        'song_difficulty': widget.songDifficulty,
        'song_image_url': widget.songImageUrl,
        'profile_image_url': widget.profileImageUrl,
        'notes_count': songNotes.length,
        'cached_timestamp': now,
        'last_checked': now,
        'version': '2.0', // Versión mejorada
        'quality_metrics': {
          'chromatic_coverage': chromaticQuality,
          'audio_coverage': audioQuality,
          'notes_with_chromatic': notesWithChromatic,
          'notes_with_audio': notesWithAudio,
        },
        'notes_data': songNotes
            .map((note) => {
                  'note_id': note.id,
                  'song_id': note.songId,
                  'start_time_ms': note.startTimeMs,
                  'duration_ms': note.durationMs,
                  'beat_position': note.beatPosition,
                  'measure_number': note.measureNumber,
                  'note_type': note.noteType,
                  'velocity': note.velocity,
                  'chromatic_id': note.chromaticId,
                  'created_at': note.createdAt.millisecondsSinceEpoch,
                  // MEJORADO: Guardar información completa de ChromaticNote para uso offline
                  'note_name': note.noteName,
                  'piston_combination': note.pistonCombination,
                  'note_url': note.noteUrl,
                  // NUEVO: Información completa del ChromaticNote si está disponible
                  'chromatic_note_data': note.chromaticNote != null
                      ? {
                          'id': note.chromaticNote!.id,
                          'instrument_id': note.chromaticNote!.instrumentId,
                          'english_name': note.chromaticNote!.englishName,
                          'spanish_name': note.chromaticNote!.spanishName,
                          'octave': note.chromaticNote!.octave,
                          'alternative': note.chromaticNote!.alternative,
                          'piston_1': note.chromaticNote!.piston1,
                          'piston_2': note.chromaticNote!.piston2,
                          'piston_3': note.chromaticNote!.piston3,
                          'note_url': note.chromaticNote!.noteUrl,
                        }
                      : null,
                })
            .toList(),
      };

      // Guardar en Hive para acceso offline
      await box.put(songCacheKey, songCacheData);

      // CRÍTICO: Forzar escritura en disco para persistencia
      await box.flush();

      // VERIFICACIÓN: Confirmar que se guardó correctamente
      final verifyData = box.get(songCacheKey);
      if (verifyData != null) {
        print('VERIFIED: Song data cached and persisted successfully!');
        print('   Song: ${widget.songName}');
        print('   ID: ${widget.songId}');
        print('   Notes: ${songNotes.length}');
        print('   Quality metrics:');
        print(
            '      ChromaticNote coverage: ${(chromaticQuality * 100).toStringAsFixed(1)}%');
        print(
            '      Audio URL coverage: ${(audioQuality * 100).toStringAsFixed(1)}%');
        print('   Cache key: $songCacheKey');
        print('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(now)}');
        print('   Hive box path: ${box.path}');
        print('   Total keys in box: ${box.keys.length}');
      } else {
        print('ERROR: Failed to verify cached data after flush!');
      }
    } catch (e) {
      print('Error caching song data offline: $e');
    }
  }

  @override
  void dispose() {
    logoTimer?.cancel();
    countdownTimer?.cancel();
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();
    _logoExitTimer?.cancel(); // NUEVO: Cancelar timer de salida del logo
    _endGameTimer?.cancel(); // NUEVO: Cancelar timer de diálogo final
    feedbackTimer?.cancel(); // NUEVO: Cancelar timer de feedback visual
    _pistonCombinationTimer
        ?.cancel(); // NUEVO: Cancelar timer de combinaciones de pistones

    // NUEVO: Cancelar todos los timers programados de notas
    for (final timer in _scheduledNoteTimers) {
      timer.cancel();
    }
    _scheduledNoteTimers.clear();
    _rotationController.dispose();
    _noteAnimationController.dispose();

    // NUEVO: Detener cualquier sonido en reproducción
    NoteAudioService.stopAllSounds();

    // NUEVO: Limpiar controlador de audio continuo
    _audioController.dispose();

    // Restaurar configuración normal al salir
    _restoreNormalMode();
    super.dispose();
  }

  void _restoreNormalMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    // Restaurar la función normal de capturas
    SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: 'REFMP',
        primaryColor: 0xFF1E3A8A,
      ),
    );
  }

  Future<void> _setupScreen() async {
    // Rotar pantalla automáticamente a landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Ocultar la barra de estado del sistema
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // Deshabilitar capturas de pantalla durante todo el juego
    await SystemChrome.setApplicationSwitcherDescription(
      const ApplicationSwitcherDescription(
        label: 'REFMP - Juego Activo',
        primaryColor: 0xFF000000,
      ),
    );
  }

  void _startLogoTimer() {
    // Timer máximo de seguridad (6 segundos) - si no se completa la descarga, continuar
    _logoExitTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && showLogo) {
        print('⏰ Logo timer expired, proceeding to countdown...');
        _proceedToCountdown();
      }
    });

    // No iniciar countdown automáticamente - esperar a que termine el cache o expire el timer
  }

  // NUEVO: Proceder al countdown cuando el cache esté listo o expire el timer
  void _proceedToCountdown() {
    if (mounted && showLogo) {
      setState(() {
        showLogo = false;
        showCountdown = true;
      });
      _startCountdown();
    }
  }

  void _startCountdown() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          countdownNumber--;
        });

        if (countdownNumber <= 0) {
          timer.cancel();
          setState(() {
            showCountdown = false;
          });
          // Iniciar el juego Guitar Hero
          _startGame();
        }
      }
    });
  }

  void _initializeAnimations() {
    // Controlador para la rotación continua de la imagen de la canción
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(); // Repetir infinitamente

    // Controlador para las notas que caen
    _noteAnimationController = AnimationController(
      duration: const Duration(seconds: 4), // Tiempo que tarda en caer una nota
      vsync: this,
    );
  }

  // Iniciar el juego Guitar Hero
  void _startGame() {
    print('🎮 Starting game...');

    // Si aún está cargando, esperar un poco
    if (isLoadingSong) {
      print('⏳ Still loading song data, waiting...');
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) _startGame();
      });
      return;
    }

    // Si no hay notas, mostrar mensaje pero no crear demo
    if (songNotes.isEmpty) {
      print('⚠️ No notes available for this song');
    }

    setState(() {
      isGameActive = true;
      currentNoteIndex = 0; // Reset index
      _playerIsOnTrack = true; // Inicializar como que el jugador está correcto
    });

    print('📝 Song notes count: ${songNotes.length}');
    print('🎵 Current note index: $currentNoteIndex');

    // DEBUG: Mostrar timing completo de todas las notas y verificar URLs de audio
    if (songNotes.isNotEmpty) {
      print('🎼 === COMPLETE SONG TIMING & AUDIO ANALYSIS ===');
      print('📊 Total notes: ${songNotes.length}');
      int notesWithAudio = 0;

      for (int i = 0; i < songNotes.length; i++) {
        final note = songNotes[i];
        final hasAudio = note.noteUrl != null && note.noteUrl!.isNotEmpty;
        if (hasAudio) notesWithAudio++;

        final hasChromatic = note.chromaticNote != null;
        print(
            '  📝 Note ${i + 1}: ${note.noteName} ${hasChromatic ? "✅" : "❌ UNKNOWN"}');
        print(
            '     ⏰ Start time: ${note.startTimeMs}ms (${(note.startTimeMs / 1000).toStringAsFixed(1)}s)');
        print('     ⏱️ Duration: ${note.durationMs}ms');
        print('     🎹 Pistons: ${note.pistonCombination}');
        print(
            '     🎯 ChromaticNote: ${hasChromatic ? "✅ Loaded (${note.chromaticNote!.englishName})" : "❌ Missing"}');
        print(
            '     🔊 Audio: ${hasAudio ? "✅ " + note.noteUrl! : "❌ NO AUDIO"}');

        if (i > 0) {
          final prevNote = songNotes[i - 1];
          final timeDiff = note.startTimeMs - prevNote.startTimeMs;
          print(
              '     📏 Gap from previous: ${timeDiff}ms (${(timeDiff / 1000).toStringAsFixed(1)}s)');

          if (timeDiff < 500) {
            print('     ⚠️  WARNING: Very close timing! (< 500ms)');
          }
        }
        print(''); // Línea en blanco para separar
      }

      print(
          '🔊 Audio summary: ${notesWithAudio}/${songNotes.length} notes have audio URLs');
      if (notesWithAudio < songNotes.length) {
        print(
            '⚠️ WARNING: ${songNotes.length - notesWithAudio} notes are missing audio!');
      }
      print('🎼 === END ANALYSIS ===');
    }

    // NUEVO: Iniciar tracking de audio continuo si está disponible
    if (_isAudioContinuous) {
      print('🎵 Starting continuous audio tracking...');
      _audioController.startTracking().then((_) {
        print('✅ Continuous audio tracking started successfully');
      }).catchError((e) {
        print('❌ Error starting continuous audio tracking: $e');
        // Fallback a sistema normal
        _isAudioContinuous = false;
      });
    }

    _spawnNotes();
    _updateGame();
  }

  // Mostrar opciones cuando no hay notas en la canción
  void _showEmptySongOptions() {
    // Mostrar un timer para permitir salir después de 10 segundos
    Timer(const Duration(seconds: 10), () {
      if (mounted && isGameActive && songNotes.isEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.blue, width: 2),
            ),
            title: Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  'Modo Práctica',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
            content: Text(
              'Esta canción no tiene notas cargadas.\n¿Deseas continuar practicando o regresar al menú?',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  // Continuar en modo práctica
                },
                child: Text(
                  'Seguir practicando',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Regresar al menú
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Regresar al menú'),
              ),
            ],
          ),
        );
      }
    });
  }

  // Generar notas basadas en los datos de la base de datos
  void _spawnNotes() {
    gameStartTime = DateTime.now().millisecondsSinceEpoch;
    print('🕒 Game start time: $gameStartTime');

    if (songNotes.isNotEmpty) {
      print(
          '🎵 Using real song notes from database (${songNotes.length} notes)');
      _spawnNotesFromDatabase();
    } else {
      print('⚠️ No notes available for this song');
      // Permitir al usuario practicar, pero mostrar opción de salir después de un tiempo
      _showEmptySongOptions();
    }
  }

  // NUEVO: Sistema programado - todas las notas se programan después del countdown
  void _spawnNotesFromDatabase() {
    print('🎯 Programming all ${songNotes.length} notes after countdown');

    // Calcular tiempo de caída una sola vez
    final screenHeight = MediaQuery.of(context).size.height;
    final fallDistance = screenHeight * 1.3;
    final fallTimeMs = (fallDistance / noteSpeed * 1000).round();

    print(
        '📐 Fall time calculated: ${fallTimeMs}ms for ${fallDistance}px at ${noteSpeed}px/s');

    // Programar cada nota individualmente con Timer.delayed
    for (int i = 0; i < songNotes.length; i++) {
      final songNote = songNotes[i];
      final noteAppearTime = songNote.startTimeMs - fallTimeMs;

      print('📅 Programming note ${i + 1}: ${songNote.noteName}');
      print('  - DB hit time: ${songNote.startTimeMs}ms');
      print('  - Will appear at: ${noteAppearTime}ms');

      // Programar la aparición de la nota con Timer.delayed y guardar referencia
      final timer = Timer(Duration(milliseconds: noteAppearTime), () {
        if (isGameActive && !isGamePaused) {
          _spawnSingleNote(songNote, i);
        }
      });

      _scheduledNoteTimers.add(timer);
    }

    print('🏁 All ${songNotes.length} notes programmed successfully');
  }

  // Spawn individual de una nota con posicionamiento basado en tiempo
  void _spawnSingleNote(SongNote songNote, int index) {
    print('🎵 Spawning scheduled note: ${songNote.noteName}');

    // Calcular posición Y basada estrictamente en el tiempo de aparición
    final currentGameTime =
        DateTime.now().millisecondsSinceEpoch - gameStartTime;
    final screenHeight = MediaQuery.of(context).size.height;
    final fallTimeMs = ((screenHeight * 1.3) / noteSpeed * 1000).round();

    // La nota debe aparecer exactamente cuando sea su momento
    final expectedAppearTime = songNote.startTimeMs - fallTimeMs;
    final timeDifference = currentGameTime - expectedAppearTime;

    // Calcular posición Y basada en cuánto tiempo ha pasado desde que debería haber aparecido
    final initialY = -screenHeight * 0.3;
    final adjustedY = initialY + (timeDifference * noteSpeed / 1000);

    print('  - Expected appear time: ${expectedAppearTime}ms');
    print('  - Current game time: ${currentGameTime}ms');
    print('  - Time difference: ${timeDifference}ms');
    print('  - Calculated Y position: ${adjustedY.toStringAsFixed(1)}');

    final fallingNote = FallingNote(
      piston: songNote.pistonCombination.isNotEmpty
          ? songNote.pistonCombination.first
          : 1,
      songNote: songNote,
      chromaticNote: songNote.chromaticNote,
      y: adjustedY,
      startTime: DateTime.now().millisecondsSinceEpoch / 1000,
    );

    setState(() {
      fallingNotes.add(fallingNote);
    });

    print(
        '✅ Note ${songNote.noteName} spawned at Y: ${adjustedY.toStringAsFixed(1)}');
  }

  // ELIMINADO: Ya no necesario con el nuevo sistema programado

  // ELIMINADO: Ya no necesario con el nuevo sistema programado

  // Actualizar posiciones de las notas basado en tiempo real
  void _updateGame() {
    gameUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // ~60 FPS
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      setState(() {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // Calcular zona de hit responsive - EN EL CENTRO DE LA PANTALLA
        final isTablet = screenWidth > 600;
        final isSmallPhone = screenHeight < 700;

        // Zona de hit en el centro de la pantalla (mucho más arriba que los pistones)
        final hitZoneHeight = isSmallPhone ? 100.0 : (isTablet ? 140.0 : 120.0);

        // Colocar la zona de hit un poco más abajo del centro de la pantalla
        final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2) + 80;
        final hitZoneCenterY = hitZoneY + (hitZoneHeight / 2);

        // Actualizar sombras de pistones según notas activas en zona de hit
        Map<int, Color> newShadows = {};
        for (var note in fallingNotes) {
          if (note.isHit || note.isMissed) continue;

          final noteBottom = note.y + 60;
          final noteTop = note.y;

          // Si la nota está en o cerca de la zona de hit, mostrar sombra
          if (noteBottom >= hitZoneY - 50 &&
              noteTop <= hitZoneY + hitZoneHeight + 50) {
            final pistons = note.requiredPistons;
            final shadowColor = Colors.blue.withOpacity(0.5);

            if (pistons.isEmpty) {
              // Nota de aire - sombra en todos los pistones
              newShadows[1] = shadowColor;
              newShadows[2] = shadowColor;
              newShadows[3] = shadowColor;
            } else {
              for (int piston in pistons) {
                newShadows[piston] = shadowColor;
              }
            }
          }
        }
        pistonShadows = newShadows;

        // SIMPLIFICADO: Actualizar posición de cada nota usando movimiento tradicional
        for (var note in fallingNotes) {
          if (!note.isHit && !note.isMissed) {
            final elapsed =
                DateTime.now().millisecondsSinceEpoch / 1000 - note.startTime;

            // Movimiento tradicional: desde posición inicial hacia abajo
            final initialY = -screenHeight * 0.3;
            note.y = initialY + (elapsed * noteSpeed);

            // DEBUG: Imprimir posición de las primeras notas
            if (note.songNote != null && note.songNote!.startTimeMs <= 6000) {
              print(
                  '📍 Note ${note.noteName}: Y=${note.y.toStringAsFixed(1)}, elapsed=${elapsed.toStringAsFixed(1)}s, DB_time=${note.songNote!.startTimeMs}ms');
            }

            // AUTO-HIT para notas de aire (sin presionar pistones) - SOLO EN EL CENTRO
            if (note.isOpenNote) {
              final noteCenter = note.y + 30;

              // Solo auto-hit si la nota está en el centro exacto (25% del hit zone)
              final hitZoneHeight = 120.0;
              final perfectZone = hitZoneHeight * 0.25;
              final distanceFromCenter = (noteCenter - hitZoneCenterY).abs();

              if (distanceFromCenter < perfectZone) {
                print('🌬️ AUTO-HIT for open note (aire): ${note.noteName}');
                note.isHit = true;

                // Actualizar la última nota tocada para mostrar en el contenedor
                setState(() {
                  lastPlayedNote = note.noteName;
                });

                // MEJORADO: Solo reproducir sonido si NO está usando audio continuo
                if (!_isAudioContinuous &&
                    note.songNote != null &&
                    note.songNote!.noteUrl != null) {
                  _playFromRobustCache(note.songNote!);
                } else if (_isAudioContinuous) {
                  print(
                      '🔇 Audio continuo activo - no reproducir nota de aire automática');
                }

                _onNoteHit(note.noteName, 1.0); // Perfect timing
                continue; // Pasar a la siguiente nota
              }
            }

            // Verificar si la nota se perdió (pasó de la zona de hit)
            final noteTop = note.y;
            final hitZoneHeight = 120.0;
            if (noteTop > hitZoneCenterY + (hitZoneHeight / 2)) {
              // Reducido de +80 a +50 para eliminar notas más rápido
              note.isMissed = true;
              print('❌ Note missed: ${note.noteName} at Y: ${note.y}');

              // NUEVO: Notificar al controlador cuando se pierde una nota
              if (_isAudioContinuous && _playerIsOnTrack) {
                _audioController.onPlayerMiss();
                _playerIsOnTrack = false;
                print('🔇 Note missed');
              }

              _onNoteMissed();
            }
          }
        }

        // Remover notas que ya no se necesitan (más agresivo)
        fallingNotes.removeWhere((note) =>
            note.y > hitZoneY + 100 || // Eliminar notas que pasaron muy abajo
            note.isHit ||
            note.isMissed);

        // Verificar si el juego ha terminado
        _checkGameEnd();
      });
    });
  }

  // MEJORADO: Verificar si el juego ha terminado cuando acabe la duración completa de la última nota
  void _checkGameEnd() {
    // Verificar si hay notas para mostrar
    if (songNotes.isEmpty) {
      return; // Juego sin notas, continúa indefinidamente
    }

    // Verificar si todas las notas ya aparecieron y no hay notas cayendo
    final currentGameTime =
        DateTime.now().millisecondsSinceEpoch - gameStartTime;
    final lastNoteTime = songNotes.isNotEmpty ? songNotes.last.startTimeMs : 0;
    final lastNoteDuration =
        songNotes.isNotEmpty ? songNotes.last.durationMs : 1000;

    // El juego termina EXACTAMENTE cuando acaba la duración completa de la última nota
    // Sin buffer adicional - solo el tiempo exacto que dura el sonido
    final expectedEndTime = lastNoteTime + lastNoteDuration;
    final gameTimePassed = currentGameTime >= expectedEndTime;

    if (gameTimePassed) {
      print('🏁 Game ended! Last note duration completed.');
      print('   Current time: ${currentGameTime}ms');
      print('   Last note start: ${lastNoteTime}ms');
      print('   Last note duration: ${lastNoteDuration}ms');
      print('   Note end time: ${expectedEndTime}ms');
      print(
          '   Sound finished: ${currentGameTime >= expectedEndTime ? "✅" : "❌"}');
      _endGame();
    } else {
      // Debug: mostrar estado actual cada 2 segundos
      if (currentGameTime % 2000 < 100) {
        final timeLeft = expectedEndTime - currentGameTime;
        print('🔄 Game status: ${timeLeft}ms remaining until last note ends');
      }
    }
  }

  // Finalizar el juego y mostrar resultados
  void _endGame() {
    setState(() {
      isGameActive = false;
      isGamePaused = false;
    });

    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();

    // NUEVO: Parar audio continuo
    if (_isAudioContinuous) {
      _audioController.stop();
    }

    // NUEVO: Esperar 2 segundos antes de mostrar el diálogo para que termine la última nota
    _endGameTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _showGameResults();
      }
    });
  }

  // Mostrar resultados del juego
  void _showGameResults() {
    // Guardar experiencia y monedas en la base de datos
    _saveExperienceAndCoins();

    showCongratulationsDialog(
      context,
      experiencePoints: experiencePoints,
      correctNotes: correctNotes,
      missedNotes: totalNotes - correctNotes,
      coins: totalCoins, // Monedas ganadas por completar la canción
      source: 'beginner_game',
      sourceName: widget.songName,
      onContinue: () {
        Navigator.pop(context); // Regresar al menú anterior
      },
    );
  }

  // Guardar puntos de experiencia y monedas en la base de datos
  Future<void> _saveExperienceAndCoins() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('⚠️ Usuario no autenticado');
        return;
      }

      if (experiencePoints <= 0 && totalCoins <= 0) {
        print('⚠️ No hay puntos ni monedas para guardar');
        return;
      }

      print(
          '💾 Guardando $experiencePoints puntos XP y $totalCoins monedas...');

      // 1. Actualizar en tabla de perfil del usuario (solo XP)
      // ignore: unused_local_variable
      bool profileUpdated = false;
      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents'
      ];

      for (String table in tables) {
        try {
          final userRecord = await supabase
              .from(table)
              .select('points_xp')
              .eq('user_id', user.id)
              .maybeSingle();

          if (userRecord != null) {
            final currentXP = userRecord['points_xp'] ?? 0;
            final newXP = currentXP + experiencePoints;

            await supabase
                .from(table)
                .update({'points_xp': newXP}).eq('user_id', user.id);

            print('✅ Perfil actualizado en $table: $currentXP → $newXP XP');
            profileUpdated = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      // 2. Actualizar en users_games (XP semanal, XP total y monedas)
      final existingRecord = await supabase
          .from('users_games')
          .select('points_xp_totally, points_xp_weekend, coins')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingRecord != null) {
        final currentTotal = existingRecord['points_xp_totally'] ?? 0;
        final currentWeekend = existingRecord['points_xp_weekend'] ?? 0;
        final currentCoins = existingRecord['coins'] ?? 0;

        final newTotal = currentTotal + experiencePoints;
        final newWeekend = currentWeekend + experiencePoints;
        final newCoins = currentCoins + totalCoins;

        await supabase.from('users_games').update({
          'points_xp_totally': newTotal,
          'points_xp_weekend': newWeekend,
          'coins': newCoins,
        }).eq('user_id', user.id);

        print(
            '✅ users_games actualizado: +$experiencePoints XP, +$totalCoins monedas');
        print(
            '   📊 Totales: $newTotal XP total, $newWeekend XP semanal, $newCoins monedas');
      } else {
        await supabase.from('users_games').insert({
          'user_id': user.id,
          'nickname': 'Usuario',
          'points_xp_totally': experiencePoints,
          'points_xp_weekend': experiencePoints,
          'coins': totalCoins,
          'created_at': DateTime.now().toIso8601String(),
        });

        print('✅ Nuevo registro en users_games creado');
      }

      // Calcular stars basado en accuracy
      final stars = accuracy >= 0.9
          ? 3
          : accuracy >= 0.7
              ? 2
              : accuracy >= 0.5
                  ? 1
                  : 0;

      // Registrar en historial de XP
      await _recordXpHistory(
        user.id,
        experiencePoints,
        'beginner_game',
        widget.songId ?? 'unknown',
        widget.songName,
        {
          'difficulty': widget.songDifficulty ?? 'fácil',
          'coins_earned': totalCoins,
          'accuracy': accuracy,
          'stars': stars,
        },
      );

      print('✅ Guardado completado exitosamente');
    } catch (e) {
      print('❌ Error al guardar puntos y monedas: $e');
    }
  }

  Future<void> _recordXpHistory(
    String userId,
    int pointsEarned,
    String source,
    String sourceId,
    String sourceName,
    Map<String, dynamic> sourceDetails,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('xp_history').insert({
        'user_id': userId,
        'points_earned': pointsEarned,
        'source': source,
        'source_id': sourceId,
        'source_name': sourceName,
        'source_details': sourceDetails,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ Historial de XP registrado: +$pointsEarned XP desde $source');
    } catch (e) {
      print('❌ Error al registrar historial de XP: $e');
      // No fallar el proceso principal si falla el historial
    }
  }

  // Métodos de control de pausa
  void _pauseGame() {
    if (isGameActive && !isGamePaused) {
      setState(() {
        isGamePaused = true;
      });
      noteSpawner?.cancel();
      gameUpdateTimer?.cancel();

      // NUEVO: Pausar audio continuo
      if (_isAudioContinuous) {
        _audioController.pause();
      }

      showPauseDialog(
        context,
        widget.songName,
        _resumeGame,
        _restartGame,
        onResumeFromBack: _resumeGame,
      );
    }
  }

  void _resumeGame() {
    if (isGameActive && isGamePaused) {
      setState(() {
        isGamePaused = false;
      });

      // NUEVO: Reanudar audio continuo
      if (_isAudioContinuous) {
        _audioController.resume();
      }

      _spawnNotes();
      _updateGame();
    }
  }

  void _restartGame() {
    print('🔄 Restarting game...');

    // NO cerrar diálogos aquí - el diálogo ya se cierra desde pause_dialog.dart
    // El Navigator.pop() estaba causando que se saliera del juego completamente

    // Reiniciar variables del juego
    setState(() {
      isGameActive = false;
      isGamePaused = false;
      fallingNotes.clear();
      totalNotes = 0;
      correctNotes = 0;
      currentScore = 0;
      experiencePoints = 0;
      currentNoteIndex = 0; // Reiniciar índice de notas
      pressedPistons.clear(); // Limpiar pistones presionados
      lastPlayedNote = null; // Limpiar última nota tocada
      _playerIsOnTrack = true; // Reiniciar estado del jugador
    });

    // NUEVO: Parar audio continuo
    if (_isAudioContinuous) {
      _audioController.stop();
    }

    // Cancelar TODOS los timers
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();
    countdownTimer?.cancel(); // ¡Importante! Cancelar el timer del countdown
    _endGameTimer?.cancel(); // NUEVO: Cancelar timer de diálogo final si existe

    // NUEVO: Cancelar todos los timers programados de notas
    for (final timer in _scheduledNoteTimers) {
      timer.cancel();
    }
    _scheduledNoteTimers.clear();

    // Reiniciar tiempo de inicio del juego
    gameStartTime = 0;

    print('🎮 Starting countdown for restart...');

    // Iniciar countdown nuevamente
    setState(() {
      showCountdown = true;
      countdownNumber = 3;
    });
    _startCountdown();
  }

  // void _endGame() {
  //   setState(() {
  //     isGameActive = false;
  //     isGamePaused = false;
  //   });

  //   noteSpawner?.cancel();
  //   gameUpdateTimer?.cancel();

  //   showCongratulationsDialog(
  //     context,
  //     experiencePoints: experiencePoints,
  //     totalScore: currentScore,
  //     correctNotes: correctNotes,
  //     missedNotes: totalNotes - correctNotes,
  //     onContinue: () {
  //       Navigator.pop(context); // Regresar al menú anterior
  //     },
  //   );
  // }

  // MEJORADO: Verificar si el jugador está tocando la nota correcta con mejor detección de combinaciones

  // NUEVO: Verificar hit con combinación específica (para mejor timing en 3 pistones)
  void _checkNoteHitWithCombination(Set<int> pistonCombination) {
    bool hitCorrectNote = false;
    bool isInHitZone = false;

    print('🎯 Checking note hit with combination: $pistonCombination');

    // Primero verificar si hay alguna nota en la zona de hit
    for (var note in fallingNotes) {
      if (!note.isHit && !note.isMissed) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // Calcular zona de hit responsive en el centro de la pantalla
        final isTablet = screenWidth > 600;
        final isSmallPhone = screenHeight < 700;

        final hitZoneHeight = isSmallPhone ? 100.0 : (isTablet ? 140.0 : 120.0);
        final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2) + 80;
        final hitZoneCenterY = hitZoneY + (hitZoneHeight / 2);

        final noteCenter = note.y + 30;
        final noteBottom = note.y + 60;
        final noteTop = note.y;
        final distanceFromCenter = (noteCenter - hitZoneCenterY).abs();

        // Definir zonas de hit basadas en distancia del centro
        final perfectZone = hitZoneHeight * 0.25; // 25% del centro es "perfect"
        final goodZone = hitZoneHeight * 0.4; // 40% del centro es "good"

        // Verificar si la nota está en la zona de hit
        if (noteBottom >= hitZoneY && noteTop <= hitZoneY + hitZoneHeight) {
          isInHitZone = true;

          // MEJORADO: Debug para combinaciones complejas
          if (note.requiredPistons.length >= 2) {
            print('🔍 === MULTI-PISTON COMBINATION DEBUG ===');
            print('   Note: ${note.noteName}');
            print('   Required pistons: ${note.requiredPistons}');
            print('   Combination used: $pistonCombination');
            print('   Note center Y: ${noteCenter.toStringAsFixed(1)}');
            print('   Hit zone center Y: ${hitZoneCenterY.toStringAsFixed(1)}');
            print(
                '   Distance from center: ${distanceFromCenter.toStringAsFixed(1)}');
            print('   Press times:');

            final currentTime = DateTime.now().millisecondsSinceEpoch;
            for (var piston in pistonCombination) {
              final pressTime = _pistonPressTime[piston];
              if (pressTime != null) {
                final timeDiff = currentTime - pressTime;
                print('     Pistón $piston: ${timeDiff}ms ago');
              }
            }
          }

          // Verificar si los pistones presionados coinciden EXACTAMENTE con la nota
          if (_exactPistonMatch(note, pistonCombination)) {
            print(
                '✅ EXACT HIT! Note: ${note.noteName}, Required: ${note.requiredPistons}, Used: $pistonCombination');
            note.isHit = true;
            hitCorrectNote = true;

            setState(() {
              lastPlayedNote = note.noteName;
            });

            // NUEVO: Notificar al controlador que el jugador acertó
            if (_isAudioContinuous) {
              _audioController.onPlayerHit(pistonCombination);
              if (!_playerIsOnTrack) {
                _playerIsOnTrack = true;
                print('🔊 Player back on track');
              }
            }

            // NUEVO: Calcular calidad del timing basado en distancia del centro
            double timingQuality;
            String feedback;
            Color feedbackColor;

            if (distanceFromCenter < perfectZone) {
              timingQuality = 1.0;
              feedback = 'Perfect';
              feedbackColor = Colors.green;
            } else if (distanceFromCenter < goodZone) {
              timingQuality = 0.7;
              feedback = 'Good';
              feedbackColor = Colors.blue;
            } else {
              timingQuality = 0.5;
              feedback = 'Regular';
              feedbackColor = Colors.orange;
            }

            _showFeedback(feedback, feedbackColor);
            _onNoteHit(note.noteName, timingQuality);

            // Feedback háptico
            HapticFeedback.mediumImpact();

            return;
          } else {
            // Debug: mostrar qué se esperaba vs qué se usó
            print('🔍 COMBINATION MISMATCH - Note: ${note.noteName}');
            print(
                '   Required: ${note.requiredPistons} (${note.requiredPistons.length} pistons)');
            print(
                '   Used: $pistonCombination (${pistonCombination.length} pistons)');

            final requiredSet = note.requiredPistons.toSet();
            final missing = requiredSet.difference(pistonCombination);
            final extra = pistonCombination.difference(requiredSet);

            if (missing.isNotEmpty) {
              print('   Missing: $missing');
            }
            if (extra.isNotEmpty) {
              print('   Extra: $extra');
            }
          }
        }
      }
    }

    // Solo marcar como error si había una nota en zona de hit Y no se acertó
    if (isInHitZone && !hitCorrectNote && _playerIsOnTrack) {
      print('❌ MISS! Used combination: $pistonCombination - Player off track');

      // NUEVO: Notificar al controlador que el jugador falló
      if (_isAudioContinuous) {
        _audioController.onPlayerMiss();
        _playerIsOnTrack = false;
        print('🔊 Player off track');
      }

      // NUEVO: Mostrar feedback "Erronea"
      _showFeedback('Erronea', Colors.red);

      _onNoteMissed();
    } else if (!isInHitZone) {
      print('⚪ No note in hit zone for combination: $pistonCombination');
    }
  }

  // MEJORADO: Función auxiliar para verificar coincidencia exacta de pistones
  bool _exactPistonMatch(FallingNote note, Set<int> pressedPistons) {
    final required = note.requiredPistons.toSet();

    // Para notas de aire (sin pistones)
    if (required.isEmpty) {
      return pressedPistons.isEmpty;
    }

    print('🔍 Checking exact match:');
    print('   Required: $required (${required.length} pistons)');
    print('   Pressed: $pressedPistons (${pressedPistons.length} pistons)');

    // CORREGIDO: Verificar coincidencia EXACTA sin tolerancia para evitar errores
    // Si requiere pistones 1 y 3, SOLO acepta 1 y 3, NO acepta 1, 2 y 3
    final match = required.length == pressedPistons.length &&
        required.every((piston) => pressedPistons.contains(piston));

    print('   Match result: ${match ? "✅ EXACT MATCH" : "❌ NO MATCH"}');
    return match;
  }

  // ELIMINADO: Lógica antigua con tolerancia que causaba problemas
  // ignore: unused_element
  bool _exactPistonMatch_OLD(FallingNote note, Set<int> pressedPistons) {
    final required = note.requiredPistons.toSet();

    if (required.isEmpty) {
      return pressedPistons.isEmpty;
    }

    // Para combinaciones de múltiples pistones - tolerancia antigua (ELIMINADA)
    if (required.length > 1) {
      // Verificar que TODOS los pistones requeridos estén presionados
      final hasAllRequired =
          required.every((piston) => pressedPistons.contains(piston));

      if (hasAllRequired) {
        print('✅ All required pistons are pressed');

        // NUEVO: Para combinaciones de 3 pistones, ser más permisivo
        if (required.length == 3 && pressedPistons.length >= 3) {
          // Si tenemos al menos los 3 pistones requeridos, aceptar
          print('🎯 3-piston combination detected - accepting match');
          return true;
        }

        // Para 2 pistones o casos generales, verificar pistones extra
        final extraPistons = pressedPistons.difference(required);
        if (extraPistons.isNotEmpty) {
          // MEJORADO: Ser más tolerante con pistones extra en combinaciones complejas
          if (required.length >= 2) {
            print(
                '⚠️ Extra pistons in multi-piston combination, but accepting');
            return true;
          }

          // Verificar tiempo solo para combinaciones simples
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          bool allExtraAreRecent = true;

          for (var piston in extraPistons) {
            final pressTime = _pistonPressTime[piston];
            if (pressTime == null ||
                (currentTime - pressTime) > _multiPistonTimeWindow) {
              allExtraAreRecent = false;
              break;
            }
          }

          if (allExtraAreRecent) {
            print('⚠️ Extra pistons detected but recent, accepting match');
            return true;
          } else {
            print('❌ Extra pistons are too old, rejecting match');
            return false;
          }
        }

        return true;
      } else {
        final missing = required.difference(pressedPistons);
        print('❌ Missing required pistons: $missing');
        return false;
      }
    }

    // Para notas que requieren un solo pistón - coincidencia exacta
    return required.length == pressedPistons.length &&
        required.every((piston) => pressedPistons.contains(piston));
  }

  // MEJORADO: Mejor detección de combinaciones de pistones para reproducir sonido
  void _playNoteFromPistonCombination() {
    print('🎹 Playing note for combination: $pressedPistons');

    // Si no hay pistones presionados, reproducir nota de aire
    if (pressedPistons.isEmpty) {
      print('�️ No pistons pressed - playing open note');
      _playOpenNote();
      return;
    }

    SongNote? noteToPlay;

    // 1. Buscar en notas cayendo que coincidan EXACTAMENTE
    for (var fallingNote in fallingNotes) {
      if (!fallingNote.isHit &&
          !fallingNote.isMissed &&
          fallingNote.songNote != null &&
          _exactPistonMatchForSong(fallingNote.songNote, pressedPistons)) {
        noteToPlay = fallingNote.songNote!;
        print('� Found exact match in falling notes: ${noteToPlay.noteName}');
        break;
      }
    }

    // 2. Si no hay en notas cayendo, buscar en todas las notas
    if (noteToPlay == null && songNotes.isNotEmpty) {
      for (var songNote in songNotes) {
        if (_exactPistonMatchForSong(songNote, pressedPistons)) {
          noteToPlay = songNote;
          print('🎵 Found exact match in database: ${noteToPlay.noteName}');
          break;
        }
      }
    }

    // 3. Si no se encuentra coincidencia exacta, buscar la más cercana
    if (noteToPlay == null && songNotes.isNotEmpty) {
      print('⚠️ No exact match found, looking for closest match...');
      SongNote? closestMatch;
      int bestScore = -1;

      for (var songNote in songNotes) {
        final required = songNote.pistonCombination.toSet();
        final pressed = pressedPistons;

        // Calcular puntuación de similitud
        final commonPistons = required.intersection(pressed).length;
        final totalUnique = required.union(pressed).length;
        final score =
            totalUnique > 0 ? (commonPistons * 100) ~/ totalUnique : 0;

        if (score > bestScore &&
            songNote.noteUrl != null &&
            songNote.noteUrl!.isNotEmpty) {
          bestScore = score;
          closestMatch = songNote;
        }
      }

      if (closestMatch != null && bestScore > 30) {
        // Al menos 30% de similitud
        noteToPlay = closestMatch;
        print('🎯 Using closest match (${bestScore}%): ${noteToPlay.noteName}');
      }
    }

    // 4. Reproducir la nota encontrada
    if (noteToPlay != null &&
        noteToPlay.noteUrl != null &&
        noteToPlay.noteUrl!.isNotEmpty) {
      print(
          '▶️ Playing note: ${noteToPlay.noteName} (pistons: ${noteToPlay.pistonCombination})');
      _playFromRobustCache(noteToPlay);
    } else {
      print('❌ No playable note found for combination: $pressedPistons');
      if (songNotes.isNotEmpty) {
        print('🔍 Available notes:');
        for (var note in songNotes.take(5)) {
          print(
              '   ${note.noteName}: ${note.pistonCombination} (URL: ${note.noteUrl != null ? "✅" : "❌"})');
        }
      }
    }
  }

  // NUEVO: Función auxiliar para verificar coincidencia exacta con SongNote
  bool _exactPistonMatchForSong(SongNote? songNote, Set<int> pressedPistons) {
    if (songNote == null) return false;

    final required = songNote.pistonCombination.toSet();

    // Para notas de aire (sin pistones)
    if (required.isEmpty) {
      return pressedPistons.isEmpty;
    }

    // Para notas que requieren pistones específicos - coincidencia exacta
    return required.length == pressedPistons.length &&
        required.every((piston) => pressedPistons.contains(piston));
  }

  // MEJORADO: Reproducir nota de aire (sin pistones) con mejor fallback
  void _playOpenNote() {
    print('🌬️ Looking for open note (no pistons)...');
    SongNote? openNote;

    // Buscar nota sin pistones requeridos
    for (var note in songNotes) {
      if (note.pistonCombination.isEmpty &&
          note.noteUrl != null &&
          note.noteUrl!.isNotEmpty) {
        openNote = note;
        print('✅ Found open note: ${openNote.noteName}');
        break;
      }
    }

    // Si no se encuentra nota de aire, usar la primera nota disponible
    if (openNote == null && songNotes.isNotEmpty) {
      for (var note in songNotes) {
        if (note.noteUrl != null && note.noteUrl!.isNotEmpty) {
          openNote = note;
          print(
              '� Using fallback note: ${openNote.noteName} (pistons: ${openNote.pistonCombination})');
          break;
        }
      }
    }

    if (openNote != null) {
      _playFromRobustCache(openNote);
    } else {
      print('❌ No playable open note found');
    }
  }

  // ELIMINADO: Ya no es necesario - el nuevo sistema tiene mejor debugging

  // MEJORADO: Reproducir audio desde cache robusto con mejor fallback
  Future<void> _playFromRobustCache(SongNote note) async {
    print('🎵 Attempting to play: ${note.noteName}');

    // Verificar que la nota tenga URL
    if (note.noteUrl == null || note.noteUrl!.isEmpty) {
      print('❌ No audio URL for note: ${note.noteName}');
      return;
    }

    print('🔗 Audio URL: ${note.noteUrl}');
    final cacheKey = 'audio_${note.noteUrl.hashCode}';

    try {
      // Intentar reproducir desde cache robusto primero
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final cachedData = box.get(cacheKey, defaultValue: null);

      if (cachedData != null &&
          cachedData['path'] != null &&
          File(cachedData['path']).existsSync()) {
        // Reproducir desde archivo local cached
        final localFile = File(cachedData['path']);
        await NoteAudioService.playNoteFromUrl(
          localFile.uri.toString(),
          noteId: note.chromaticId?.toString(),
          durationMs: note.durationMs,
        );
        print('✅ Audio played from cache: ${note.noteName}');
      } else {
        // Fallback: descargar y reproducir directamente
        print('⬇️ Cache miss, playing from URL: ${note.noteName}');
        await NoteAudioService.playNoteFromUrl(
          note.noteUrl!,
          noteId: note.chromaticId?.toString(),
          durationMs: note.durationMs,
        );
        print('✅ Audio played from URL: ${note.noteName}');
      }
    } catch (e) {
      print('❌ Error playing audio for ${note.noteName}: $e');

      // Último fallback: intentar una vez más con la URL original
      try {
        await NoteAudioService.playNoteFromUrl(
          note.noteUrl!,
          noteId: note.chromaticId?.toString(),
          durationMs: note.durationMs,
        );
        print('✅ Final fallback successful for: ${note.noteName}');
      } catch (finalError) {
        print('💥 Complete audio failure for ${note.noteName}: $finalError');
      }
    }
  }

  // Cuando se acierta una nota con calidad de timing
  void _onNoteHit([String? noteName, double timingQuality = 0.5]) {
    setState(() {
      totalNotes++;
      correctNotes++;
      currentScore += 10;
      experiencePoints += experiencePerCorrectNote;
    });

    // NUEVO: Mostrar feedback basado en la precisión del timing
    // timingQuality: 0.0 = centro perfecto, 1.0 = borde de tolerancia
    if (timingQuality <= 0.3) {
      _showFeedback('Perfecto', Colors.green);
      HapticFeedback.mediumImpact();
    } else if (timingQuality <= 0.7) {
      _showFeedback('Bien', Colors.blue);
      HapticFeedback.lightImpact();
    } else {
      _showFeedback('Bien', Colors.orange);
      HapticFeedback.lightImpact();
    }
  }

  // Cuando se falla una nota
  void _onNoteMissed() {
    setState(() {
      totalNotes++;
      // No incrementar correctNotes
      currentScore = (currentScore - 5).clamp(0, double.infinity).toInt();
    });

    HapticFeedback.heavyImpact();
  }

  // NUEVO: Método para mostrar feedback visual temporal
  void _showFeedback(String text, Color color) {
    feedbackTimer?.cancel();

    setState(() {
      feedbackText = text;
      feedbackColor = color;
      feedbackOpacity = 1.0;
    });

    // Ocultar después de 0.8 segundos
    feedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          feedbackOpacity = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: showLogo
          ? _buildLogoScreen()
          : showCountdown
              ? _buildCountdownScreen()
              : _buildGameScreen(),
    );
  }

  Widget _buildLogoScreen() {
    // Obtener dimensiones de la pantalla para diseño responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // Detectar pantallas pequeñas

    // Calcular tamaños responsive
    final logoSize = isSmallScreen ? 120.0 : 200.0;
    final titleFontSize = isSmallScreen ? 24.0 : 32.0;
    final subtitleFontSize = isSmallScreen ? 14.0 : 18.0;
    final progressBarWidth =
        (screenWidth - 40).clamp(200.0, 300.0); // Con padding de 20 a cada lado

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A8A), // Azul oscuro
            Color(0xFF3B82F6), // Azul medio
            Color(0xFF60A5FA), // Azul claro
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spacer flexible para centrar mejor en pantallas pequeñas
              const Spacer(flex: 1),

              // Logo responsive
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 15 : 20,
                      offset: Offset(0, isSmallScreen ? 5 : 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
                  child: Image.asset(
                    'assets/images/icono.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(isSmallScreen ? 15 : 20),
                        ),
                        child: Icon(
                          Icons.music_note,
                          size: logoSize * 0.5, // 50% del tamaño del logo
                          color: Colors.blue,
                        ),
                      );
                    },
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 30),

              // Título responsive
              Text(
                'REFMP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isSmallScreen ? 2 : 3,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 5 : 10),

              // Subtítulo responsive
              Text(
                'Nivel Principiante',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: subtitleFontSize,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),

              // Spacer flexible
              const Spacer(flex: 1),

              // Indicador de carga de audio (parte inferior)
              if (isLoadingSong || isPreloadingAudio) ...[
                // Barra de progreso responsive
                Container(
                  width: progressBarWidth,
                  height: isSmallScreen ? 6 : 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 3 : 4),
                  ),
                  child: Stack(
                    children: [
                      // Progreso de descarga de audio
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isPreloadingAudio
                            ? (progressBarWidth * (audioCacheProgress / 100))
                            : (isLoadingSong ? progressBarWidth : 0),
                        height: isSmallScreen ? 6 : 8,
                        decoration: BoxDecoration(
                          color: isPreloadingAudio
                              ? Colors.blue
                              : Colors.white.withOpacity(0.8),
                          borderRadius:
                              BorderRadius.circular(isSmallScreen ? 3 : 4),
                          boxShadow: [
                            BoxShadow(
                              color: (isPreloadingAudio
                                      ? Colors.blue
                                      : Colors.white)
                                  .withOpacity(0.5),
                              blurRadius: isSmallScreen ? 6 : 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 10 : 15),

                // Texto de estado compacto
                Text(
                  isLoadingSong
                      ? 'Cargando canción...'
                      : isPreloadingAudio
                          ? 'Cache offline ${audioCacheProgress}%'
                          : _audioCacheCompleted
                              ? '¡Música lista offline!'
                              : 'Preparando...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Información adicional solo si hay espacio
                if (isPreloadingAudio && !isSmallScreen) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Guardando para reproducción offline',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],

              // Spacer final para mantener el contenido centrado
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E3A8A), // Azul oscuro
            Color(0xFF3B82F6), // Azul medio
            Color(0xFF60A5FA), // Azul claro
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Prepárate...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 40),
            // Número de cuenta regresiva
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Text(
                countdownNumber > 0 ? '$countdownNumber' : '¡Comienza!',
                key: ValueKey<String>(
                    countdownNumber > 0 ? '$countdownNumber' : 'start'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.blue.withOpacity(0.8),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
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

  Widget _buildGameScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A), // Muy oscuro
            Color(0xFF1E293B), // Oscuro
            Color(0xFF334155), // Medio oscuro
          ],
        ),
      ),
      child: Stack(
        children: [
          // Área principal del juego (ocupa toda la pantalla)
          Positioned(
            top: 0, // Desde el inicio de la pantalla
            left: 0,
            right: 0,
            bottom: 0, // Hasta el final de la pantalla
            child: _buildGameArea(),
          ),

          // Header con botón de regreso flotante (encima del área de juego)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildHeader(),
          ),

          // Contenedor de nota musical en el lado izquierdo
          Positioned(
            top: 100, // Debajo del header
            left: 30, // Al lado izquierdo
            child: _buildMusicalNoteDisplay(),
          ),

          // Barra de progreso vertical (al lado derecho cerca de la cámara)
          Positioned(
            top: 100, // Debajo del header
            right: 30, // Al lado derecho, cerca de la cámara del dispositivo
            child: _buildVerticalProgressBar(),
          ),

          // Controles de pistones en la parte inferior centrados (responsive)
          Positioned(
            bottom: () {
              final screenHeight = MediaQuery.of(context).size.height;
              final screenWidth = MediaQuery.of(context).size.width;
              final isTablet = screenWidth > 600;
              final isSmallPhone = screenHeight < 700;

              if (isSmallPhone) {
                return 15.0; // Más cerca del borde en celulares pequeños
              } else if (isTablet) {
                return 30.0; // Más espacio en tablets
              } else {
                return 20.0; // Posición estándar
              }
            }(),
            left: 0,
            right: 0,
            child: Center(
              child: _buildPistonControls(),
            ),
          ),

          // NUEVO: Feedback overlay (Perfecto, Bien, Erronea) - DEBAJO DEL NOMBRE DE LA CANCIÓN
          if (feedbackText != null)
            Positioned(
              top: 70, // Debajo del header/nombre de la canción
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: feedbackOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      // Fondo muy transparente solo para "Bien", más visible para otros
                      color: feedbackText == 'Bien'
                          ? Colors.transparent
                          : feedbackColor?.withOpacity(0.3) ?? Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: feedbackText == 'Bien'
                          ? null
                          : Border.all(
                              color: feedbackColor?.withOpacity(0.5) ??
                                  Colors.white54,
                              width: 1,
                            ),
                    ),
                    child: Text(
                      feedbackText!,
                      style: TextStyle(
                        fontSize: 24, // Más pequeño
                        fontWeight: FontWeight.bold,
                        color: feedbackColor ?? Colors.white,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Método helper para construir la imagen de perfil con soporte para archivos locales y URLs
  Widget _buildProfileImage(String imageUrl) {
    // Verificar si es un archivo local
    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      final file = File(
          imageUrl.startsWith('file://') ? imageUrl.substring(7) : imageUrl);

      if (file.existsSync()) {
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(27), // Asegurar que esté recortado
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 54, // Dimensiones fijas para evitar desbordamiento
            height: 54,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.person,
                color: Colors.white,
                size: 35,
              );
            },
          ),
        );
      } else {
        return const Icon(
          Icons.person,
          color: Colors.white,
          size: 35,
        );
      }
    }
    // Es una URL de red
    else if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(27), // Asegurar que esté recortado
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: 54, // Dimensiones fijas para evitar desbordamiento
          height: 54,
          placeholder: (context, url) => const Icon(
            Icons.person,
            color: Colors.white,
            size: 35,
          ),
          errorWidget: (context, url, error) {
            return const Icon(
              Icons.person,
              color: Colors.white,
              size: 35,
            );
          },
        ),
      );
    }
    // Fallback para otros casos
    else {
      return const Icon(
        Icons.person,
        color: Colors.white,
        size: 35,
      );
    }
  }

  // Método para construir el contenedor de nota musical en el lado izquierdo
  Widget _buildMusicalNoteDisplay() {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título
            const Text(
              'Nota Tocada',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Contenedor de la nota
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: lastPlayedNote != null
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                    color: lastPlayedNote != null
                        ? Colors.blue
                        : Colors.grey.withOpacity(0.5),
                    width: 2),
                boxShadow: lastPlayedNote != null
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  lastPlayedNote ?? '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize:
                        lastPlayedNote != null && lastPlayedNote!.length > 2
                            ? 14
                            : 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Indicador de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: lastPlayedNote != null
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                lastPlayedNote != null ? 'Acierto' : 'Esperando...',
                style: TextStyle(
                  color: lastPlayedNote != null ? Colors.green : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para construir la barra de progreso vertical del rendimiento
  Widget _buildVerticalProgressBar() {
    return Container(
      width: 40,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            // Indicador de rendimiento
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.red.withOpacity(0.8),
                      Colors.orange.withOpacity(0.6),
                      Colors.yellow.withOpacity(0.4),
                      Colors.green.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Fondo de la barra
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    // Progreso actual
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 180 *
                            accuracy, // Altura basada en la precisión (máximo 180 en lugar de 190)
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              // Color dinámico basado en rendimiento
                              if (accuracy >= 0.8) ...[
                                Colors.green,
                                Colors.green.shade400,
                              ] else if (accuracy >= 0.6) ...[
                                Colors.yellow.shade600,
                                Colors.yellow.shade400,
                              ] else if (accuracy >= 0.4) ...[
                                Colors.orange.shade600,
                                Colors.orange.shade400,
                              ] else ...[
                                Colors.red.shade600,
                                Colors.red.shade400,
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Marcadores de nivel
                    ...List.generate(5, (index) {
                      double position = (index + 1) * 0.2;
                      return Positioned(
                        bottom: 180 * position - 1, // Cambiado de 190 a 180
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Porcentaje de precisión
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${(accuracy * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Icono de estado
            Icon(
              accuracy >= 0.8
                  ? Icons.star
                  : accuracy >= 0.6
                      ? Icons.thumb_up
                      : accuracy >= 0.4
                          ? Icons.warning
                          : Icons.error,
              color: accuracy >= 0.8
                  ? Colors.green
                  : accuracy >= 0.6
                      ? Colors.yellow
                      : accuracy >= 0.4
                          ? Colors.orange
                          : Colors.red,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Botón de regreso con arrow iOS redondeado
        Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => showBackDialog(
              context,
              widget.songName,
              onCancel: () {
                // Si el juego está pausado, reanudarlo
                if (isGamePaused) {
                  _resumeGame();
                }
              },
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 24,
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),

        const SizedBox(width: 15),

        // Botón de pausa
        Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => _pauseGame(),
            icon: const Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 24,
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),

        const SizedBox(width: 15),

        // Botón de debug para alternar audio continuo/individual
        Container(
          decoration: BoxDecoration(
            color: _isAudioContinuous ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: (_isAudioContinuous ? Colors.green : Colors.orange)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _isAudioContinuous = !_isAudioContinuous;
              });
              if (_isAudioContinuous) {
                print('🎵 Audio continuo activado');
                // Si hay una canción cargada, iniciar tracking
                if (widget.songId != null && isGameActive) {
                  _audioController.loadSong(widget.songId!).then((_) {
                    _audioController.startTracking();
                  });
                }
              } else {
                print('🎼 Audio individual activado');
                _audioController.stop();
              }
            },
            icon: Icon(
              _isAudioContinuous ? Icons.library_music : Icons.music_note,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),

        const SizedBox(width: 15),

        // Imagen de perfil (circular y transparente) - VERSION SIMPLE
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: widget.profileImageUrl != null &&
                    widget.profileImageUrl!.isNotEmpty
                ? _buildProfileImage(widget.profileImageUrl!)
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
          ),
        ),

        const SizedBox(width: 15),

        // Imagen de la canción (circular con rotación) - VERSION SIMPLE
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2.0 * 3.141592653589793,
                  child: Stack(
                    children: [
                      // Imagen de fondo de la canción o color sólido
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: widget.songImageUrl != null &&
                                widget.songImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.songImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.blue,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.blue,
                                ),
                              )
                            : Container(
                                color: Colors.blue,
                              ),
                      ),
                      // Nota musical blanca en el centro
                      Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.blue,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 15),

        // Título de la canción
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Text(
              widget.songName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        const SizedBox(width: 15),

        // Monedas del jugador
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Imagen de la moneda
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/coin.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.monetization_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Cantidad de monedas por nota correcta en este nivel
              Text(
                totalCoins.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Puntos de experiencia
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de experiencia
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Cantidad de puntos de experiencia
              Text(
                '$experiencePoints',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          // Líneas guía para los pistones
          _buildPistonGuides(),

          // Zona de hit (donde deben presionarse las notas)
          _buildHitZone(),

          // Notas que caen
          ..._buildFallingNotes(),

          // Mensaje cuando no hay notas disponibles
          if (songNotes.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                  border:
                      Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note,
                      color: Colors.blue,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay notas para esta canción',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Puedes practicar presionando los pistones\npara escuchar diferentes notas',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Efectos de feedback
          _buildFeedbackEffects(),
        ],
      ),
    );
  }

  // Construir las líneas guía para cada pistón
  Widget _buildPistonGuides() {
    return Positioned.fill(
      child: CustomPaint(
        painter: PistonGuidesPainter(),
      ),
    );
  }

  // Construir la zona de hit (responsive, justo debajo de los pistones)
  Widget _buildHitZone() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Detectar si es tablet o celular para ajustar tamaño
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Tamaño responsive de la zona de hit
    double hitZoneHeight;

    if (isSmallPhone) {
      hitZoneHeight = 100; // Zona más compacta para celulares pequeños
    } else if (isTablet) {
      hitZoneHeight = 140; // Zona más grande para tablets
    } else {
      hitZoneHeight = 120; // Tamaño estándar para celulares normales
    }

    // Calcular posición un poco más abajo del centro de la pantalla
    final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2) + 80;

    return Positioned(
      top: hitZoneY, // Ahora se posiciona desde arriba, en el centro
      left: 0,
      right: 0,
      child: Container(
        height: hitZoneHeight,
        decoration: BoxDecoration(
          // Hacer la zona visible para que los jugadores sepan dónde tocar
          color: Colors.white.withOpacity(0.05), // Muy sutil pero visible
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'ZONA DE HIT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: isSmallPhone ? 12 : 14,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }

  // Construir las notas que caen
  List<Widget> _buildFallingNotes() {
    return fallingNotes.map((note) {
      if (note.isHit || note.isMissed) return const SizedBox.shrink();

      // Calcular posición y tamaño basado en los pistones requeridos
      return _buildRectangularNote(note);
    }).toList();
  }

  // Construir una nota rectangular que abarca los pistones requeridos
  Widget _buildRectangularNote(FallingNote note) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Configuración de pistones
    const double pistonSize = 70.0;
    const double realPistonSeparation = 16.0;
    const double realPistonDiameter = 18.0;
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    // Ancho total del contenedor de pistones
    final double totalPistonWidth =
        (pistonSize * 3) + (pixelSeparation * 2) + 40;
    final double startX = (screenWidth - totalPistonWidth) / 2 + 20;

    // Obtener pistones requeridos
    final requiredPistons = note.requiredPistons;

    // Si es nota libre (aire), crear barra que abarca todos los pistones
    if (note.isOpenNote) {
      return Positioned(
        left: startX,
        top: note.y,
        child: _buildOpenNote(note, totalPistonWidth - 40),
      );
    }

    // Para notas con pistones específicos
    if (requiredPistons.isEmpty) {
      // Nota sin pistones requeridos - centrar en el medio
      return Positioned(
        left: startX + pistonSize + pixelSeparation + 15,
        top: note.y,
        child: _buildNote(note),
      );
    }

    // NUEVO: Verificar si los pistones son consecutivos o separados
    final sortedPistons = requiredPistons.toList()..sort();
    final areConsecutive = _arePistonsConsecutive(sortedPistons);

    // Si son pistones SEPARADOS (ej: 1 y 3), crear notas individuales
    if (!areConsecutive && requiredPistons.length > 1) {
      return Stack(
        children: requiredPistons.map((piston) {
          final pistonX =
              _getPistonCenterX(piston, startX, pistonSize, pixelSeparation);
          return Positioned(
            left: pistonX - 30,
            top: note.y,
            child: _buildSinglePistonNote(note, 60),
          );
        }).toList(),
      );
    }

    // Si son CONSECUTIVOS (ej: 1 y 2, o 2 y 3), crear barra que los une
    final minPiston = sortedPistons.first;
    final maxPiston = sortedPistons.last;

    // Calcular posición inicial y ancho del rectángulo
    double rectStartX =
        _getPistonCenterX(minPiston, startX, pistonSize, pixelSeparation) - 35;
    double rectEndX =
        _getPistonCenterX(maxPiston, startX, pistonSize, pixelSeparation) + 35;
    double rectWidth = rectEndX - rectStartX;

    return Positioned(
      left: rectStartX,
      top: note.y,
      child: _buildRectangularNoteWidget(note, rectWidth),
    );
  }

  // NUEVO: Verificar si los pistones son consecutivos
  bool _arePistonsConsecutive(List<int> sortedPistons) {
    if (sortedPistons.length <= 1) return true;

    for (int i = 0; i < sortedPistons.length - 1; i++) {
      if (sortedPistons[i + 1] - sortedPistons[i] != 1) {
        return false; // Hay un salto, no son consecutivos
      }
    }
    return true; // Todos son consecutivos
  }

  // Obtener la posición X del centro de un pistón
  double _getPistonCenterX(int pistonNumber, double startX, double pistonSize,
      double pixelSeparation) {
    switch (pistonNumber) {
      case 1:
        return startX + (pistonSize / 2);
      case 2:
        return startX + pistonSize + pixelSeparation + (pistonSize / 2);
      case 3:
        return startX +
            (pistonSize * 2) +
            (pixelSeparation * 2) +
            (pistonSize / 2);
      default:
        return startX + (pistonSize / 2);
    }
  }

  // Construir widget de nota rectangular
  Widget _buildRectangularNoteWidget(FallingNote note, double width) {
    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        color: note.noteColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: note.noteColor.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          note.displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: note.displayText.length > 8 ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // NUEVO: Construir nota individual para pistón (cuando son separados)
  Widget _buildSinglePistonNote(FallingNote note, double width) {
    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        color: note.noteColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: note.noteColor.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          note.displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: note.displayText.length > 8 ? 10 : 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Construir nota libre (aire) - barra gris que abarca todos los pistones
  Widget _buildOpenNote(FallingNote note, double width) {
    return Container(
      width: width,
      height: 40, // Más delgada para notas libres
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: Center(
        child: Text(
          note.displayText,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Construir una nota individual (para compatibilidad)
  Widget _buildNote(FallingNote note) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: note.noteColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: note.noteColor.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mostrar la nota musical
            Text(
              note.displayText,
              style: TextStyle(
                color: Colors.white,
                fontSize: note.displayText.length > 8 ? 10 : 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            // Si hay pistones requeridos, mostrar indicador
            if (note.requiredPistons.isNotEmpty && !note.isOpenNote)
              Text(
                note.requiredPistons.join(','),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Efectos de feedback visual
  Widget _buildFeedbackEffects() {
    return const SizedBox.shrink(); // Por ahora vacío, se puede agregar después
  }

  Widget _buildPistonControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Tamaños responsive para los pistones
    final double pistonSize;
    final double realPistonSeparation;

    if (isSmallPhone) {
      pistonSize = 60.0; // Más pequeños en celulares pequeños
      realPistonSeparation = 12.0;
    } else if (isTablet) {
      pistonSize = 85.0; // Más grandes en tablets
      realPistonSeparation = 20.0;
    } else {
      pistonSize = 70.0; // Tamaño estándar
      realPistonSeparation = 16.0;
    }

    const double realPistonDiameter = 18.0; // mm en trompeta real

    // Calcular la separación proporcional en pixels
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallPhone ? 15 : 20, vertical: isSmallPhone ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pistón 1
          _buildPistonButton(1, pistonSize),

          SizedBox(width: pixelSeparation),

          // Pistón 2
          _buildPistonButton(2, pistonSize),

          SizedBox(width: pixelSeparation),

          // Pistón 3
          _buildPistonButton(3, pistonSize),
        ],
      ),
    );
  }

  Widget _buildPistonButton(int pistonNumber, double pistonSize) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallPhone = screenHeight < 700;

    // Verificar si este pistón debe mostrar sombra
    final hasShadow = pistonShadows.containsKey(pistonNumber);
    final shadowColor = pistonShadows[pistonNumber];

    // Tamaño de fuente responsive
    final double fontSize = isSmallPhone ? 20.0 : 24.0;

    return GestureDetector(
      onTapDown: (_) => _onPistonPressed(pistonNumber),
      onTapUp: (_) => _onPistonReleased(pistonNumber),
      onTapCancel: () => _onPistonReleased(pistonNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: pistonSize,
        height: pistonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(pistonSize / 2),
          // Agregar borde cuando hay sombra
          border: hasShadow
              ? Border.all(
                  color: Colors.blue.shade300,
                  width: 4,
                )
              : null,
          boxShadow: [
            // Sombra normal
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
            // Sombra adicional cuando debe presionarse
            if (hasShadow)
              BoxShadow(
                color: Colors.blue.withOpacity(0.8),
                blurRadius: 25,
                spreadRadius: 5,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Imagen del pistón
            ClipRRect(
              borderRadius: BorderRadius.circular(pistonSize / 2),
              child: Image.asset(
                'assets/images/piston.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(pistonSize / 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF1E40AF),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        pistonNumber.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Overlay de color cuando hay sombra
            if (hasShadow)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pistonSize / 2),
                  color: (shadowColor ?? Colors.blue).withOpacity(0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Timer para manejar combinaciones de pistones
  Timer? _pistonCombinationTimer;

  // NUEVO: Mapa para rastrear el tiempo de presión de cada pistón
  final Map<int, int> _pistonPressTime = {};

  // NUEVO: Configuración para combinaciones múltiples - AUMENTADO para mejor detección
  static const int _multiPistonTimeWindow =
      500; // 500ms para completar combinación (más tiempo)
  static const int _audioDelayMs =
      100; // 100ms delay para audio (más tiempo para capturar)

  void _onPistonPressed(int pistonNumber) {
    // Feedback háptico
    HapticFeedback.lightImpact();

    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Registrar tiempo de presión del pistón
    _pistonPressTime[pistonNumber] = currentTime;

    // Agregar pistón al conjunto de pistones presionados
    pressedPistons.add(pistonNumber);

    print(
        '🎹 Piston $pistonNumber pressed at ${currentTime}. Current combination: $pressedPistons');

    // Cancelar timer anterior si existe
    _pistonCombinationTimer?.cancel();

    // MEJORADO: Determinar si necesitamos esperar más pistones
    bool needsMorePistons = false;
    int maxRequiredPistons = 1;

    // Verificar si hay notas en zona de hit que requieran más pistones
    if (isGameActive) {
      for (var note in fallingNotes) {
        if (!note.isHit && !note.isMissed) {
          final screenHeight = MediaQuery.of(context).size.height;
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final isSmallPhone = screenHeight < 700;

          // Calcular zona de hit un poco más abajo del centro de la pantalla
          final hitZoneHeight =
              isSmallPhone ? 100.0 : (isTablet ? 140.0 : 120.0);
          final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2) + 80;
          final hitZoneCenterY = hitZoneY + (hitZoneHeight / 2);

          final noteCenter = note.y + 30;
          final distance = (noteCenter - hitZoneCenterY).abs();

          // Si hay una nota en zona de hit
          if (distance <= hitZoneHeight / 2) {
            final requiredCount = note.requiredPistons.length;
            maxRequiredPistons = maxRequiredPistons > requiredCount
                ? maxRequiredPistons
                : requiredCount;

            if (requiredCount > pressedPistons.length) {
              needsMorePistons = true;
              print(
                  '🎯 Found note requiring ${requiredCount} pistons, current: ${pressedPistons.length}');
            }
          }
        }
      }
    }

    // MEJORADO: Calcular delay más inteligente basado en el número de pistones requeridos
    int delay;
    if (needsMorePistons && pressedPistons.length < maxRequiredPistons) {
      // Para combinaciones de 3 pistones, esperar más tiempo
      if (maxRequiredPistons >= 3) {
        delay = _multiPistonTimeWindow; // 500ms para 3 pistones
        print(
            '⏳ Waiting for 3-piston combination (${pressedPistons.length}/3)...');
      } else if (maxRequiredPistons == 2) {
        delay = _multiPistonTimeWindow ~/ 2; // 250ms para 2 pistones
        print(
            '⏳ Waiting for 2-piston combination (${pressedPistons.length}/2)...');
      } else {
        delay = _audioDelayMs;
      }
    } else {
      // Si ya tenemos suficientes pistones o no necesitamos más, procesar rápidamente
      delay = _audioDelayMs;
    }

    print(
        '🕒 Timer delay set to ${delay}ms for ${pressedPistons.length} pistones (max needed: $maxRequiredPistons)');

    // Crear timer con delay apropiado
    _pistonCombinationTimer = Timer(Duration(milliseconds: delay), () {
      // Limpiar pistones que fueron presionados hace mucho tiempo
      _cleanupOldPistonPresses();

      // MEJORADO: Capturar la combinación actual antes de reproducir
      final currentCombination = Set<int>.from(pressedPistons);

      print(
          '⚡ Processing combination: $currentCombination after ${delay}ms delay');

      // Reproducir sonido para la combinación actual
      _playNoteFromPistonCombination();

      // MEJORADO: Verificar hit inmediatamente con la combinación capturada
      if (isGameActive) {
        _checkNoteHitWithCombination(currentCombination);
      }
    });

    debugPrint(
        'Pistón $pistonNumber presionado - Combination: $pressedPistons (delay: ${delay}ms)');
  }

  // MEJORADO: Limpiar pistones presionados hace mucho tiempo - más conservador
  void _cleanupOldPistonPresses() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final pistonsToRemove = <int>[];

    // NUEVO: Usar ventana más amplia para la limpieza en combinaciones complejas
    final cleanupWindow = pressedPistons.length >= 2
        ? _multiPistonTimeWindow *
            2 // Doble tiempo para combinaciones múltiples
        : _multiPistonTimeWindow; // Tiempo normal para pistones simples

    for (var entry in _pistonPressTime.entries) {
      if (currentTime - entry.value > cleanupWindow) {
        pistonsToRemove.add(entry.key);
      }
    }

    for (var piston in pistonsToRemove) {
      _pistonPressTime.remove(piston);
      pressedPistons.remove(piston);
    }

    if (pistonsToRemove.isNotEmpty) {
      print(
          '🧹 Cleaned up old piston presses: $pistonsToRemove (window: ${cleanupWindow}ms)');
    }
  }

  void _onPistonReleased(int pistonNumber) {
    // Remover pistón del conjunto de pistones presionados
    pressedPistons.remove(pistonNumber);
    _pistonPressTime.remove(pistonNumber);

    print(
        '🎹 Piston $pistonNumber released. Current combination: $pressedPistons');

    // MEJORADO: No cancelar inmediatamente si hay otros pistones presionados
    // Esto permite mantener combinaciones activas

    // Si no hay pistones presionados, cancelar timer
    if (pressedPistons.isEmpty) {
      _pistonCombinationTimer?.cancel();
      print('🔇 All pistons released - stopping audio');
    } else {
      // Si aún hay pistones presionados, verificar si necesitamos actuar
      print('🎹 Pistons still pressed: $pressedPistons');

      // Solo crear nuevo timer si no hay uno activo
      if (_pistonCombinationTimer == null ||
          !_pistonCombinationTimer!.isActive) {
        _pistonCombinationTimer = Timer(const Duration(milliseconds: 100), () {
          _playNoteFromPistonCombination();
        });
      }
    }

    debugPrint('Pistón $pistonNumber liberado - Remaining: $pressedPistons');
  }

  // NUEVO: Método helper para limpiar cache offline antiguo
  static Future<void> cleanOldOfflineCache() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAge =
          const Duration(days: 7).inMilliseconds; // Cache válido por 7 días

      final keysToDelete = <String>[];

      // Revisar todas las claves del cache
      for (var key in box.keys) {
        if (key.toString().startsWith('song_') &&
            key.toString().endsWith('_complete')) {
          final data = box.get(key);
          if (data != null && data['cached_timestamp'] != null) {
            final cacheAge = now - (data['cached_timestamp'] as int);
            if (cacheAge > maxAge) {
              keysToDelete.add(key.toString());
            }
          }
        }
      }

      // Eliminar cache expirado
      for (var key in keysToDelete) {
        await box.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        print('🧹 Cleaned ${keysToDelete.length} expired offline song caches');
      }
    } catch (e) {
      print('❌ Error cleaning old offline cache: $e');
    }
  }

  // NUEVO: Método para mostrar información de debug del cache
  Future<void> debugCacheStatus() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID for cache debug');
      return;
    }

    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';
      final cachedData = box.get(songCacheKey, defaultValue: null);

      print('🐛 === CACHE DEBUG STATUS ===');
      print('   🆔 Song ID: ${widget.songId}');
      print('   🔑 Cache key: $songCacheKey');

      if (cachedData != null) {
        final timestamp = cachedData['cached_timestamp'] ?? 0;
        final lastChecked = cachedData['last_checked'] ?? 0;
        final notesCount = cachedData['notes_count'] ?? 0;
        final qualityMetrics =
            cachedData['quality_metrics'] as Map<String, dynamic>?;

        print(
            '   📅 Cached: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
        print(
            '   🔍 Last checked: ${DateTime.fromMillisecondsSinceEpoch(lastChecked)}');
        print('   🎵 Notes count: $notesCount');

        if (qualityMetrics != null) {
          final chromaticCoverage = qualityMetrics['chromatic_coverage'] ?? 0.0;
          final audioCoverage = qualityMetrics['audio_coverage'] ?? 0.0;
          print(
              '   📈 ChromaticNote coverage: ${(chromaticCoverage * 100).toStringAsFixed(1)}%');
          print(
              '   🔊 Audio coverage: ${(audioCoverage * 100).toStringAsFixed(1)}%');
        } else {
          print('   ⚠️ No quality metrics available');
        }
      } else {
        print('   📝 No cache found');
      }

      print('   🎵 Currently loaded notes: ${songNotes.length}');
      print('🐛 === END CACHE DEBUG ===');
    } catch (e) {
      print('❌ Error during cache debug: $e');
    }
  }

  // NUEVO: Método para forzar actualización manual desde la base de datos
  Future<void> forceUpdateFromDatabase() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID to force update');
      return;
    }

    print('🔄 FORCING database update...');

    setState(() {
      isLoadingSong = true;
    });

    try {
      // Limpiar cache existente
      if (Hive.isBoxOpen('offline_data')) {
        final box = Hive.box('offline_data');
        final songCacheKey = 'song_${widget.songId}_complete';
        await box.delete(songCacheKey);
        print('🗑️ Cleared existing cache');
      }

      // Cargar datos frescos forzosamente
      await _loadFreshDataFromDatabase();

      print('✅ Force update completed');
    } catch (e) {
      print('❌ Error during force update: $e');
    } finally {
      setState(() {
        isLoadingSong = false;
      });
    }
  }

  // MEJORADO: Método para verificar si necesita actualización basado en tiempo
  Future<bool> needsPeriodicUpdate() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      return false;
    }

    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';
      final cachedData = box.get(songCacheKey, defaultValue: null);

      if (cachedData == null) {
        return true; // No cache, necesita actualización
      }

      final lastChecked = cachedData['last_checked'] ?? 0;
      final timeSinceLastCheck =
          DateTime.now().millisecondsSinceEpoch - lastChecked;

      // Actualizar cada 6 horas para asegurar datos frescos
      const sixHours = 6 * 60 * 60 * 1000;
      return timeSinceLastCheck > sixHours;
    } catch (e) {
      print('❌ Error checking if needs periodic update: $e');
      return false;
    }
  }

  // NUEVO: Método helper para obtener información del cache offline
  static Future<Map<String, dynamic>> getOfflineCacheInfo() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      int totalSongs = 0;
      int totalAudioFiles = 0;

      for (var key in box.keys) {
        if (key.toString().startsWith('song_') &&
            key.toString().endsWith('_complete')) {
          totalSongs++;
        } else if (key.toString().startsWith('audio_')) {
          totalAudioFiles++;
        }
      }

      return {
        'total_songs': totalSongs,
        'total_audio_files': totalAudioFiles,
        'cache_size_mb': 0.0, // Se puede calcular si es necesario
      };
    } catch (e) {
      print('❌ Error getting offline cache info: $e');
      return {
        'total_songs': 0,
        'total_audio_files': 0,
        'cache_size_mb': 0.0,
      };
    }
  }

  // NUEVO: Método para limpiar cache de baja calidad de una canción específica
  // ignore: unused_element
  static Future<void> clearLowQualitySongCache(String songId) async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${songId}_complete';

      if (box.containsKey(songCacheKey)) {
        await box.delete(songCacheKey);
        print('🧹 Cleared low-quality cache for song: $songId');
      }
    } catch (e) {
      print('❌ Error clearing song cache: $e');
    }
  }

  // MEJORADO: Función para validar y reparar cache corrupto o de baja calidad
  Future<bool> validateAndRepairCache() async {
    print('🔧 === VALIDATING AND REPAIRING CACHE ===');

    if (widget.songId == null || widget.songId!.isEmpty) {
      print('❌ No song ID to validate');
      return false;
    }

    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }

      final box = Hive.box('offline_data');
      final songCacheKey = 'song_${widget.songId}_complete';
      final cachedData = box.get(songCacheKey, defaultValue: null);

      if (cachedData == null) {
        print('� No cache found - attempting fresh load');
        await _loadFreshDataFromDatabase();
        return songNotes.isNotEmpty;
      }

      // Verificar integridad del cache
      final qualityMetrics =
          cachedData['quality_metrics'] as Map<String, dynamic>?;

      if (qualityMetrics != null) {
        final chromaticCoverage = qualityMetrics['chromatic_coverage'] ?? 0.0;
        final audioCoverage = qualityMetrics['audio_coverage'] ?? 0.0;

        print('📊 Cache quality analysis:');
        print(
            '   🎯 ChromaticNote coverage: ${(chromaticCoverage * 100).toStringAsFixed(1)}%');
        print(
            '   � Audio coverage: ${(audioCoverage * 100).toStringAsFixed(1)}%');

        // Si la calidad es muy baja, intentar reparar
        if (chromaticCoverage < 0.5 || audioCoverage < 0.5) {
          print('⚠️ Cache quality is poor, attempting repair...');
          await _loadFreshDataFromDatabase();
          return songNotes.isNotEmpty;
        }
      } else {
        print('⚠️ No quality metrics found, validating cache data...');
        // Intentar cargar del cache existente y validar
        await _loadSongFromOfflineCache();

        if (songNotes.isEmpty) {
          print('📝 Cache is empty, attempting fresh load');
          await _loadFreshDataFromDatabase();
          return songNotes.isNotEmpty;
        }
      }

      print('✅ Cache validation successful');
      return true;
    } catch (e) {
      print('❌ Error during cache validation: $e');
      return false;
    } finally {
      print('🔧 === END CACHE VALIDATION ===');
    }
  }
}

// CustomPainter para dibujar las líneas guía de los pistones
class PistonGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Calcular las posiciones reales de los pistones
    const double pistonSize = 70.0;
    const double realPistonSeparation = 16.0;
    const double realPistonDiameter = 18.0;
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    // Ancho total del contenedor de pistones
    final double totalPistonWidth =
        (pistonSize * 3) + (pixelSeparation * 2) + 40;
    final double startX = (size.width - totalPistonWidth) / 2 + 20;

    // Dibujar líneas verticales para cada pistón en su posición real

    // Línea pistón 1
    final double piston1X = startX + (pistonSize / 2);
    canvas.drawLine(
      Offset(piston1X, 0),
      Offset(piston1X, size.height),
      paint,
    );

    // Línea pistón 2
    final double piston2X =
        startX + pistonSize + pixelSeparation + (pistonSize / 2);
    canvas.drawLine(
      Offset(piston2X, 0),
      Offset(piston2X, size.height),
      paint,
    );

    // Línea pistón 3
    final double piston3X =
        startX + (pistonSize * 2) + (pixelSeparation * 2) + (pistonSize / 2);
    canvas.drawLine(
      Offset(piston3X, 0),
      Offset(piston3X, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
