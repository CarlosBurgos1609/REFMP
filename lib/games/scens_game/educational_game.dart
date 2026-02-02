// ignore_for_file: unused_local_variable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:refmp/games/game/dialogs/pause_dialog.dart';
import 'package:refmp/games/game/dialogs/back_dialog.dart';

/// Juego educativo que muestra una partitura y hace caer notas
/// El estudiante debe presionar los pistones correctos sin reproducir sonido
class EducationalGamePage extends StatefulWidget {
  final String sublevelId;
  final String title;
  final String? sheetMusicImageUrl;
  final String? backgroundAudioUrl;
  final int experiencePoints; // Puntos configurados en la base de datos
  final int coins; // Monedas configuradas en la base de datos

  const EducationalGamePage({
    super.key,
    required this.sublevelId,
    required this.title,
    this.sheetMusicImageUrl,
    this.backgroundAudioUrl,
    this.experiencePoints = 0,
    this.coins = 0,
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

  // Sombras de pistones (indica qué pistones deben presionarse ahora)
  Map<int, Color> pistonShadows = {}; // {pistonNumber: shadowColor}

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

  // Control de fin de juego
  bool _isCheckingGameEnd = false;

  // Animación
  late AnimationController _noteAnimationController;
  late AnimationController _rotationController;

  // Configuración del juego (similar a begginer_game)
  static const double noteSpeed = 150.0; // pixels por segundo
  // ignore: unused_field
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

      // ignore: unnecessary_null_comparison, unnecessary_type_check
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

        // Ordenar notas por tiempo de inicio (CRÍTICO)
        gameNotes.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));

        totalNotes = gameNotes.length;
        debugPrint('✅ Cargadas ${gameNotes.length} notas del juego');
        debugPrint(
            '⏱️ Primera nota: ${gameNotes.first.startTimeMs}ms, Última nota: ${gameNotes.last.startTimeMs}ms');

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

  Future<void> _playBackgroundAudio() async {
    try {
      debugPrint('🔊 Iniciando reproducción de audio...');
      debugPrint('🔗 URL: ${widget.backgroundAudioUrl}');

      // Configurar modo de reproducción
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      await _audioPlayer.play(UrlSource(widget.backgroundAudioUrl!));
      debugPrint('✅ Comando de reproducción enviado');

      // Obtener duración del audio (solo una vez)
      _audioPlayer.onDurationChanged.listen((Duration duration) {
        if (mounted && audioDurationMs == 0) {
          setState(() {
            audioDurationMs = duration.inMilliseconds;
          });
          debugPrint('⏱️ Duración del audio: ${audioDurationMs}ms');
        }
      });

      // Detectar cuando termina el audio (evitar múltiples llamadas)
      _audioPlayer.onPlayerComplete.listen((event) {
        debugPrint('🎵 Audio terminado - finalizando juego');
        if (mounted && isGameActive && !isGamePaused) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted && isGameActive) {
              _endGame();
            }
          });
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
    totalNotes = gameNotes.length; // Inicializar el total de notas
    debugPrint('🕒 Tiempo de inicio del juego: $gameStartTime');
    debugPrint('🎵 Audio y notas sincronizados');
    debugPrint('📊 Total de notas a tocar: $totalNotes');

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
      } else {
        // Aparecer inmediatamente (incluso con tiempo negativo)
        _spawnSingleNote(note, i);
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

      // Calcular zona de hit responsive - MOVIDA MÁS ARRIBA
      final isTablet = screenWidth > 600;
      final isSmallPhone = screenHeight < 700;

      // Zona de hit en el centro-superior de la pantalla (mucho más arriba que los pistones)
      final hitZoneHeight = isSmallPhone ? 100.0 : (isTablet ? 140.0 : 120.0);

      // Colocar la zona de hit en el centro de la pantalla
      // En lugar de calcular desde abajo, la ponemos en el centro
      final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2);
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
          final pistons = note.gameNote.requiredPistons;
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

