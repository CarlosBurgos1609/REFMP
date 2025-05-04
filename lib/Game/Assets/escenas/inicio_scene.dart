// lib/game/escenas/inicio_scene.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:refmp/main.dart'; // Para usar navigatorKey

class InicioScene extends FlameGame {
  final BuildContext context;

  InicioScene(this.context);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Fondo blanco
    add(RectangleComponent(
      size: canvasSize,
      paint: Paint()..color = Colors.white,
      priority: -1, // para que quede en el fondo
    ));

    final backSprite = await loadSprite('back.png');

    final backButton = BackButtonComponent(
      sprite: backSprite,
      size: Vector2(40, 40),
      position: Vector2(20, 50),
      context: context,
    );

    add(backButton);

    // Texto al lado del botón
    final text = TextComponent(
      text: 'Instrumentos',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      position: Vector2(150, 58), // Ajusta según se vea visualmente
      anchor: Anchor.topLeft,
    );

    add(text);
  }
}

class BackButtonComponent extends SpriteComponent with TapCallbacks {
  final BuildContext context;

  BackButtonComponent({
    required super.sprite,
    required super.size,
    required super.position,
    required this.context,
  });

  @override
  void onTapUp(TapUpEvent event) {
    navigatorKey.currentState?.pushReplacementNamed('/home');
  }
}
