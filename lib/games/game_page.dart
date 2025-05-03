// lib/game/game_page.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:refmp/Game/Assets/escenas/inicio_scene.dart';
import 'package:refmp/Game/Assets/escenas/splash_scene.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late FlameGame _currentGame;

  @override
  void initState() {
    super.initState();

    _currentGame = SplashScene(
      onFinish: () {
        // Cambiar a InicioScene después del splash
        setState(() {
          _currentGame = InicioScene(context);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _currentGame),
    );
  }
}
