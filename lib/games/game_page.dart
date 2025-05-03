// lib/game/game_page.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:refmp/Game/Assets/escenas/splash_scene.dart';
import 'package:refmp/Game/Assets/escenas/inicio_scene.dart'; // Importa InicioScene

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GameWidget(
      game: SplashScene(
        onFinish: () {
          // Cambiar a InicioScene directamente, no a Home
          runApp(
            MaterialApp(
              home: GameWidget(
                game: InicioScene(context),
              ),
            ),
          );
        },
      ),
    );
  }
}
