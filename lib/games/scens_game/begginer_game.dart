import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // NUEVO: Para cache robusto
import 'package:hive_flutter/hive_flutter.dart'; // NUEVO: Para cache offline
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
      return chromaticNote!.spanishName;
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
}

class _BegginnerGamePageState extends State<BegginnerGamePage>
    with TickerProviderStateMixin {
  bool showLogo = true;
  bool showCountdown = false;
  int countdownNumber = 3;
  Timer? logoTimer;
  Timer? countdownTimer;

  // Estado de los pistones (sin prevención de capturas por pistones)
  Set<int> pressedPistons = <int>{};

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

  // NUEVO: Controlador de audio continuo
  final ContinuousAudioController _audioController =
      ContinuousAudioController();
  bool _isAudioContinuous =
      false; // CAMBIADO: Inicialmente deshabilitado para pruebas
  bool _playerIsOnTrack = true; // Si el jugador está tocando correctamente

  // Configuración del juego
  static const double noteSpeed = 200.0; // pixels por segundo
  static const double hitTolerance =
      70.0; // Tolerancia aumentada para hits más fáciles y anticipados

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
    _loadSongData(); // Cargar datos musicales
    _startLogoTimer(); // MOVIDO: iniciar timer después de cargar datos
  }

  // NUEVO: Inicializar Hive si no está abierto
  Future<void> _initializeHive() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
        print('✅ Hive box opened successfully');
      }
    } catch (e) {
      print('❌ Error initializing Hive: $e');
    }
  }

  // NUEVO: Inicializar el servicio de audio
  Future<void> _initializeAudio() async {
    try {
      await NoteAudioService.initialize();

      // NUEVO: Inicializar controlador de audio continuo
      await _audioController.initialize();

      // Verificar tamaño del caché y limpiar si es muy grande
      final cacheSizeMB = await NoteAudioService.getCacheSizeMB();
      print('📊 Audio cache size: ${cacheSizeMB.toStringAsFixed(1)} MB');

      if (cacheSizeMB > 50) {
        // Si el caché supera 50MB
        print('🧹 Cache too large, clearing old files...');
        await NoteAudioService.clearOldCache();
      }

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

    // SIEMPRE intentar cargar desde la base de datos si hay songId
    if (widget.songId != null && widget.songId!.isNotEmpty) {
      try {
        print('🔍 Attempting to load from database...');
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

          // NUEVO: Precargar TODOS los audios durante el logo
          _precacheAllAudioFiles();

          currentNoteIndex = 0;
        } else {
          print('⚠️ No notes found in database for this song');
          songNotes = []; // Lista vacía, no crear notas demo
        }
      } catch (e) {
        print('❌ Error loading song data: $e');
        songNotes = []; // Lista vacía en caso de error
      }
    } else {
      print('⚠️ No song ID provided, cannot load notes');
      songNotes = []; // Sin ID de canción, lista vacía
    }

    setState(() {
      isLoadingSong = false;
    });
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

  // NUEVO: Precargar TODOS los audios durante la pantalla del logo (SISTEMA ROBUSTO)
  Future<void> _precacheAllAudioFiles() async {
    try {
      setState(() {
        isPreloadingAudio = true;
        audioCacheProgress = 0;
      });

      print('🎵 Starting robust audio precaching...');

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

      // Obtener todas las URLs únicas de audio
      final Set<String> uniqueAudioUrls = {};
      for (var note in songNotes) {
        if (note.noteUrl != null && note.noteUrl!.isNotEmpty) {
          uniqueAudioUrls.add(note.noteUrl!);
        }
      }

      print('📥 Found ${uniqueAudioUrls.length} unique audio files to cache');

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

      print(
          '🎉 Audio precaching completed! ${successCount}/${uniqueAudioUrls.length} files cached successfully');

      // Proceder al countdown ahora que el cache está completo
      _proceedToCountdown();
    } catch (e) {
      print('❌ Error during audio precaching: $e');
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

  @override
  void dispose() {
    logoTimer?.cancel();
    countdownTimer?.cancel();
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();
    _logoExitTimer?.cancel(); // NUEVO: Cancelar timer de salida del logo
    _endGameTimer?.cancel(); // NUEVO: Cancelar timer de diálogo final
    _pistonCombinationTimer
        ?.cancel(); // NUEVO: Cancelar timer de combinaciones de pistones
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

  // Generar notas basadas en los datos de la base de datos
  void _spawnNotesFromDatabase() {
    noteSpawner = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      final currentGameTime =
          DateTime.now().millisecondsSinceEpoch - gameStartTime;
      const int lookaheadTime = 3000; // 3 segundos de anticipación

      // Verificar si hay notas que deben aparecer pronto
      while (currentNoteIndex < songNotes.length) {
        final songNote = songNotes[currentNoteIndex];
        final noteAppearTime = songNote.startTimeMs - lookaheadTime;

        if (currentGameTime >= noteAppearTime) {
          print(
              'Spawning note: ${songNote.noteName} (pistons: ${songNote.pistonCombination}) at game time ${currentGameTime}ms');

          // Calcular posición Y con espaciado automático
          final double calculatedY = _calculateNoteSpacing();

          // Crear FallingNote con datos cromáticos y posición espaciada
          final fallingNote = FallingNote(
            piston: songNote.pistonCombination.isNotEmpty
                ? songNote.pistonCombination.first
                : 1,
            songNote: songNote,
            chromaticNote: songNote.chromaticNote, // Pasar datos cromáticos
            y: calculatedY,
            startTime: DateTime.now().millisecondsSinceEpoch / 1000,
          );

          fallingNotes.add(fallingNote);
          print(
              '✅ Added note with chromatic data: ${fallingNote.noteName} at Y: $calculatedY');
          currentNoteIndex++;
        } else {
          break;
        }
      }

      // Si ya mostramos todas las notas, detener el spawner
      if (currentNoteIndex >= songNotes.length) {
        print('All notes spawned. Total: ${songNotes.length}');
        timer.cancel();
      }
    });
  }

  // Calcular espaciado automático de notas para evitar superposición
  double _calculateNoteSpacing() {
    const double noteHeight = 60.0; // Altura de cada nota
    const double minNoteGap = 20.0; // Espacio mínimo entre notas
    const double totalSpacing =
        noteHeight + minNoteGap; // Espaciado total requerido
    const double defaultStartY = -50.0; // Posición Y inicial por defecto

    if (fallingNotes.isEmpty) {
      return defaultStartY;
    }

    // Buscar todas las notas activas y sus rangos ocupados
    List<double> occupiedRanges = [];

    for (var existingNote in fallingNotes) {
      if (!existingNote.isHit && !existingNote.isMissed) {
        // Calcular el rango que ocupa esta nota (desde Y hasta Y + altura)
        double noteTop = existingNote.y;
        double noteBottom = existingNote.y + noteHeight;
        occupiedRanges.add(noteTop);
        occupiedRanges.add(noteBottom);
      }
    }

    if (occupiedRanges.isEmpty) {
      return defaultStartY;
    }

    // Ordenar los rangos para encontrar el espacio más alto disponible
    occupiedRanges.sort();

    // Encontrar la posición más alta ocupada
    double highestOccupiedY = occupiedRanges.first;

    // Calcular nueva posición Y asegurando que no hay superposición
    double newY = highestOccupiedY - totalSpacing;

    print(
        '📏 Note spacing: highest occupied Y: $highestOccupiedY, new Y: $newY, total spacing: $totalSpacing');

    return newY;
  }

  // Actualizar posiciones de las notas
  void _updateGame() {
    gameUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // ~60 FPS
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      setState(() {
        final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // Calcular zona de hit responsive (igual que en _buildHitZone)
        final isTablet = screenWidth > 600;
        final isSmallPhone = screenHeight < 700;

        double hitZoneBottom;
        if (isSmallPhone) {
          hitZoneBottom = 110; // Más cerca para celulares pequeños
        } else if (isTablet) {
          hitZoneBottom = 150; // Más espacio en tablets
        } else {
          hitZoneBottom = 130; // Tamaño estándar para celulares normales
        }

        final hitZoneY = screenHeight - hitZoneBottom;

        // Actualizar posición de cada nota
        for (var note in fallingNotes) {
          if (!note.isHit && !note.isMissed) {
            final elapsed = currentTime - note.startTime;
            note.y = -50 + (elapsed * noteSpeed);

            // AUTO-HIT para notas de aire (sin presionar pistones)
            if (note.isOpenNote &&
                note.y >= hitZoneY - 30 &&
                note.y <= hitZoneY + 30) {
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

              _onNoteHit(note.noteName); // Contar como acierto
              continue; // Pasar a la siguiente nota
            }

            // Verificar si la nota se perdió (más cerca de los pistones - límite reducido)
            if (note.y > hitZoneY + 50) {
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

  // Verificar si el juego ha terminado
  void _checkGameEnd() {
    // Solo terminar el juego si hay notas para mostrar y ya se terminaron
    if (songNotes.isNotEmpty &&
        currentNoteIndex >= songNotes.length &&
        fallingNotes.isEmpty) {
      print('🏁 Game ended! All notes completed.');
      _endGame();
    }
    // Si no hay notas, el juego sigue activo pero sin mostrar nada
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
    showCongratulationsDialog(
      context,
      experiencePoints: experiencePoints,
      totalScore: currentScore,
      correctNotes: correctNotes,
      missedNotes: totalNotes - correctNotes,
      onContinue: () {
        Navigator.pop(context); // Regresar al menú anterior
      },
    );
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
  void _checkNoteHit(int pistonNumber) {
    bool hitCorrectNote = false;
    bool isInHitZone = false;

    // Primero verificar si hay alguna nota en la zona de hit
    for (var note in fallingNotes) {
      if (!note.isHit && !note.isMissed) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        // Calcular zona de hit responsive (igual que en el timer y _buildHitZone)
        final isTablet = screenWidth > 600;
        final isSmallPhone = screenHeight < 700;

        double hitZoneBottom;
        if (isSmallPhone) {
          hitZoneBottom = 110; // Más cerca para celulares pequeños
        } else if (isTablet) {
          hitZoneBottom = 150; // Más espacio en tablets
        } else {
          hitZoneBottom = 130; // Tamaño estándar para celulares normales
        }

        final hitZoneY = screenHeight - hitZoneBottom;
        final distance = (note.y - hitZoneY).abs();

        // Verificar si la nota está en la zona de hit
        if (distance <= hitTolerance || note.y >= hitZoneY - 40) {
          isInHitZone = true;

          // Verificar si los pistones presionados coinciden EXACTAMENTE con la nota
          if (_exactPistonMatch(note, pressedPistons)) {
            print(
                '✅ EXACT HIT! Note: ${note.noteName}, Required: ${note.requiredPistons}, Pressed: $pressedPistons');
            note.isHit = true;
            hitCorrectNote = true;

            setState(() {
              lastPlayedNote = note.noteName;
            });

            // NUEVO: Notificar al controlador que el jugador acertó
            if (_isAudioContinuous) {
              _audioController.onPlayerHit(pressedPistons);
              if (!_playerIsOnTrack) {
                _playerIsOnTrack = true;
                print('🔊 Player back on track');
              }
            }

            _onNoteHit(note.noteName);
            return;
          } else {
            // Debug: mostrar qué se esperaba vs qué se presionó
            print('🔍 PARTIAL MATCH - Note: ${note.noteName}');
            print(
                '   Required: ${note.requiredPistons} (${note.requiredPistons.length} pistons)');
            print(
                '   Pressed: $pressedPistons (${pressedPistons.length} pistons)');

            // Si es una combinación de múltiples pistones, dar un poco más de tiempo
            final requiredCount = note.requiredPistons.length;
            if (requiredCount > 1 && pressedPistons.length < requiredCount) {
              print(
                  '⏳ Multi-piston note - waiting for complete combination...');
              // No marcar como error aún, puede que esté presionando gradualmente
              return;
            }
          }
        }
      }
    }

    // Solo marcar como error si había una nota en zona de hit Y no se acertó
    if (isInHitZone && !hitCorrectNote && _playerIsOnTrack) {
      print('❌ MISS! Pressed: $pressedPistons - Player off track');

      // NUEVO: Notificar al controlador que el jugador falló
      if (_isAudioContinuous) {
        _audioController.onPlayerMiss();
        _playerIsOnTrack = false;
        print('🔇 Player off track');
      }

      _onNoteMissed();
    } else if (!isInHitZone) {
      print('🎵 FREE PLAY - No notes in hit zone, just playing sound');
    }
  }

  // NUEVO: Función auxiliar para verificar coincidencia exacta de pistones
  bool _exactPistonMatch(FallingNote note, Set<int> pressedPistons) {
    final required = note.requiredPistons.toSet();

    // Para notas de aire (sin pistones)
    if (required.isEmpty) {
      return pressedPistons.isEmpty;
    }

    // Para notas que requieren pistones específicos
    return required.length == pressedPistons.length &&
        required.every((piston) => pressedPistons.contains(piston));
  }

  // MEJORADO: Mejor detección de combinaciones de pistones para reproducir sonido
  void _playNoteFromPistonCombination() {
    // Si no hay pistones presionados, reproducir nota de aire
    if (pressedPistons.isEmpty) {
      print('🎵 No pistons pressed - playing open note (air)');
      _playOpenNote();
      return;
    }

    print('🎹 Finding note for piston combination: $pressedPistons');
    SongNote? noteToPlay;

    // 1. Buscar en notas cayendo que coincidan EXACTAMENTE con los pistones presionados
    for (var fallingNote in fallingNotes) {
      if (!fallingNote.isHit &&
          !fallingNote.isMissed &&
          _exactPistonMatchForSong(fallingNote.songNote, pressedPistons) &&
          fallingNote.songNote != null) {
        noteToPlay = fallingNote.songNote!;
        print(
            '🎵 Playing from falling note: ${noteToPlay.noteName} (${noteToPlay.pistonCombination})');
        break;
      }
    }

    // 2. Si no hay notas cayendo, buscar en todas las notas cargadas con coincidencia exacta
    if (noteToPlay == null && songNotes.isNotEmpty) {
      for (var songNote in songNotes) {
        if (_exactPistonMatchForSong(songNote, pressedPistons)) {
          noteToPlay = songNote;
          print(
              '🎵 Playing from database: ${noteToPlay.noteName} (${noteToPlay.pistonCombination})');
          break; // Tomar la primera que coincida exactamente
        }
      }
    }

    // 3. Reproducir la nota encontrada usando el cache robusto
    if (noteToPlay != null && noteToPlay.noteUrl != null) {
      _playFromRobustCache(noteToPlay);
    } else {
      print('⚠️ No exact match found for: $pressedPistons');
      _debugAvailableCombinations();
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

  // NUEVO: Reproducir nota de aire (sin pistones)
  void _playOpenNote() {
    SongNote? openNote;

    // Buscar nota sin pistones requeridos
    for (var note in songNotes) {
      if (note.pistonCombination.isEmpty) {
        openNote = note;
        break;
      }
    }

    if (openNote != null && openNote.noteUrl != null) {
      print('🌬️ Playing open note: ${openNote.noteName}');
      _playFromRobustCache(openNote);
    }
  }

  // NUEVO: Debug de combinaciones disponibles
  void _debugAvailableCombinations() {
    if (songNotes.isNotEmpty) {
      print('📋 Available combinations (first 5):');
      for (var note in songNotes.take(5)) {
        final combo = note.pistonCombination.isEmpty
            ? '[Air]'
            : note.pistonCombination.toString();
        print('   ${note.noteName}: $combo');
      }
    }
  }

  // NUEVO: Reproducir audio desde cache robusto
  Future<void> _playFromRobustCache(SongNote note) async {
    if (note.noteUrl == null) return;

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
        // Reproducir desde archivo local cached usando el sistema existente
        final localFile = File(cachedData['path']);
        await NoteAudioService.playNoteFromUrl(
          localFile.uri.toString(), // Convertir path local a URI
          noteId: note.chromaticId?.toString(),
          durationMs: note.durationMs,
        );
        print('🔊 Audio played from robust cache: ${note.noteName}');
      } else {
        // Fallback: usar el sistema original
        NoteAudioService.playNoteFromUrl(
          note.noteUrl!,
          noteId: note.chromaticId?.toString(),
          durationMs: note.durationMs,
        ).then((_) {
          print('🔊 Audio played via fallback: ${note.noteName}');
        }).catchError((e) {
          print('⚠️ Audio playback failed: $e');
        });
      }
    } catch (e) {
      print('⚠️ Error playing from cache, using fallback: $e');
      // Fallback completo
      NoteAudioService.playNoteFromUrl(
        note.noteUrl!,
        noteId: note.chromaticId?.toString(),
        durationMs: note.durationMs,
      ).catchError((e) => print('⚠️ Fallback also failed: $e'));
    }
  }

  // Cuando se acierta una nota (solo actualizar puntuación)
  void _onNoteHit([String? noteName]) {
    setState(() {
      totalNotes++;
      correctNotes++;
      currentScore += 10;
      experiencePoints += experiencePerCorrectNote;
    });

    // NO reproducir sonido aquí - el sonido se reproduce en _onPistonPressed
    // if (noteName != null) {
    //   _playNoteSound(noteName);
    // }

    // Feedback háptico
    HapticFeedback.lightImpact();
  }

  // Cuando se falla una nota
  void _onNoteMissed() {
    setState(() {
      totalNotes++;
      // No incrementar correctNotes
      currentScore = (currentScore - 5).clamp(0, double.infinity).toInt();
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
                          ? 'Descargando ${audioCacheProgress}%'
                          : _audioCacheCompleted
                              ? '¡Audio listo!'
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
                    'Optimizando experiencia musical',
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

    // Detectar si es tablet o celular para ajustar posición
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Posición responsive de la zona de hit
    // Para celulares pequeños: más cerca de los pistones
    // Para tablets: más espacio para acomodar mejor el layout
    double hitZoneBottom;
    double hitZoneHeight;

    if (isSmallPhone) {
      hitZoneBottom = 110; // Más cerca para celulares pequeños
      hitZoneHeight = 80; // Zona más compacta
    } else if (isTablet) {
      hitZoneBottom = 150; // Más espacio en tablets
      hitZoneHeight = 120; // Zona más grande
    } else {
      hitZoneBottom = 130; // Tamaño estándar para celulares normales
      hitZoneHeight = 100;
    }

    return Positioned(
      bottom: hitZoneBottom,
      left: 0,
      right: 0,
      child: Container(
        height: hitZoneHeight,
        decoration: BoxDecoration(
          // Hacer la zona visible para pruebas (comentar después si se desea)
          color: Colors.white.withOpacity(0.05), // Muy sutil pero visible
          border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'ZONA DE HIT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
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

    // Calcular el rango de pistones a cubrir
    final minPiston = requiredPistons.reduce((a, b) => a < b ? a : b);
    final maxPiston = requiredPistons.reduce((a, b) => a > b ? a : b);

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
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
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
      ),
    );
  }

  // Timer para manejar combinaciones de pistones
  Timer? _pistonCombinationTimer;

  void _onPistonPressed(int pistonNumber) {
    // Feedback háptico
    HapticFeedback.lightImpact();

    // Agregar pistón al conjunto de pistones presionados
    pressedPistons.add(pistonNumber);

    print(
        '🎹 Piston $pistonNumber pressed. Current combination: $pressedPistons');

    // Cancelar timer anterior si existe
    _pistonCombinationTimer?.cancel();

    // Crear un pequeño delay para permitir combinaciones naturales
    _pistonCombinationTimer = Timer(const Duration(milliseconds: 100), () {
      // Reproducir sonido para la combinación actual
      _playNoteFromPistonCombination();

      // Verificar si hay una nota que golpear (solo para scoring)
      if (isGameActive) {
        _checkNoteHit(pistonNumber);
      }
    });

    debugPrint(
        'Pistón $pistonNumber presionado - Combination: $pressedPistons');
  }

  void _onPistonReleased(int pistonNumber) {
    // Remover pistón del conjunto de pistones presionados
    pressedPistons.remove(pistonNumber);

    print(
        '🎹 Piston $pistonNumber released. Current combination: $pressedPistons');

    // Cancelar timer de combinación al soltar
    _pistonCombinationTimer?.cancel();

    // Si aún hay pistones presionados, crear nuevo timer para la nueva combinación
    if (pressedPistons.isNotEmpty) {
      _pistonCombinationTimer = Timer(const Duration(milliseconds: 50), () {
        _playNoteFromPistonCombination();
        if (isGameActive) {
          // Solo verificar hit si se soltó en zona de hit activa
          _checkNoteHit(pistonNumber);
        }
      });
    }

    debugPrint('Pistón $pistonNumber liberado - Remaining: $pressedPistons');
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
