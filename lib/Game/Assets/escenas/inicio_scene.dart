import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      priority: -1,
    ));

    // Botón de retroceso
    final backSprite = await loadSprite('back.png');
    final backButton = BackButtonComponent(
      sprite: backSprite,
      size: Vector2(40, 40),
      position: Vector2(20, 50),
      context: context,
    );
    add(backButton);

    // Texto centrado "Instrumentos"
    final centerText = TextComponent(
      text: 'Instrumentos',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 58),
    );
    add(centerText);

    // Línea divisora gris
    add(RectangleComponent(
      size: Vector2(size.x * 0.8, 2),
      position: Vector2(size.x * 0.1, 110),
      paint: Paint()..color = Colors.blue,
    ));

    // Cargar instrumentos desde Supabase
    final supabase = Supabase.instance.client;
    final response = await supabase.from('games').select('*');

    if (response.isEmpty) return;

    double startY = 120;
    const double spacing = 80;

    for (int i = 0; i < response.length; i++) {
      final game = response[i];
      final name = game['name'] ?? 'Sin nombre';

      final button = GameButtonComponent(
        text: name,
        position: Vector2(size.x / 2, startY + (i * spacing)),
        gameName: name,
        context: context,
      );
      add(button);
    }
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
    // Suponiendo que navigatorKey está configurado
    Navigator.of(context).pop();
  }
}

class GameButtonComponent extends PositionComponent with TapCallbacks {
  final String text;
  final String gameName;
  final BuildContext context;

  GameButtonComponent({
    required this.text,
    required Vector2 position,
    required this.gameName,
    required this.context,
  }) {
    this.position = position; // usamos la propiedad heredada
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(250, 60);
    anchor = Anchor.topCenter;

    add(RectangleComponent(
      size: size,
      position: Vector2.zero(),
      paint: Paint()..color = Colors.blue,
    ));

    add(TextComponent(
      text: text,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));
  }

  @override
  void onTapUp(TapUpEvent event) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Seleccionado"),
        content: Text("Has seleccionado: $gameName"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
