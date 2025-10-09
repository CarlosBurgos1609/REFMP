import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BegginnerGamePage extends StatefulWidget {
  final String songName;
  final String? songId;

  const BegginnerGamePage({
    super.key,
    required this.songName,
    this.songId,
  });

  @override
  State<BegginnerGamePage> createState() => _BegginnerGamePageState();
}

class _BegginnerGamePageState extends State<BegginnerGamePage> {
  bool showLogo = true;
  Timer? logoTimer;

  @override
  void initState() {
    super.initState();
    _setupScreen();
    _startLogoTimer();
  }

  @override
  void dispose() {
    logoTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: showLogo ? _buildLogoScreen() : _buildGameScreen(),
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

        const SizedBox(width: 20),

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

    // Aquí puedes agregar la lógica del juego
    debugPrint('Pistón $pistonNumber presionado');

    // TODO: Implementar lógica del juego
  }

  void _onPistonReleased(int pistonNumber) {
    debugPrint('Pistón $pistonNumber liberado');

    // TODO: Implementar lógica del juego
  }
}
