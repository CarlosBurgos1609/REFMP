import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BegginnerGamePage extends StatefulWidget {
  final String songName;
  final String? songId;
  final String? songImageUrl;
  final String? profileImageUrl;

  const BegginnerGamePage({
    super.key,
    required this.songName,
    this.songId,
    this.songImageUrl,
    this.profileImageUrl,
  });

  @override
  State<BegginnerGamePage> createState() => _BegginnerGamePageState();
}

class _BegginnerGamePageState extends State<BegginnerGamePage>
    with TickerProviderStateMixin {
  bool showLogo = true;
  Timer? logoTimer;

  // Estado de los pistones para prevenir pantallazos
  Set<int> pressedPistons = <int>{};
  Timer? screenshotPreventionTimer;
  bool _isScreenshotBlocked = false;

  // Controlador de animación para la rotación de la imagen de la canción
  late AnimationController _rotationController;

  // Variables para el sistema de puntuación y rendimiento
  int totalCoins = 150; // Monedas del jugador
  int currentScore = 0; // Puntuación actual
  int totalNotes = 0; // Total de notas tocadas
  int correctNotes = 0; // Notas correctas
  double get accuracy => totalNotes == 0 ? 1.0 : correctNotes / totalNotes;

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
    screenshotPreventionTimer?.cancel();
    _rotationController.dispose();
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
  }

  void _startLogoTimer() {
    logoTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showLogo = false;
        });
      }
    });
  }

  void _initializeAnimations() {
    // Controlador para la rotación continua de la imagen de la canción
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(); // Repetir infinitamente
  }

  void _checkScreenshotPrevention() {
    if (pressedPistons.length == 3) {
      // Los 3 pistones están presionados, prevenir pantallazos
      _enableScreenshotPrevention();
    } else {
      // No todos los pistones están presionados, permitir pantallazos
      _disableScreenshotPrevention();
    }
  }

  void _enableScreenshotPrevention() {
    screenshotPreventionTimer?.cancel();
    screenshotPreventionTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && pressedPistons.length == 3) {
        _isScreenshotBlocked = true;

        // Estrategia múltiple para prevenir pantallazos
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );

        // Forzar re-render de la pantalla con contenido seguro
        setState(() {});

        // Ocultar contenido de la aplicación del recents/overview
        SystemChrome.setApplicationSwitcherDescription(
          const ApplicationSwitcherDescription(
            label: 'REFMP - Juego Seguro',
            primaryColor: 0xFF000000,
          ),
        );

        debugPrint('Screenshot prevention ENABLED - All 3 pistons pressed');
      }
    });
  }

  void _disableScreenshotPrevention() {
    screenshotPreventionTimer?.cancel();
    if (mounted) {
      _isScreenshotBlocked = false;

      // Restaurar modo normal
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );

      // Restaurar descripción normal de la app
      SystemChrome.setApplicationSwitcherDescription(
        const ApplicationSwitcherDescription(
          label: 'REFMP',
          primaryColor: 0xFF1E3A8A,
        ),
      );

      debugPrint('Screenshot prevention DISABLED - Not all pistons pressed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          showLogo ? _buildLogoScreen() : _buildGameScreen(),
          // Overlay de protección cuando los 3 pistones están presionados
          if (_isScreenshotBlocked)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.blue,
                      size: 80,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'MODO SEGURO ACTIVADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Contenido protegido',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
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
              // Cantidad de monedas
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
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              color: Colors.blue,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Área de Juego',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Aquí aparecerán las notas musicales',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
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
    _checkScreenshotPrevention();

    // Simular jugabilidad (esto se reemplazará con lógica real del juego)
    _simulateGameplay(true); // true = nota correcta, false = nota incorrecta

    debugPrint('Pistón $pistonNumber presionado');

    // TODO: Implementar lógica del juego
  }

  void _onPistonReleased(int pistonNumber) {
    // Remover pistón del conjunto de pistones presionados
    pressedPistons.remove(pistonNumber);
    _checkScreenshotPrevention();

    debugPrint('Pistón $pistonNumber liberado');

    // TODO: Implementar lógica del juego
  }

  // Método para simular el progreso del juego (temporal)
  void _simulateGameplay(bool isCorrect) {
    setState(() {
      totalNotes++;
      if (isCorrect) {
        correctNotes++;
        currentScore += 10; // +10 puntos por nota correcta
        totalCoins += 2; // +2 monedas por nota correcta
      } else {
        // Penalización por nota incorrecta
        currentScore = (currentScore - 5).clamp(0, double.infinity).toInt();
        totalCoins = (totalCoins - 1).clamp(0, double.infinity).toInt();
      }
    });
  }

  // Método para resetear el progreso del juego
  // void _resetGameProgress() {
  //   setState(() {
  //     totalNotes = 0;
  //     correctNotes = 0;
  //     currentScore = 0;
  //     // No resetear totalCoins ya que es persistente
  //   });
  // }
}
