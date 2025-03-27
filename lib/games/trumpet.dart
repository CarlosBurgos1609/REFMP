import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrumpetGameWidget extends StatefulWidget {
  final String songName;
  final String artist;

  const TrumpetGameWidget(
      {super.key, required this.songName, required this.artist});

  @override
  _TrumpetGameWidgetState createState() => _TrumpetGameWidgetState();
}

class _TrumpetGameWidgetState extends State<TrumpetGameWidget> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pasto.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 40),
              Text(
                widget.songName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.artist,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset(
                        'assets/images/trumpet.png',
                        width: 500,
                        height: 250,
                      ),
                    ),
                    Positioned.fill(
                      child: GameWidget(game: TrumpetGame()),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Pistón 1"),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Pistón 2"),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Pistón 3"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TrumpetGame extends FlameGame with TapDetector {
  List<FallingButton> buttons = [];
  int score = 0;

  @override
  Future<void> onLoad() async {
    _spawnButtons();
  }

  void _spawnButtons() {
    for (int i = 0; i < 10; i++) {
      double xPos = (i % 3) * 100 + 100;
      var button = FallingButton(Vector2(xPos, -i * 100.0));
      buttons.add(button);
      add(button);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    for (var button in buttons) {
      if (button.containsPoint(info.eventPosition.global)) {
        if (button.isActive) {
          score += 10;
          button.removeFromParent();
        }
      }
    }
  }
}

class FallingButton extends SpriteComponent with HasGameRef<TrumpetGame> {
  bool isActive = true;

  FallingButton(Vector2 position) {
    this.position = position;
    size = Vector2(50, 50);
  }

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('trumpet.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100 * dt;
    if (position.y > gameRef.size.y) {
      isActive = false;
      removeFromParent();
    }
  }
}
