import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../game/dialogs/back_dialog.dart';
import '../game/dialogs/pause_dialog.dart';
// import '../game/dialogs/congratulations_dialog.dart';

// Clase para representar una nota que cae
class FallingNote {
  final int piston; // 1, 2, o 3
  double y; // Posición Y actual
  final double startTime; // Tiempo cuando empezó a caer
  bool isHit; // Si ya fue golpeada
  bool isMissed; // Si se perdió la nota

  FallingNote({
    required this.piston,
    required this.y,
    required this.startTime,
    this.isHit = false,
    this.isMissed = false,
  });
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
  Timer? noteSpawner;
  Timer? gameUpdateTimer;
  late AnimationController _noteAnimationController;
  bool isGameActive = false;
  bool isGamePaused = false;

  // Configuración del juego
  static const double noteSpeed = 200.0; // pixels por segundo
  static const double hitZoneY =
      500.0; // Posición Y donde deben golpearse las notas
  static const double hitTolerance =
      30.0; // Tolerancia para considerar un hit correcto

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
  }

  @override
  void dispose() {
    logoTimer?.cancel();
    countdownTimer?.cancel();
    noteSpawner?.cancel();
    gameUpdateTimer?.cancel();
    _rotationController.dispose();
    _noteAnimationController.dispose();
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

  // Generar notas aleatorias
  void _spawnNotes() {
    noteSpawner = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!isGameActive || isGamePaused) {
        timer.cancel();
        return;
      }

      final random = Random();
      final piston = random.nextInt(3) + 1; // Pistones 1, 2, o 3

      fallingNotes.add(FallingNote(
        piston: piston,
        y: -50, // Empezar fuera de la pantalla
        startTime: DateTime.now().millisecondsSinceEpoch / 1000,
      ));
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

            // Verificar si la nota se perdió (pasó la zona de hit)
            if (note.y > hitZoneY + 100) {
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
    for (var note in fallingNotes) {
      if (note.piston == pistonNumber && !note.isHit && !note.isMissed) {
        // Verificar si la nota está en la zona de hit
        final distance = (note.y - hitZoneY).abs();
        if (distance <= hitTolerance) {
          note.isHit = true;
          _onNoteHit();
          return;
        }
      }
    }
    // Si no hay nota correcta, es un miss
    _onNoteMissed();
  }

  // Cuando se acierta una nota
  void _onNoteHit() {
    setState(() {
      totalNotes++;
      correctNotes++;
      currentScore += 10;
      experiencePoints += experiencePerCorrectNote;
    });

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
          _buildGameArea(),

          // Header con botón de regreso flotante
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildHeader(),
          ),

          // Barra de progreso vertical (al lado derecho cerca de la cámara)
          Positioned(
            top: 100, // Debajo del header
            right: 30, // Al lado derecho, cerca de la cámara del dispositivo
            child: _buildVerticalProgressBar(),
          ),

          // Controles de pistones en la parte inferior centrados
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
                        height: 190 * accuracy, // Altura basada en la precisión
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
                        bottom: 190 * position - 1,
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

  // Construir la zona de hit
  Widget _buildHitZone() {
    return Positioned(
      bottom: 140, // Justo encima de los pistones
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
        ),
        child: Row(
          children: [
            // Zona pistón 1
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Zona pistón 2
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Zona pistón 3
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir las notas que caen
  List<Widget> _buildFallingNotes() {
    return fallingNotes.map((note) {
      if (note.isHit || note.isMissed) return const SizedBox.shrink();

      final screenWidth = MediaQuery.of(context).size.width;
      final pistonWidth = screenWidth / 3;
      final noteX = (note.piston - 1) * pistonWidth + (pistonWidth / 2) - 25;

      return Positioned(
        left: noteX,
        top: note.y,
        child: _buildNote(note),
      );
    }).toList();
  }

  // Construir una nota individual
  Widget _buildNote(FallingNote note) {
    Color noteColor;
    switch (note.piston) {
      case 1:
        noteColor = Colors.red;
        break;
      case 2:
        noteColor = Colors.green;
        break;
      case 3:
        noteColor = Colors.blue;
        break;
      default:
        noteColor = Colors.white;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: noteColor.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          note.piston.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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

    // Dibujar líneas verticales para cada pistón
    final pistonWidth = size.width / 3;

    // Línea pistón 1
    canvas.drawLine(
      Offset(pistonWidth * 0.5, 0),
      Offset(pistonWidth * 0.5, size.height),
      paint,
    );

    // Línea pistón 2
    canvas.drawLine(
      Offset(pistonWidth * 1.5, 0),
      Offset(pistonWidth * 1.5, size.height),
      paint,
    );

    // Línea pistón 3
    canvas.drawLine(
      Offset(pistonWidth * 2.5, 0),
      Offset(pistonWidth * 2.5, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
