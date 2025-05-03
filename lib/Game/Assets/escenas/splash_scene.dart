// lib/game/escenas/splash_scene.dart
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

class SplashScene extends FlameGame {
  final VoidCallback onFinish;

  SplashScene({required this.onFinish});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final sprite = await loadSprite('icono.png');
    final logo = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(200, 200)
      ..anchor = Anchor.center
      ..position = size / 2;

    add(logo);

    await Future.delayed(const Duration(seconds: 3));
    onFinish(); // Aquí ahora pasa a InicioScene
  }
}
