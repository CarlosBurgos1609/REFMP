import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart'; // Asegúrate de tener este import

class SplashScene extends FlameGame {
  final VoidCallback
      onFinish; // Asegúrate de que VoidCallback está bien definido

  SplashScene({required this.onFinish});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Cargar sprite
    final sprite = await loadSprite('icono.png');
    final logo = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(200, 200)
      ..anchor = Anchor.center
      ..position = size / 2;

    add(logo);

    // Después de 3 segundos, llamar al callback para cambiar de pantalla
    await Future.delayed(const Duration(seconds: 1));
    onFinish(); // Llama al callback
  }
}
