import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../game/dialogs/back_dialog.dart';
import '../game/dialogs/pause_dialog.dart';
import '../../models/song_note.dart';
import '../../services/database_service.dart';
// import '../game/dialogs/congratulations_dialog.dart';

// Clase para representar una nota que cae
class FallingNote {
  final int piston; // 1, 2, o 3 (para retrocompatibilidad)
  final SongNote? songNote; // Nota musical de la base de datos (nueva)
  double y; // Posición Y actual
  final double startTime; // Tiempo cuando empezó a caer
  bool isHit; // Si ya fue golpeada
  bool isMissed; // Si se perdió la nota

  FallingNote({
    required this.piston,
    this.songNote,
    required this.y,
    required this.startTime,
    this.isHit = false,
    this.isMissed = false,
  });

  // Obtener los pistones requeridos para esta nota
  List<int> get requiredPistons => songNote?.pistonCombination ?? [piston];

  // Obtener el nombre de la nota musical
  String get noteName => songNote?.noteName ?? '$piston';

  // Verificar si los pistones presionados coinciden
  bool matchesPistons(Set<int> pressedPistons) {
    if (songNote != null) {
      return songNote!.matchesPistonCombination(pressedPistons);
    } else {
      // Lógica original para notas simples
      return pressedPistons.contains(piston);
    }
  }

  // Obtener color basado en los pistones requeridos
  Color get noteColor {
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
  int currentNoteIndex = 0; // Índice de la próxima nota a mostrar
  int gameStartTime = 0; // Tiempo cuando empezó el juego (en milisegundos)
  String?
      lastPlayedNote; // Última nota musical tocada (para mostrar en el contenedor)

  // Sistema de audio para notas de trompeta
  late AudioPlayer _audioPlayer;
  static const Map<String, String> _noteToAudioFile = {
    // Octava 3
    'F#3': 'F#3.ogg',
    'GB3': 'F#3.ogg', // Gb es lo mismo que F#
    'G3': 'G3.ogg',
    'G#3': 'G#3.ogg',
    'AB3': 'G#3.ogg', // Ab es lo mismo que G#
    'A3': 'A3.ogg',
    'A#3': 'A#3.ogg',
    'BB3': 'A#3.ogg', // Bb es lo mismo que A#
    'B3': 'B3.ogg',

    // Octava 4
    'C4': 'C4.ogg',
    'C#4': 'C#4.ogg',
    'DB4': 'C#4.ogg', // Db es lo mismo que C#
    'D4': 'D4.ogg',
    'D#4': 'D#4.ogg',
    'EB4': 'D#4.ogg', // Eb es lo mismo que D#
    'E4': 'E4.ogg',
    'F4': 'F4.ogg',
    'F#4': 'F#4.ogg',
    'GB4': 'F#4.ogg', // Gb es lo mismo que F#
    'G4': 'G4.ogg',
    'G#4': 'G#4.ogg',
    'AB4': 'G#4.ogg', // Ab es lo mismo que G#
    'A4': 'A4.ogg',
    'A#4': 'A#4.ogg',
    'BB4': 'A#4.ogg', // Bb es lo mismo que A#
    'B4': 'B4.ogg',

    // Octava 5
    'C5': 'C5.ogg',
    'C#5': 'C#5.ogg',
    'DB5': 'C#5.ogg', // Db es lo mismo que C#
    'D5': 'D5.ogg',
    'D#5': 'D#5.ogg',
    'EB5': 'D#5.ogg', // Eb es lo mismo que D#
    'E5': 'E5.ogg',
    'F5': 'F5.ogg',
    'F#5': 'F#5.ogg',
    'GB5': 'F#5.ogg', // Gb es lo mismo que F#
    'G5': 'G5.ogg',
    'G#5': 'G#5.ogg',
    'AB5': 'G#5.ogg', // Ab es lo mismo que G#
    'A5': 'A5.ogg',
    'A#5': 'A#5.ogg',
    'BB5': 'A#5.ogg', // Bb es lo mismo que A#
    'B5': 'B5.ogg',

    // Octava 6
    'C6': 'C6.ogg',
    'C#6': 'C#6.ogg',
    'DB6': 'C#6.ogg', // Db es lo mismo que C#
    'D6': 'D6.ogg',
    'D#6': 'D#6.ogg',
    'EB6': 'D#6.ogg', // Eb es lo mismo que D#
    'E6': 'E6.ogg',
    'F#6': 'F#6.ogg',
    'GB6': 'F#6.ogg', // Gb es lo mismo que F#
  };

  // Configuración del juego
  static const double noteSpeed = 200.0; // pixels por segundo
  static const double hitTolerance =
      50.0; // Tolerancia aumentada para hits más fáciles después de los pistones

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
    _startLogoTimer();
    _initializeAnimations();
    _initializeAudio(); // Inicializar sistema de audio
    _loadSongData(); // Cargar datos musicales
  }