      setState(() {
        for (var note in fallingNotes) {
          if (!note.isHit && !note.isMissed) {
            // Actualizar posición Y basada en velocidad
            final elapsed = currentTime - note.startTime;
            note.y = -screenHeight * 0.3 + (elapsed * noteSpeed / 1000);

            final noteBottom = note.y + 60;
            final noteTop = note.y;
            final noteCenter = note.y + 30;

            // AUTO-HIT para notas de aire - solo cuando esté en el CENTRO del hit zone
            if (note.gameNote.requiredPistons.isEmpty &&
                noteBottom >= hitZoneY &&
                noteTop <= hitZoneY + hitZoneHeight) {
              // Verificar si está en el centro de la zona de hit (igual que PERFECT)
              final distanceFromCenter = (noteCenter - hitZoneCenterY).abs();
              final perfectZone =
                  hitZoneHeight * 0.25; // Solo en el 25% central

              if (distanceFromCenter < perfectZone) {
                // Solo hacer auto-hit cuando esté en el centro
                debugPrint(
                    '🌬️ AUTO-HIT: ${note.gameNote.noteName} - Centro alcanzado');
                note.isHit = true;
                correctNotes++;
                currentScore += 40;
                perfectHits++;
                _showFeedback('¡Perfecto!', Colors.green);
                HapticFeedback.mediumImpact();
                continue;
              }
            }

            // Verificar hits con pistones presionados SOLO si la nota está en la zona de hit
            if (note.gameNote.requiredPistons.isNotEmpty &&
                pressedPistons.isNotEmpty &&
                noteBottom >= hitZoneY &&
                noteTop <= hitZoneY + hitZoneHeight) {
              if (_exactPistonMatch(
                  note.gameNote.requiredPistons, pressedPistons)) {
                // HIT! Marcar como acertada
                note.isHit = true;
                correctNotes++;

                // Calcular tipo de hit según posición respecto al CENTRO de la zona
                final distanceFromCenter = (noteCenter - hitZoneCenterY).abs();
                final perfectZone =
                    hitZoneHeight * 0.25; // 25% del centro es perfect
                final goodZone = hitZoneHeight * 0.4; // 40% es good

                if (distanceFromCenter < perfectZone) {
                  // PERFECT - en el centro sin tocar líneas
                  perfectHits++;
                  currentScore += 40;
                  _showFeedback('¡PERFECT!', Colors.green);
                } else if (distanceFromCenter < goodZone) {
                  // GOOD - cerca del centro
                  goodHits++;
                  currentScore += 25;
                  _showFeedback('¡Bien!', Colors.lightGreen);
                } else {
                  // REGULAR - en los bordes de la zona
                  regularHits++;
                  currentScore += 15;
                  _showFeedback('Regular', Colors.orange);
                }

                lastPlayedNote = note.gameNote.noteName;
                HapticFeedback.mediumImpact();
                debugPrint(
                    '✅ Hit: ${note.gameNote.noteName} - Distancia del centro: ${distanceFromCenter.toStringAsFixed(1)}px');
              }
            }

            // Verificar si la nota pasó la zona de hit (miss)
            if (noteTop > hitZoneY + hitZoneHeight && !note.isHit) {
              note.isMissed = true;
              _showFeedback('Miss', Colors.red);
              HapticFeedback.heavyImpact();
              debugPrint(
                  '❌ Miss: ${note.gameNote.noteName} (${note.gameNote.requiredPistons})');
            }
          }
        }

        // Limpiar notas fuera de pantalla y completadas
        fallingNotes.removeWhere((note) {
          // Eliminar si está muy debajo de la pantalla
          final isFarBelowScreen = note.y > screenHeight + 50;
          // O si ya fue procesada (tocada o perdida) - eliminar inmediatamente
          final isProcessed = note.isHit || note.isMissed;
          return isFarBelowScreen || isProcessed;
        });
      });

