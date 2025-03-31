// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flame/game.dart';
// import 'package:flame/components.dart';
// import 'package:flame/sprite.dart';
// import 'package:sensors_plus/sensors_plus.dart';
// import 'dart:math';

// void main() {
//   runApp(GameWidget(game: TrumpetGame()));
//   SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.portraitDown,
//   ]);
// }

// class TrumpetGame extends FlameGame {
//   SpriteComponent? background;
//   SpriteComponent? trumpet;
//   double rotationAngle = 0;
//   double? _lastAccelerometerZ;

//   @override
//   Future<void> onLoad() async {
//     await super.onLoad();

//     // Cargar fondo
//     final backgroundSprite = await Sprite.load('pasto.png');
//     background = SpriteComponent(
//       sprite: backgroundSprite,
//       size: size,
//     );
//     add(background!);

//     // Cargar trompeta
//     final trumpetSprite = await Sprite.load('trumpet.png');
//     trumpet = SpriteComponent(
//       sprite: trumpetSprite,
//       size: Vector2(200, 200),
//       position: size / 2,
//       anchor: Anchor.center,
//     );
//     add(trumpet!);

//     // Escuchar sensor de acelerómetro
//     accelerometerEvents.listen((AccelerometerEvent event) {
//       _handleAccelerometer(event);
//     });
//   }

//   void _handleAccelerometer(AccelerometerEvent event) {
//     // Usamos el eje Z para detectar si el dispositivo está boca arriba o abajo
//     const double threshold = 7.0; // Umbral de sensibilidad

//     if (_lastAccelerometerZ == null) {
//       _lastAccelerometerZ = event.z;
//       return;
//     }

//     // Solo actualizamos si hay un cambio significativo
//     if ((event.z - _lastAccelerometerZ!).abs() > threshold) {
//       _lastAccelerometerZ = event.z;
//       if (event.z > 0) {
//         rotationAngle = 0; // Posición normal
//       } else {
//         rotationAngle = pi; // Boca abajo
//       }
//     }
//   }

//   @override
//   void update(double dt) {
//     super.update(dt);
//     // Aplicar rotación
//     background?.angle = rotationAngle;
//     trumpet?.angle = rotationAngle;
//     trumpet?.position = size / 2;
//   }

//   @override
//   void render(Canvas canvas) {
//     canvas.save();
//     canvas.translate(size.x / 2, size.y / 2);
//     canvas.rotate(rotationAngle);
//     canvas.translate(-size.x / 2, -size.y / 2);

//     super.render(canvas);
//     canvas.restore();
//   }
// }