  // Inicializar el sistema de audio
  void _initializeAudio() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setVolume(0.7); // Volumen al 70%
  }

  // Cargar datos de la canción desde la base de datos
  Future<void> _loadSongData() async {
    if (widget.songId == null || widget.songId!.isEmpty) {
      print('⚠️ No song ID provided, using demo notes');
      songNotes = _createDemoNotes();
      return;
    }

    setState(() {
      isLoadingSong = true;
    });

    try {
      songNotes = await DatabaseService.getSongNotes(widget.songId!);
      print(
          '✅ Loaded ${songNotes.length} notes from database for song: ${widget.songName}');

      // Mostrar información de las primeras 5 notas
      for (int i = 0; i < (songNotes.length < 5 ? songNotes.length : 5); i++) {
        final note = songNotes[i];
        print(
            'Note $i: ${note.noteName} at ${note.startTimeMs}ms - Pistons: ${note.pistonCombination}');
      }

      currentNoteIndex = 0;
    } catch (e) {
      print('❌ Error loading song data: $e');
      songNotes = _createDemoNotes(); // Fallback a notas demo
    } finally {
      setState(() {
        isLoadingSong = false;
      });
    }
  }

  // Crear notas demo si falla la carga de la base de datos
  List<SongNote> _createDemoNotes() {
    print('Creating demo notes...');
    return List.generate(20, (index) {
      final notes = ['F4', 'G4', 'A4', 'Bb4', 'C5', 'D5'];
      return SongNote(
        id: 'demo_$index',
        songId: 'demo',
        noteName: notes[index % notes.length],
        startTimeMs: index * 2000, // Una nota cada 2 segundos
        durationMs: 500,
        beatPosition: 1.0,
        measureNumber: (index ~/ 4) + 1,
        noteType: 'quarter',
        velocity: 80,
        createdAt: DateTime.now(),
      );
    });
  }

  // Reproducir el sonido correspondiente a una nota musical
  Future<void> _playNoteSound(String noteName) async {
    try {
      // Normalizar el nombre de la nota (convertir Bb a A#, etc.)
      String normalizedNote = noteName;
      if (noteName.contains('b')) {
        normalizedNote = noteName.replaceAll('b', '#');
        // Convertir bemol a sostenido equivalente
        if (normalizedNote.startsWith('Db')) {
          normalizedNote = normalizedNote.replaceFirst('Db', 'C#');
        } else if (normalizedNote.startsWith('Eb')) {
          normalizedNote = normalizedNote.replaceFirst('Eb', 'D#');
        } else if (normalizedNote.startsWith('Gb')) {
          normalizedNote = normalizedNote.replaceFirst('Gb', 'F#');
        } else if (normalizedNote.startsWith('Ab')) {
          normalizedNote = normalizedNote.replaceFirst('Ab', 'G#');
        } else if (normalizedNote.startsWith('Bb')) {
          normalizedNote = normalizedNote.replaceFirst('Bb', 'A#');
        }
      }

      // Buscar el archivo de audio correspondiente
      final audioFile = _noteToAudioFile[normalizedNote];
      if (audioFile != null) {
        // Detener cualquier sonido anterior
        await _audioPlayer.stop();

        // Reproducir el nuevo sonido
        await _audioPlayer
            .play(AssetSource('games/game/Songs/Trumpet_notes/$audioFile'));
        print('🎵 Playing sound: $audioFile for note: $noteName');
      } else {
        print(
            '⚠️ No audio file found for note: $noteName (normalized: $normalizedNote)');
      }
    } catch (e) {
      print('❌ Error playing note sound: $e');
    }
  }

  @override
  void dispose() {
    logoTimer?.cancel();
    countdownTimer?.cancel();
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();
    _rotationController.dispose();
    _noteAnimationController.dispose();
    // Limpiar recursos de audio
    _audioPlayer.dispose();
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
    logoTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showLogo = false;
          showCountdown = true;
        });
        _startCountdown();
      }
    });
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
    isGameActive = true;
    _spawnNotes();
    _updateGame();
  }

  // Generar notas basadas en los datos de la base de datos
  void _spawnNotes() {
    gameStartTime = DateTime.now().millisecondsSinceEpoch;

    if (songNotes.isNotEmpty) {
      print('Using real song notes from database');
      _spawnNotesFromDatabase();
    } else {
      print('Using demo notes');
      _spawnDemoNotes();
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

          fallingNotes.add(FallingNote(
            piston: songNote.pistonCombination.isNotEmpty
                ? songNote.pistonCombination.first
                : 1,
            songNote: songNote,
            y: -50,
            startTime: DateTime.now().millisecondsSinceEpoch / 1000,
          ));
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

  // Generar notas demo
  void _spawnDemoNotes() {
    noteSpawner = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (!isGameActive ||
          isGamePaused ||
          currentNoteIndex >= songNotes.length) {
        timer.cancel();
        return;
      }

      final songNote = songNotes[currentNoteIndex];
      fallingNotes.add(FallingNote(
        piston: songNote.pistonCombination.isNotEmpty
            ? songNote.pistonCombination.first
            : 1,
        songNote: songNote,
        y: -50,
        startTime: DateTime.now().millisecondsSinceEpoch / 1000,
      ));
      currentNoteIndex++;
    });
  } // Actualizar posiciones de las notas

  void _updateGame() {
    gameUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // ~60 FPS
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      setState(() {
        final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;

        // Actualizar posición de cada nota
        for (var note in fallingNotes) {
          if (!note.isHit && !note.isMissed) {
            final elapsed = currentTime - note.startTime;
            note.y = -50 + (elapsed * noteSpeed);

            // Verificar si la nota se perdió (pasó la zona de hit ampliada)
            final screenHeight = MediaQuery.of(context).size.height;
            final hitZoneY = screenHeight - 160;
            if (note.y > hitZoneY + 80) {
              // Pasó la zona de hit + margen generoso
              note.isMissed = true;
              _onNoteMissed();
            }
          }
        }

        // Remover notas que ya no se necesitan
        fallingNotes.removeWhere((note) => note.y > 700 || note.isHit);
      });
    });
  }

  // Métodos de control de pausa
  void _pauseGame() {
    if (isGameActive && !isGamePaused) {
      setState(() {
        isGamePaused = true;
      });
      noteSpawner?.cancel();
      gameUpdateTimer?.cancel();

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
      _spawnNotes();
      _updateGame();
    }
  }

  void _restartGame() {
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
    });

    // Cancelar timers
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();

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

  // Cuando se presiona un pistón, verificar si hay una nota
  void _checkNoteHit(int pistonNumber) {
    setState(() {
      pressedPistons.add(pistonNumber);
    });

    for (var note in fallingNotes) {
      if (!note.isHit && !note.isMissed) {
        final screenHeight = MediaQuery.of(context).size.height;
        final hitZoneY = screenHeight - 160;
        final distance = (note.y - hitZoneY).abs();

        if (distance <= hitTolerance) {
          // Usar la nueva lógica de pistones
          if (note.matchesPistons(pressedPistons)) {
            print(
                '✅ HIT! Note: ${note.noteName}, Required: ${note.requiredPistons}, Pressed: $pressedPistons');
            note.isHit = true;

            // Actualizar la última nota tocada para mostrar en el contenedor
            setState(() {
              lastPlayedNote = note.noteName;
            });

            _onNoteHit(note.noteName); // Pasar el nombre de la nota
            return;
          }
        }
      }
    }
    print('❌ MISS! Pressed: $pressedPistons');
    _onNoteMissed();
  }

  // Cuando se acierta una nota
  void _onNoteHit([String? noteName]) {
    setState(() {
      totalNotes++;
      correctNotes++;
      currentScore += 10;
      experiencePoints += experiencePerCorrectNote;
    });

    // Reproducir sonido de la nota tocada
    if (noteName != null) {
      _playNoteSound(noteName);
    }

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
            // Logo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/icono.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 100,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Texto de carga
            const Text(
              'REFMP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nivel Principiante',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
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

          // Controles de pistones en la parte inferior centrados (encima del área de juego)
          Positioned(
            bottom: 20,
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
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              color: Colors.white,
              size: 35,
            );
          },
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
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
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

  // Construir la zona de hit (sutil, después de los pistones)
  Widget _buildHitZone() {
    return Positioned(
      bottom:
          130, // Posición más arriba para cubrir mejor la zona de los pistones
      left: 0,
      right: 0,
      child: Container(
        height: 120, // Zona de hit mucho más grande para mejor detección
        // decoration: BoxDecoration(
        //   color: Colors.white.withOpacity(0.1), // Muy sutil
        //   border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        // ),
      ),
    );
  }

  // Construir las notas que caen
  List<Widget> _buildFallingNotes() {
    return fallingNotes.map((note) {
      if (note.isHit || note.isMissed) return const SizedBox.shrink();

      // Calcular la posición X basada en la posición real de los pistones
      final screenWidth = MediaQuery.of(context).size.width;

      // Configuración de pistones (igual que en _buildPistonControls)
      const double pistonSize = 70.0;
      const double realPistonSeparation = 16.0;
      const double realPistonDiameter = 18.0;
      final double pixelSeparation =
          (realPistonSeparation / realPistonDiameter) * pistonSize;

      // Ancho total del contenedor de pistones
      final double totalPistonWidth =
          (pistonSize * 3) + (pixelSeparation * 2) + 40; // +40 por padding
      final double startX = (screenWidth - totalPistonWidth) / 2 +
          20; // Centrado + padding inicial

      // Posición X de cada pistón
      double pistonCenterX;
      switch (note.piston) {
        case 1:
          pistonCenterX = startX + (pistonSize / 2);
          break;
        case 2:
          pistonCenterX =
              startX + pistonSize + pixelSeparation + (pistonSize / 2);
          break;
        case 3:
          pistonCenterX = startX +
              (pistonSize * 2) +
              (pixelSeparation * 2) +
              (pistonSize / 2);
          break;
        default:
          pistonCenterX = startX + (pistonSize / 2);
      }

      final noteX =
          pistonCenterX - 25; // -25 porque la nota tiene 50px de ancho

      return Positioned(
        left: noteX,
        top: note.y,
        child: _buildNote(note),
      );
    }).toList();
  }

  // Construir una nota individual
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
              note.noteName,
              style: TextStyle(
                color: Colors.white,
                fontSize: note.noteName.length > 2 ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Si hay pistones requeridos, mostrar indicador
            if (note.requiredPistons.isNotEmpty)
              Text(
                note.requiredPistons.join(','),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
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
    // Simular las distancias reales de una trompeta (ajustado para estar más cerca)
    // En una trompeta real, los pistones están separados por aproximadamente 22mm
    // Tamaño del pistón: aproximadamente 18mm de diámetro
    const double pistonSize = 70.0; // Tamaño del botón en pixels
    const double realPistonSeparation =
        16.0; // Reducido de 22.0 para estar más cerca
    const double realPistonDiameter = 18.0; // mm en trompeta real

    // Calcular la separación proporcional en pixels
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pistón 1
          _buildPistonButton(1),

          SizedBox(width: pixelSeparation),

          // Pistón 2
          _buildPistonButton(2),

          SizedBox(width: pixelSeparation),

          // Pistón 3
          _buildPistonButton(3),
        ],
      ),
    );
  }

  Widget _buildPistonButton(int pistonNumber) {
    const double pistonSize =
        70.0; // Tamaño constante para simular trompeta real

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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
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

  void _onPistonPressed(int pistonNumber) {
    // Feedback háptico
    HapticFeedback.lightImpact();

    // Agregar pistón al conjunto de pistones presionados
    pressedPistons.add(pistonNumber);

    // Verificar si hay una nota que golpear
    if (isGameActive) {
      _checkNoteHit(pistonNumber);
    }

    debugPrint('Pistón $pistonNumber presionado');
  }

  void _onPistonReleased(int pistonNumber) {
    // Remover pistón del conjunto de pistones presionados
    pressedPistons.remove(pistonNumber);

    debugPrint('Pistón $pistonNumber liberado');

    // TODO: Implementar lógica del juego
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
