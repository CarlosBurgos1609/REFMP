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

    final backSprite = await loadSprite('back.png');

    final backButton = BackButtonComponent(
      sprite: backSprite,
      size: Vector2(40, 40),
      position: Vector2(20, 50),
      context: context,
    );

    add(backButton);
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