      _checkGameEnd();
    });
  }

  void _checkGameEnd() {
    if (gameNotes.isEmpty || _isCheckingGameEnd) return;

    final currentGameTime =
        DateTime.now().millisecondsSinceEpoch - gameStartTime;
    final lastNoteTime = gameNotes.last.startTimeMs;
    final lastNoteDuration = gameNotes.last.durationMs;

    // Terminar cuando acabe la duración completa de la última nota
    final expectedEndTime = lastNoteTime + lastNoteDuration;
    final gameTimePassed = currentGameTime >= expectedEndTime;

    if (gameTimePassed && !_isCheckingGameEnd) {
      _isCheckingGameEnd = true;
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
      _isCheckingGameEnd = false;
    });

    gameUpdateTimer?.cancel();

    // Detener audio de forma segura
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ Error al detener audio: $e');
    }

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
    _endGameTimer?.cancel();
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

    // Mostrar diálogo de pausa con el diseño correcto
    showPauseDialog(
      context,
      widget.title,
      _resumeGame,
      _restartGame,
      onResumeFromBack: _resumeGame,
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
      _isCheckingGameEnd = false;
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
      pistonShadows.clear();
      feedbackText = null;
      feedbackColor = null;
      feedbackOpacity = 0.0;
      lastPlayedNote = null;
      audioDurationMs = 0;
      isAudioPlaying = false;
    });

    // Cancelar TODOS los timers
    gameUpdateTimer?.cancel();
    feedbackTimer?.cancel();
    countdownTimer?.cancel();
    _endGameTimer?.cancel();

    // Detener audio de forma segura
    try {
      _audioPlayer.stop();
    } catch (e) {
      debugPrint('⚠️ Error al detener audio en restart: $e');
    }

    // Cancelar todos los timers programados de notas
    for (final timer in _scheduledNoteTimers) {
      timer.cancel();
    }
    _scheduledNoteTimers.clear();

    // Reiniciar tiempo de inicio y duración de audio
    gameStartTime = 0;
    audioDurationMs = 0;

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
        // Determinar tema (claro u oscuro)
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icono de check animado
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    '¡Felicitaciones!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Has completado el juego',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Estadísticas en una fila
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey[800]?.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey[600]!.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Experiencia
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.star,
                            iconColor: Colors.purple,
                            title: 'Experiencia',
                            value: '$experiencePoints',
                            valueColor: Colors.purple,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Monedas
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.monetization_on,
                            iconColor: Colors.amber,
                            title: 'Monedas',
                            value: '${widget.coins}',
                            valueColor: Colors.amber,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Notas acertadas
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.check_rounded,
                            iconColor: Colors.green,
                            title: 'Correctas',
                            value: '$correctNotes',
                            valueColor: Colors.green,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Notas falladas
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.close_rounded,
                            iconColor: Colors.red,
                            title: 'Fallos',
                            value: '${totalNotes - correctNotes}',
                            valueColor: Colors.red,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón Continuar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      // Guardar puntos de experiencia si hubo notas correctas
                      if (experiencePoints > 0) {
                        await _saveExperiencePoints();
                      }
                      // Cerrar diálogo primero
                      if (mounted) {
                        Navigator.of(context).pop(); // Cerrar diálogo
                        // Pequeño delay para asegurar que el contexto es estable
                        await Future.delayed(Duration(milliseconds: 100));
                        // Ahora cerrar la página del juego
                        if (mounted) {
                          Navigator.of(context).pop(correctNotes > 0);
                        }
                      }
                    },
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  // Widget helper para crear tarjetas de estadísticas
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color valueColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(height: 4),

          // Título
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Valor
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
                showBackDialog(
                  context,
                  widget.title,
                  onCancel: _resumeGame,
                  onRestart: _restartGame,
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

          // Imagen de la partitura rotando
          if (widget.sheetMusicImageUrl != null)
            RotationTransition(
              turns: _rotationController,
              child: Container(
                width: 50,
                height: 50,
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
                      size: 25,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.music_note,
                      color: Colors.grey,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(width: 12),

          // Título centrado en el AppBar
          Expanded(
            child: Center(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Monedas y XP en fila horizontal
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Monedas
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${widget.coins}',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Experiencia
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.purple, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${widget.experiencePoints}',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Stack(
      children: [
        // Área principal de juego
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Stack(
            children: [
              // Líneas guía
              _buildPistonGuides(),
              // Zona de hit
              _buildHitZone(),
              // Notas cayendo
              ..._buildFallingNotes(),
            ],
          ),
        ),

        // Contenedor de nota musical (lado izquierdo)
        if (lastPlayedNote != null) _buildMusicalNoteDisplay(),

        // Barra de progreso vertical (lado derecho)
        _buildVerticalProgressBar(),

        // Feedback de texto simple (debajo del header)
        if (feedbackText != null) _buildSimpleFeedback(),
      ],
    );
  }

  // Contenedor de nota musical tocada
  Widget _buildMusicalNoteDisplay() {
    return Positioned(
      left: 20,
      top: MediaQuery.of(context).size.height / 2 - 60,
      child: AnimatedOpacity(
        opacity: lastPlayedNote != null ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade700.withOpacity(0.9),
                Colors.blue.shade900.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                lastPlayedNote ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Barra de progreso vertical del rendimiento
  Widget _buildVerticalProgressBar() {
    final accuracy = totalNotes > 0 ? (correctNotes / totalNotes) : 1.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final barHeight = screenHeight * 0.5;

    return Positioned(
      right: 20,
      top: (screenHeight - barHeight) / 2,
      child: Container(
        width: 50,
        height: barHeight,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            // Sección superior - Indicador de progreso
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Fondo
                      Container(
                        color: Colors.grey.shade800,
                      ),
                      // Barra de progreso
                      FractionallySizedBox(
                        heightFactor: accuracy,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                accuracy >= 0.7
                                    ? Colors.green
                                    : accuracy >= 0.4
                                        ? Colors.orange
                                        : Colors.red,
                                accuracy >= 0.7
                                    ? Colors.green.shade300
                                    : accuracy >= 0.4
                                        ? Colors.orange.shade300
                                        : Colors.red.shade300,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Porcentaje
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${(accuracy * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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

    // Altura de la zona de hit (debe coincidir con la lógica de detección)
    final hitZoneHeight = isSmallPhone ? 100.0 : (isTablet ? 140.0 : 120.0);

    // Posición en el centro de la pantalla (debe coincidir con la lógica de detección)
    final hitZoneY = (screenHeight / 2) - (hitZoneHeight / 2);

    return Positioned(
      top: hitZoneY,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallPhone = screenHeight < 700;

    // Tamaños responsive de pistones
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
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;
    final double totalPistonWidth =
        (pistonSize * 3) + (pixelSeparation * 2) + 40;
    final double startX = (screenWidth - totalPistonWidth) / 2 + 20;

    return fallingNotes
        .map((note) =>
            _buildRectangularNote(note, startX, pistonSize, pixelSeparation))
        .toList();
  }

  // Construir nota rectangular que abarca los pistones requeridos
  Widget _buildRectangularNote(FallingGameNote note, double startX,
      double pistonSize, double pixelSeparation) {
    final pistons = note.gameNote.requiredPistons;

    // Si es nota de aire (sin pistones), mostrar barra gris
    if (pistons.isEmpty) {
      final totalWidth = (pistonSize * 3) + (pixelSeparation * 2);
      final leftX = startX;
      return _buildOpenNote(note, leftX, totalWidth);
    }

    final sortedPistons = List<int>.from(pistons)..sort();

    // Si son pistones consecutivos, crear barra continua
    if (sortedPistons.length > 1 && _arePistonsConsecutive(sortedPistons)) {
      final firstPiston = sortedPistons.first;
      final lastPiston = sortedPistons.last;
      final leftX =
          _getPistonCenterX(firstPiston, startX, pistonSize, pixelSeparation) -
              pistonSize / 2;
      final rightX =
          _getPistonCenterX(lastPiston, startX, pistonSize, pixelSeparation) +
              pistonSize / 2;
      final width = rightX - leftX;

      return Positioned(
        left: leftX,
        top: note.y,
        child: _buildRectangularNoteWidget(note, width),
      );
    } else {
      // Pistones no consecutivos - crear notas individuales
      return Stack(
        children: sortedPistons.map((piston) {
          final centerX =
              _getPistonCenterX(piston, startX, pistonSize, pixelSeparation);
          return Positioned(
            left: centerX - pistonSize / 2,
            top: note.y,
            child: _buildSinglePistonNote(note, pistonSize),
          );
        }).toList(),
      );
    }
  }

  // Verificar si los pistones son consecutivos
  bool _arePistonsConsecutive(List<int> sortedPistons) {
    for (int i = 0; i < sortedPistons.length - 1; i++) {
      if (sortedPistons[i + 1] - sortedPistons[i] != 1) {
        return false;
      }
    }
    return true;
  }

  // Obtener posición X del centro de un pistón
  double _getPistonCenterX(int pistonNumber, double startX, double pistonSize,
      double pixelSeparation) {
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

  // Construir widget de nota rectangular
  Widget _buildRectangularNoteWidget(FallingGameNote note, double width) {
    Color noteColor = note.isHit
        ? Colors.green.withOpacity(0.8)
        : note.isMissed
            ? Colors.red.withOpacity(0.8)
            : Colors.blue;

    return Container(
      width: width,
      height: 60,
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(8),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Construir nota individual
  Widget _buildSinglePistonNote(FallingGameNote note, double size) {
    Color noteColor = note.isHit
        ? Colors.green.withOpacity(0.8)
        : note.isMissed
            ? Colors.red.withOpacity(0.8)
            : Colors.blue;

    return Container(
      width: size,
      height: 60,
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(8),
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
    );
  }

  // Construir nota de aire (barra gris)
  Widget _buildOpenNote(FallingGameNote note, double leftX, double totalWidth) {
    return Positioned(
      left: leftX,
      top: note.y,
      child: Container(
        width: totalWidth,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Center(
          child: Text(
            'AIRE',
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

  // Widget de feedback simple debajo del header
  Widget _buildSimpleFeedback() {
    return Positioned(
      top: 80, // Debajo del header
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: feedbackOpacity,
          duration: Duration(milliseconds: 300),
          child: Text(
            feedbackText ?? '',
            style: TextStyle(
              color: feedbackColor ?? Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
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
    final hasShadow = pistonShadows.containsKey(pistonNumber);
    final shadowColor = pistonShadows[pistonNumber];

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
          duration: const Duration(milliseconds: 200),
          width: pistonSize,
          height: pistonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(pistonSize / 2),
            // Borde brillante cuando debe presionarse
            border: hasShadow && !isPressed
                ? Border.all(
                    color: Colors.blue.shade300,
                    width: 4,
                  )
                : null,
            boxShadow: [
              // Sombra principal
              BoxShadow(
                color: isPressed
                    ? Colors.green.withOpacity(0.6)
                    : hasShadow
                        ? Colors.blue.withOpacity(0.8)
                        : Colors.blue.withOpacity(0.3),
                blurRadius: isPressed ? 20 : (hasShadow ? 25 : 10),
                offset: const Offset(0, 5),
                spreadRadius: hasShadow ? 3 : 0,
              ),
              // Sombra adicional animada cuando debe presionarse
              if (hasShadow && !isPressed)
                BoxShadow(
                  color: Colors.blue.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 0),
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Stack(
            children: [
              // Overlay de color cuando debe presionarse
              if (hasShadow && !isPressed)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(pistonSize / 2),
                    color: Colors.blue.withOpacity(0.4),
                  ),
                ),
              // Imagen del pistón
              ClipRRect(
                borderRadius: BorderRadius.circular(pistonSize / 2),
                child: ColorFiltered(
                  colorFilter: hasShadow && !isPressed
                      ? ColorFilter.mode(
                          Colors.blue.withOpacity(0.3),
                          BlendMode.srcATop,
                        )
                      : ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: Image.asset(
                    'assets/images/piston.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: hasShadow && !isPressed
                              ? Colors.blue.shade400
                              : Colors.blue,
                          borderRadius: BorderRadius.circular(pistonSize / 2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: hasShadow && !isPressed
                                ? [
                                    Colors.blue.shade300,
                                    Colors.blue.shade600,
                                  ]
                                : [
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF1E40AF),
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
                              shadows: hasShadow
                                  ? [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
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
