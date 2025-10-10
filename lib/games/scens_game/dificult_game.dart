import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

class DificultGamePage extends StatefulWidget {
  final String songName;
  final String? songId;

  const DificultGamePage({
    super.key,
    required this.songName,
    this.songId,
  });

  @override
  State<DificultGamePage> createState() => _DificultGamePageState();
}

class _DificultGamePageState extends State<DificultGamePage> {
  bool showLogo = true;
  Timer? logoTimer;

  // Estado de los pistones para prevenir pantallazos
  Set<int> pressedPistons = <int>{};
  Timer? screenshotPreventionTimer;
  bool _isScreenshotBlocked = false;

  @override
  void initState() {
    super.initState();
    _setupScreen();
    _startLogoTimer();
  }

  @override
  void dispose() {
    logoTimer?.cancel();
    screenshotPreventionTimer?.cancel();
    // Restaurar orientación y barra de estado al salir
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
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
          primaryColor: 0xFFDC2626,
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
                      color: Colors.red,
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
            Color(0xFF7F1D1D), // Rojo oscuro
            Color(0xFFDC2626), // Rojo medio
            Color(0xFFEF4444), // Rojo claro
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
                        color: Colors.red,
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
              'Nivel Avanzado',
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

  Widget _buildHeader() {
    return Row(
      children: [
        // Botón de regreso con arrow iOS redondeado
        Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
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

        const SizedBox(width: 20),

        // Título de la canción
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
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
      ],
    );
  }

  Widget _buildGameArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              color: Colors.red,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Área de Juego - Avanzado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Nivel de máxima dificultad',
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
    // Simular las distancias reales de una trompeta
    // En una trompeta real, los pistones están separados por aproximadamente 22mm
    // Tamaño del pistón: aproximadamente 18mm de diámetro
    const double pistonSize = 70.0; // Tamaño del botón en pixels
    const double realPistonSeparation = 22.0; // mm en trompeta real
    const double realPistonDiameter = 18.0; // mm en trompeta real

    // Calcular la separación proporcional en pixels
    final double pixelSeparation =
        (realPistonSeparation / realPistonDiameter) * pistonSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
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
              color: Colors.red.withOpacity(0.3),
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(pistonSize / 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFEF4444),
                      Color(0xFFDC2626),
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

    // Aquí puedes agregar la lógica del juego
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
}
