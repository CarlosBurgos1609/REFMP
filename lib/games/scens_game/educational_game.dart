import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../game/dialogs/pause_dialog.dart';
import '../game/dialogs/back_dialog.dart';
import '../game/dialogs/congratulations_dialog.dart';

/// Juego educativo que muestra una partitura y hace caer notas
/// El estudiante debe presionar los pistones correctos sin reproducir sonido
class EducationalGamePage extends StatefulWidget {
  final String sublevelId;
  final String title;
  final String? sheetMusicImageUrl;
  final String? backgroundAudioUrl;
  final int experiencePoints; // Puntos configurados en la base de datos

  const EducationalGamePage({
    super.key,
    required this.sublevelId,
    required this.title,
    this.sheetMusicImageUrl,
    this.backgroundAudioUrl,
    this.experiencePoints = 0,
  });

  @override
  State<EducationalGamePage> createState() => _EducationalGamePageState();
}

class _EducationalGamePageState extends State<EducationalGamePage>
    with TickerProviderStateMixin {
  // Control del juego
  bool showLogo = true;
  bool showCountdown = false;
  bool isGameActive = false;
  bool isGamePaused = false;
  bool isLoadingData = true;
  int countdownNumber = 3;

  // Timers
  Timer? logoTimer;
  Timer? countdownTimer;
  Timer? gameUpdateTimer;
  List<Timer> _scheduledNoteTimers = []; // Timers programados de notas
  Timer? _endGameTimer; // Timer para mostrar diálogo final

  // Pistones presionados
  Set<int> pressedPistons = <int>{};

  // Datos del juego
  List<GameNote> gameNotes = [];
  List<FallingGameNote> fallingNotes = [];
  int currentNoteIndex = 0;
  int gameStartTime = 0;
  String? lastPlayedNote; // Última nota tocada

  // Puntuación
  int correctNotes = 0;
  int totalNotes = 0;
  int currentScore = 0;
  int experiencePoints = 0;
  int perfectHits = 0;
  int goodHits = 0;
  int regularHits = 0;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isAudioPlaying = false;
  int audioDurationMs = 0;

  // Animación
  late AnimationController _noteAnimationController;
  late AnimationController _rotationController;

  // Configuración del juego (similar a begginer_game)
  static const double noteSpeed = 150.0; // pixels por segundo
  static const double hitTolerance = 80.0; // tolerancia para hits

  @override
  void initState() {
    super.initState();
    _setupScreen();
    _initializeAnimations();
    _loadGameData();
  }

  @override
  void dispose() {
    logoTimer?.cancel();
    countdownTimer?.cancel();
    gameUpdateTimer?.cancel();
    _endGameTimer?.cancel();
    feedbackTimer?.cancel();

    // Cancelar timers programados de notas
    for (final timer in _scheduledNoteTimers) {
      timer.cancel();
    }
    _scheduledNoteTimers.clear();

    _noteAnimationController.dispose();
    _rotationController.dispose();
    _audioPlayer.dispose();
    _restoreNormalMode();
    super.dispose();
  }

  Future<void> _setupScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreNormalMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  void _initializeAnimations() {
    _noteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );

    // Controlador para la rotación continua de la imagen de la partitura
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  // Cargar datos del juego desde la base de datos
  Future<void> _loadGameData() async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint('🎮 Cargando datos del juego educativo...');
      debugPrint('📋 Sublevel ID: ${widget.sublevelId}');

      // Cargar notas desde game_song_sublevel
      final response = await supabase
          .from('game_song_sublevel')
          .select(
              'id, start_time_ms, duration_ms, order_index, chromatic_note_id')
          .eq('sublevel_id', widget.sublevelId)
          .order('order_index');

      debugPrint('📦 Respuesta de la BD: $response');

      if (response != null && response is List && response.isNotEmpty) {
        debugPrint('📄 Total de registros: ${response.length}');

        gameNotes = response.map((item) {
          debugPrint('🎵 Procesando nota: $item');

          final noteId =
              item['id'] is int ? item['id'] : int.parse(item['id'].toString());
          final chromaticId = item['chromatic_note_id'] as int;

          return GameNote(
            id: noteId,
            startTimeMs: item['start_time_ms'] as int,
            durationMs: item['duration_ms'] as int,
            orderIndex: item['order_index'] as int,
            noteName: _getNoteNameFromId(chromaticId),
            requiredPistons: _getPistonsFromChromaticScale(chromaticId),
          );
        }).toList();

        totalNotes = gameNotes.length;
        debugPrint('✅ Cargadas ${gameNotes.length} notas del juego');

        // Iniciar el juego después de cargar
        setState(() {
          isLoadingData = false;
        });
        _startLogoTimer();
      } else {
        debugPrint('⚠️ No se encontraron notas para este subnivel');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('No hay notas configuradas para este juego')),
          );
          Navigator.pop(context, false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error al cargar datos del juego: $e');
      debugPrint('🔍 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el juego: $e')),
        );
        Navigator.pop(context, false);
      }
    }
  }

  // Obtener nombre de la nota basándose en el ID de chromatic_scale
  String _getNoteNameFromId(int chromaticNoteId) {
    // Escala cromática para trompeta desde Fa#3 (F#3)
    final Map<int, String> noteNames = {
      1: 'Fa#3', // F#3
      2: 'Sol3', // G3
      3: 'Sol#3', // G#3
      4: 'La3', // A3
      5: 'La#3', // A#3 / Sib3
      6: 'Si3', // B3
      7: 'Do4', // C4
      8: 'Do#4', // C#4 / Reb4
      9: 'Re4', // D4
      10: 'Re#4', // D#4 / Mib4
      11: 'Mi4', // E4
      12: 'Fa4', // F4
      13: 'Fa#4', // F#4
      14: 'Sol4', // G4
      15: 'Sol#4', // G#4
      16: 'La4', // A4
      17: 'La#4', // A#4
      18: 'Si4', // B4
      19: 'Do5', // C5
    };

    return noteNames[chromaticNoteId] ?? 'Nota $chromaticNoteId';
  }

  // Obtener pistones basándose en el ID de chromatic_scale
  // Escala cromática real de trompeta en Sib
  List<int> _getPistonsFromChromaticScale(int chromaticNoteId) {
    // Mapeo correcto de notas cromáticas a pistones de trompeta
    // Basado en digitación estándar de trompeta en Sib
    final Map<int, List<int>> pistonMap = {
      1: [2, 3], // F#3/Gb3 (Fa# - Pistones 2+3)
      2: [1, 3], // G3 (Sol - Pistones 1+3)
      3: [2, 3], // G#3/Ab3 (Sol# - Pistones 2+3)
      4: [1, 2], // A3 (La - Pistones 1+2)
      5: [1], // A#3/Bb3 (La# - Pistón 1)
      6: [2], // B3 (Si - Pistón 2)
      7: [], // C4 (Do - Sin pistones/Aire)
      8: [1, 2, 3], // C#4/Db4 (Do# - Pistones 1+2+3)
      9: [1, 3], // D4 (Re - Pistones 1+3)
      10: [2, 3], // D#4/Eb4 (Re# - Pistones 2+3)
      11: [1, 2], // E4 (Mi - Pistones 1+2)
      12: [1], // F4 (Fa - Pistón 1)
      13: [2], // F#4 (Fa# - Pistón 2)
      14: [], // G4 (Sol - Sin pistones)
      15: [2, 3], // G#4 (Sol# - Pistones 2+3)
      16: [1, 2], // A4 (La - Pistones 1+2)
      17: [1], // A#4 (La# - Pistón 1)
      18: [2], // B4 (Si - Pistón 2)
      19: [], // C5 (Do - Sin pistones)
    };

    return pistonMap[chromaticNoteId] ?? [];
  }

  void _startLogoTimer() {
    logoTimer = Timer(const Duration(seconds: 3), () {
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
    // Iniciar audio de fondo DURANTE el countdown
    if (widget.backgroundAudioUrl != null) {
      _playBackgroundAudio();
      debugPrint('🎵 Audio iniciado durante countdown');
    }

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownNumber > 1) {
        setState(() {
          countdownNumber--;
        });
      } else {
        timer.cancel();
        setState(() {
          showCountdown = false;
          isGameActive = true; // Activar juego DESPUÉS del countdown
        });
        // Iniciar notas y actualización DESPUÉS del countdown
        _spawnNotes();
        _updateGame();
      }
    });
  }

  void _startGame() {
    debugPrint('🎮 Juego educativo activo - ya se inició en countdown');
    // El audio y las notas ya se iniciaron durante el countdown
    // Solo iniciamos el loop de actualización si no se hizo ya
    if (gameUpdateTimer == null || !gameUpdateTimer!.isActive) {
      _updateGame();
    }
  }

  Future<void> _playBackgroundAudio() async {
    try {
      debugPrint('🔊 Iniciando reproducción de audio...');
      debugPrint('🔗 URL: ${widget.backgroundAudioUrl}');

      await _audioPlayer.play(UrlSource(widget.backgroundAudioUrl!));

      // Obtener duración del audio
      _audioPlayer.onDurationChanged.listen((Duration duration) {
        if (mounted) {
          setState(() {
            audioDurationMs = duration.inMilliseconds;
          });
          debugPrint('⏱️ Duración del audio: ${audioDurationMs}ms');
        }
      });

      // Detectar cuando termina el audio
      _audioPlayer.onPlayerComplete.listen((event) {
        debugPrint('🎵 Audio terminado - finalizando juego');
        if (mounted && isGameActive) {
          _endGame();
        }
      });

      if (mounted) {
        setState(() {
          isAudioPlaying = true;
        });
      }

      debugPrint('✅ Audio de fondo reproduciéndose');
    } catch (e) {
      debugPrint('❌ Error al reproducir audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir audio de fondo'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _spawnNotes() {
    gameStartTime = DateTime.now().millisecondsSinceEpoch;
    debugPrint('🕒 Tiempo de inicio del juego: $gameStartTime');
    debugPrint('🎵 Audio y notas sincronizados');

    final screenHeight = MediaQuery.of(context).size.height;
    final fallDistance = screenHeight * 1.3;
    final fallTimeMs = (fallDistance / noteSpeed * 1000).round();

    debugPrint(
        '📊 Fall time: ${fallTimeMs}ms para ${fallDistance.toStringAsFixed(1)}px');

    // Programar cada nota individualmente con Timer (sistema de begginer_game)
    for (int i = 0; i < gameNotes.length; i++) {
      final note = gameNotes[i];
      final spawnTime = note.startTimeMs - fallTimeMs;

      debugPrint('🎵 Nota ${i + 1}: ${note.noteName}');
      debugPrint('   - Debe tocarse en: ${note.startTimeMs}ms');
      debugPrint('   - Aparecerá en: ${spawnTime}ms');

      if (spawnTime > 0) {
        // Programar aparición futura
        final timer = Timer(Duration(milliseconds: spawnTime), () {
          if (mounted && isGameActive) {
            _spawnSingleNote(note, i);
          }
        });
        _scheduledNoteTimers.add(timer);
      } else if (spawnTime > -1000) {
        // Aparecer inmediatamente
        _spawnSingleNote(note, i);
      } else {
        debugPrint('   ⚠️ Nota omitida');
      }
    }

    debugPrint('🏁 Programadas ${gameNotes.length} notas');
  }

  void _spawnSingleNote(GameNote note, int index) {
    final currentGameTime =
        DateTime.now().millisecondsSinceEpoch - gameStartTime;
    final screenHeight = MediaQuery.of(context).size.height;
    final fallTimeMs = ((screenHeight * 1.3) / noteSpeed * 1000).round();

    // Calcular posición Y basada en el tiempo exacto
    final expectedAppearTime = note.startTimeMs - fallTimeMs;
    final timeDifference = currentGameTime - expectedAppearTime;
    final initialY = -screenHeight * 0.3;
    final adjustedY = initialY + (timeDifference * noteSpeed / 1000);

    debugPrint(
        '  - Expected: ${expectedAppearTime}ms, Current: ${currentGameTime}ms');
    debugPrint('  - Y position: ${adjustedY.toStringAsFixed(1)}');

    final fallingNote = FallingGameNote(
      gameNote: note,
      y: adjustedY,
      startTime:
          DateTime.now().millisecondsSinceEpoch.toDouble() - timeDifference,
      isHit: false,
      isMissed: false,
    );

    setState(() {
      fallingNotes.add(fallingNote);
    });

    debugPrint(
        '🎵 Nota spawneada: ${note.noteName} en Y=${adjustedY.toStringAsFixed(1)}');
  }

  void _updateGame() {
    gameUpdateTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      // Calcular zona de hit responsive
      final isTablet = screenWidth > 600;
      final isSmallPhone = screenHeight < 700;

      double hitZoneBottom;
      if (isSmallPhone) {
        hitZoneBottom = 110;
      } else if (isTablet) {
        hitZoneBottom = 150;
      } else {
        hitZoneBottom = 130;
      }

      final hitZoneY = screenHeight - hitZoneBottom;

      setState(() {
        for (var note in fallingNotes) {
          if (!note.isHit && !note.isMissed) {
            // Actualizar posición Y basada en velocidad
            final elapsed = currentTime - note.startTime;
            note.y = -screenHeight * 0.3 + (elapsed * noteSpeed / 1000);

            final distance = (note.y - hitZoneY).abs();

            // AUTO-HIT para notas de aire (sistema begginer_game)
            if (note.gameNote.requiredPistons.isEmpty &&
                note.y >= hitZoneY - 30 &&
                note.y <= hitZoneY + 30) {
              debugPrint('🌬️ AUTO-HIT: ${note.gameNote.noteName}');
              note.isHit = true;
              correctNotes++;
              totalNotes++;
              currentScore += 150;
              perfectHits++;
              _showFeedback('¡Perfecto!', Colors.green);
              continue;
            }

            // Verificar hits con pistones presionados
            if (note.gameNote.requiredPistons.isNotEmpty &&
                pressedPistons.isNotEmpty &&
                distance <= hitTolerance) {
              if (_exactPistonMatch(
                  note.gameNote.requiredPistons, pressedPistons)) {
                // Calcular calidad de timing
                String quality;
                Color feedbackColor;
                int points;
                double timingQuality;

                if (distance <= 15) {
                  quality = '¡Perfecto!';
                  feedbackColor = Colors.green;
                  points = 150;
                  timingQuality = 1.0;
                  perfectHits++;
                } else if (distance <= 35) {
                  quality = '¡Bien!';
                  feedbackColor = Colors.blue;
                  points = 100;
                  timingQuality = 0.7;
                  goodHits++;
                } else {
                  quality = 'Regular';
                  feedbackColor = Colors.orange;
                  points = 50;
                  timingQuality = 0.3;
                  regularHits++;
                }

                note.isHit = true;
                correctNotes++;
                totalNotes++;
                currentScore += points;
                lastPlayedNote = note.gameNote.noteName;
                debugPrint(
                    '✅ $quality: ${note.gameNote.noteName} (d=${distance.toStringAsFixed(1)})');
                _showFeedback(quality, feedbackColor);
                HapticFeedback.mediumImpact();
                continue;
              }
            }

            // Nota perdida
            if (note.y > hitZoneY + hitTolerance + 50) {
              note.isMissed = true;
              totalNotes++;
              _showFeedback('¡Fallaste!', Colors.red);
              HapticFeedback.heavyImpact();
              debugPrint('❌ Perdida: ${note.gameNote.noteName}');
            }
          }
        }

        // Limpiar notas fuera de pantalla
        fallingNotes.removeWhere(
            (note) => note.y > hitZoneY + 200 && (note.isHit || note.isMissed));
      });

      _checkGameEnd();
    });
  }

  void _checkGameEnd() {
    if (gameNotes.isEmpty) return;

    final currentGameTime =
        DateTime.now().millisecondsSinceEpoch - gameStartTime;
    final lastNoteTime = gameNotes.last.startTimeMs;
    final lastNoteDuration = gameNotes.last.durationMs;

    // Terminar cuando acabe la duración completa de la última nota
    final expectedEndTime = lastNoteTime + lastNoteDuration;
    final gameTimePassed = currentGameTime >= expectedEndTime;

    if (gameTimePassed) {
      debugPrint(
          '⏱️ Juego terminado: ${currentGameTime}ms >= ${expectedEndTime}ms');
      _endGame();
    }
  }

  void _endGame() {
    if (!isGameActive) return;

    setState(() {
      isGameActive = false;
      isGamePaused = false;
    });

    gameUpdateTimer?.cancel();
    _audioPlayer.stop();

    // Calcular puntuación y experiencia
    final accuracy = totalNotes > 0 ? correctNotes / totalNotes : 0;
    experiencePoints = widget.experiencePoints > 0
        ? (widget.experiencePoints * accuracy).round()
        : (correctNotes * 10 * accuracy).round();

    debugPrint('🎯 Juego finalizado:');
    debugPrint('   - Correctas: $correctNotes/$totalNotes');
    debugPrint('   - Precisión: ${(accuracy * 100).toStringAsFixed(1)}%');
    debugPrint('   - Puntos XP: $experiencePoints');

    // Esperar 2 segundos antes de mostrar diálogo (como begginer_game)
    _endGameTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _showResultsDialog();
      }
    });
  }

  void _pauseGame() {
    if (!isGameActive || isGamePaused) return;

    setState(() {
      isGamePaused = true;
    });

    gameUpdateTimer?.cancel();
    _audioPlayer.pause();

    // Mostrar diálogo de pausa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.pause_rounded, color: Colors.blue, size: 30),
            SizedBox(width: 10),
            Text('Juego en Pausa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $currentScore'),
            Text('Notas correctas: $correctNotes/$totalNotes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeGame();
            },
            child: Text('Reanudar',
                style: TextStyle(color: Colors.green, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restartGame();
            },
            child: Text('Reiniciar',
                style: TextStyle(color: Colors.orange, fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Salir',
                style: TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _resumeGame() {
    if (!isGamePaused) return;

    setState(() {
      isGamePaused = false;
    });

    _audioPlayer.resume();
    _updateGame();
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
      perfectHits = 0;
      goodHits = 0;
      regularHits = 0;
      currentNoteIndex = 0;
      pressedPistons.clear();
      feedbackText = null;
      feedbackColor = null;
      feedbackOpacity = 0.0;
    });

    // Cancelar TODOS los timers
    gameUpdateTimer?.cancel();
    feedbackTimer?.cancel();
    countdownTimer?.cancel();
    _endGameTimer?.cancel();
    _audioPlayer.stop();

    // Cancelar todos los timers programados de notas
    for (final timer in _scheduledNoteTimers) {
      timer.cancel();
    }
    _scheduledNoteTimers.clear();

    // Reiniciar tiempo de inicio
    gameStartTime = 0;

    // Iniciar countdown nuevamente
    setState(() {
      showCountdown = true;
      countdownNumber = 3;
    });
    _startCountdown();
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              SizedBox(width: 12),
              Text('¡Juego Completado!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Puntuación: $currentScore',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Notas correctas: $correctNotes/$totalNotes'),
              SizedBox(height: 4),
              Text(
                'Precisión: ${totalNotes > 0 ? ((correctNotes / totalNotes * 100).toStringAsFixed(1)) : "0"}%',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 12),
              // Desglose de calidad
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars, color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text('Perfectos:', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text('$perfectHits',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Text('Buenos:', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text('$goodHits',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.adjust, color: Colors.orange, size: 18),
                            SizedBox(width: 6),
                            Text('Regulares:', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text('$regularHits',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: Colors.amber[700], size: 24),
                    SizedBox(width: 8),
                    Text(
                      '+$experiencePoints XP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Guardar puntos de experiencia si hubo notas correctas
                if (experiencePoints > 0) {
                  await _saveExperiencePoints();
                }
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(
                    context, correctNotes > 0); // Volver con resultado
              },
              child: Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  // Guardar puntos de experiencia en la base de datos
  Future<void> _saveExperiencePoints() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint('⚠️ Usuario no autenticado');
        return;
      }

      if (experiencePoints <= 0) {
        debugPrint('⚠️ No hay puntos para guardar');
        return;
      }

      debugPrint('💾 Guardando $experiencePoints puntos XP...');

      // 1. Actualizar en tabla de perfil del usuario
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

            debugPrint(
                '✅ Perfil actualizado en $table: $currentXP → $newXP XP');
            profileUpdated = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      // 2. Actualizar en users_games
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
        final newCoins = currentCoins + (experiencePoints ~/ 10);

        await supabase.from('users_games').update({
          'points_xp_totally': newTotal,
          'points_xp_weekend': newWeekend,
          'coins': newCoins,
        }).eq('user_id', user.id);

        debugPrint(
            '✅ users_games actualizado: +$experiencePoints XP, +${experiencePoints ~/ 10} monedas');
      } else {
        final newCoins = experiencePoints ~/ 10;

        await supabase.from('users_games').insert({
          'user_id': user.id,
          'nickname': 'Usuario',
          'points_xp_totally': experiencePoints,
          'points_xp_weekend': experiencePoints,
          'coins': newCoins,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Nuevo registro en users_games creado');
      }

      debugPrint('✅ Guardado completado exitosamente');
    } catch (e) {
      debugPrint('❌ Error al guardar puntos: $e');
    }
  }

  void _checkNoteHit() {
    // Esta función ahora solo sirve para trigger inmediato al presionar
    // La verificación continua se hace en _updateGame()
    // Solo agregamos vibración háptica para feedback inmediato
    if (pressedPistons.isNotEmpty) {
      HapticFeedback.lightImpact();
    }
  }

  void _checkOpenNotes() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    double hitZoneBottom;
    if (isSmallPhone) {
      hitZoneBottom = 110;
    } else if (isTablet) {
      hitZoneBottom = 150;
    } else {
      hitZoneBottom = 130;
    }

    final hitZoneY = screenHeight - hitZoneBottom;

    for (var note in fallingNotes) {
      if (!note.isHit && !note.isMissed) {
        // Verificar si es una nota de aire (sin pistones)
        if (note.gameNote.requiredPistons.isEmpty) {
          final distance = (note.y - hitZoneY).abs();

          if (distance <= 30) {
            setState(() {
              note.isHit = true;
              correctNotes++;
              totalNotes++;
              currentScore += 100;
            });
            debugPrint('🌬️ Nota de aire correcta: ${note.gameNote.noteName}');
            _showFeedback('¡Correcto!', Colors.green);
            return;
          }
        }
      }
    }
  }

  bool _exactPistonMatch(List<int> required, Set<int> pressed) {
    final requiredSet = required.toSet();
    if (requiredSet.isEmpty) return pressed.isEmpty;
    return requiredSet.length == pressed.length &&
        requiredSet.every((p) => pressed.contains(p));
  }

  String? feedbackText;
  Color? feedbackColor;
  double feedbackOpacity = 0.0;
  Timer? feedbackTimer;

  void _showFeedback(String text, Color color) {
    setState(() {
      feedbackText = text;
      feedbackColor = color;
      feedbackOpacity = 1.0;
    });

    feedbackTimer?.cancel();
    feedbackTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          feedbackOpacity = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return _buildLoadingScreen();
    }

    if (showLogo) {
      return _buildLogoScreen();
    }

    if (showCountdown) {
      return _buildCountdownScreen();
    }

    return _buildGameScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Cargando juego...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Prepárate para tocar',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Countdown principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$countdownNumber',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                // Indicador de que el audio ya está sonando
                if (isAudioPlaying)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '¡Pista sonando!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Mensaje en la parte inferior
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              'Prepárate para tocar...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Partitura de fondo (más visible)
          if (widget.sheetMusicImageUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.4, // Más visible
                child: CachedNetworkImage(
                  imageUrl: widget.sheetMusicImageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(Icons.music_note,
                        size: 50, color: Colors.grey[800]),
                  ),
                ),
              ),
            ),

          // Área del juego con gradiente más suave
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildGameArea(),
                ),
              ],
            ),
          ),

          // Feedback visual
          if (feedbackText != null) _buildFeedbackEffects(),

          // Controles de pistones en la parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPistonControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final accuracy = totalNotes > 0 ? (correctNotes / totalNotes * 100) : 100.0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón atrás
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                _pauseGame();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => AlertDialog(
                    title: Text('Salir del juego'),
                    content: Text('¿Deseas salir del juego educativo?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resumeGame();
                        },
                        child: Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child:
                            Text('Salir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
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
          // Imagen de la partitura rotando (similar a begginer_game)
          if (widget.sheetMusicImageUrl != null)
            RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.sheetMusicImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Icon(
                      Icons.music_note,
                      color: Colors.blue,
                      size: 30,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.music_note,
                      color: Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(width: 12),

          // Información del juego
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '$correctNotes/$totalNotes',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.analytics, color: Colors.blue, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '${accuracy.toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Puntuación
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '$currentScore',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6),
              // Barra de progreso
              Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: audioDurationMs > 0
                      ? ((DateTime.now().millisecondsSinceEpoch -
                                  gameStartTime) /
                              audioDurationMs)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12),

          // Botón de pausa
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: IconButton(
              icon: Icon(Icons.pause, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  isGamePaused = !isGamePaused;
                });
                if (isGamePaused) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.resume();
                }
              },
            ),
          ),
        ],
      ),
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

          // Notas cayendo
          ..._buildFallingNotes(),

          // Efectos de feedback
          if (feedbackText != null) _buildFeedbackEffects(),
        ],
      ),
    );
  }

  Widget _buildPistonGuides() {
    return Positioned.fill(
      child: CustomPaint(
        painter: PistonGuidesPainter(),
      ),
    );
  }

  Widget _buildHitZone() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Detectar si es tablet o celular para ajustar posición
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Posición responsive de la zona de hit
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
          // Hacer la zona visible
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

  List<Widget> _buildFallingNotes() {
    return fallingNotes.map((note) => _buildNote(note)).toList();
  }

  Widget _buildNote(FallingGameNote note) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pistons = note.gameNote.requiredPistons;

    // Calcular posición X basada en los pistones
    double centerX;
    if (pistons.isEmpty) {
      // Nota de aire - centro
      centerX = screenWidth / 2;
    } else if (pistons.length == 1) {
      // Un solo pistón
      centerX = _getPistonX(pistons[0], screenWidth);
    } else {
      // Múltiples pistones - promedio
      final positions = pistons.map((p) => _getPistonX(p, screenWidth));
      centerX = positions.reduce((a, b) => a + b) / positions.length;
    }

    // Color basado en si fue tocada correctamente
    Color noteColor = note.isHit
        ? Colors.green.withOpacity(0.7)
        : note.isMissed
            ? Colors.red.withOpacity(0.7)
            : Colors.blue;

    return Positioned(
      left: centerX - 30,
      top: note.y,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: noteColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: noteColor.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            note.gameNote.noteName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  double _getPistonX(int pistonNumber, double screenWidth) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Tamaños responsive para los pistones (mismo que en _buildPistonControls)
    final double pistonSize;
    final double realPistonSeparation;

    if (isSmallPhone) {
      pistonSize = 75.0;
      realPistonSeparation = 15.0;
    } else if (isTablet) {
      pistonSize = 100.0;
      realPistonSeparation = 25.0;
    } else {
      pistonSize = 90.0;
      realPistonSeparation = 20.0;
    }

    const double realPistonDiameter = 18.0;

    // Calcular la separación proporcional en pixels
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    // Ancho total del contenedor de pistones
    final double totalPistonWidth =
        (pistonSize * 3) + (pixelSeparation * 2) + 40; // +40 por padding
    final double startX =
        (screenWidth - totalPistonWidth) / 2 + 20; // +20 por padding izquierdo

    // Calcular posición X para cada pistón
    double pistonX;
    if (pistonNumber == 1) {
      pistonX = startX + (pistonSize / 2);
    } else if (pistonNumber == 2) {
      pistonX = startX + pistonSize + pixelSeparation + (pistonSize / 2);
    } else {
      pistonX =
          startX + (pistonSize * 2) + (pixelSeparation * 2) + (pistonSize / 2);
    }

    return pistonX;
  }

  Widget _buildFeedbackEffects() {
    return Center(
      child: AnimatedOpacity(
        opacity: feedbackOpacity,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: feedbackColor?.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            feedbackText ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPistonControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Tamaños más grandes para los pistones
    final double pistonSize;
    final double realPistonSeparation;

    if (isSmallPhone) {
      pistonSize = 75.0; // Más grandes
      realPistonSeparation = 15.0;
    } else if (isTablet) {
      pistonSize = 100.0; // Mucho más grandes en tablets
      realPistonSeparation = 25.0;
    } else {
      pistonSize = 90.0; // Más grandes que antes
      realPistonSeparation = 20.0;
    }

    const double realPistonDiameter = 18.0; // mm en trompeta real

    // Calcular la separación proporcional en pixels
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isSmallPhone ? 20 : 25,
            vertical: isSmallPhone ? 12 : 15),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
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
      ),
    );
  }

  Widget _buildPistonButton(int pistonNumber, double pistonSize) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallPhone = screenHeight < 700;
    final isPressed = pressedPistons.contains(pistonNumber);

    // Tamaño de fuente responsive
    final double fontSize = isSmallPhone ? 22.0 : 28.0;

    return GestureDetector(
      onTapDown: (_) {
        // Vibración háptica al presionar
        HapticFeedback.lightImpact();
        setState(() {
          pressedPistons.add(pistonNumber);
        });
        _checkNoteHit();
      },
      onTapUp: (_) {
        setState(() {
          pressedPistons.remove(pistonNumber);
        });
      },
      onTapCancel: () {
        setState(() {
          pressedPistons.remove(pistonNumber);
        });
      },
      child: AnimatedScale(
        scale: isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: pistonSize,
          height: pistonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(pistonSize / 2),
            boxShadow: [
              BoxShadow(
                color: isPressed
                    ? Colors.green.withOpacity(0.6)
                    : Colors.blue.withOpacity(0.3),
                blurRadius: isPressed ? 20 : 10,
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
      ),
    );
  }
}

// Clase para representar una nota del juego desde la base de datos
class GameNote {
  final int id;
  final int startTimeMs;
  final int durationMs;
  final int orderIndex;
  final String noteName;
  final List<int> requiredPistons;

  GameNote({
    required this.id,
    required this.startTimeMs,
    required this.durationMs,
    required this.orderIndex,
    required this.noteName,
    required this.requiredPistons,
  });
}

// Clase para notas cayendo en el juego
class FallingGameNote {
  final GameNote gameNote;
  double y;
  final double startTime;
  bool isHit;
  bool isMissed;

  FallingGameNote({
    required this.gameNote,
    required this.y,
    required this.startTime,
    required this.isHit,
    required this.isMissed,
  });
}

// CustomPainter para las líneas guía (igual que begginer_game)
class PistonGuidesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Calcular las posiciones reales de los pistones (tamaño actualizado)
    const double pistonSize = 90.0; // Mismo tamaño que en _buildPistonControls
    const double realPistonSeparation = 20.0;
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
