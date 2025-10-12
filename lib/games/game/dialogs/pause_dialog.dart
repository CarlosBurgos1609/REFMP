import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'back_dialog.dart';

void showPauseDialog(
  BuildContext context,
  String songName,
  VoidCallback onResume,
  VoidCallback onRestart,
) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono de pausa centrado
              Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.blue,
                    size: 35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Título centrado
              Center(
                child: Text(
                  'Juego en Pausa',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Color.fromARGB(255, 255, 255, 255)
                        : Color.fromARGB(255, 33, 150, 243),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción en fila
              Row(
                children: [
                  // Botón Regresar
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context); // Cerrar diálogo de pausa
                              showBackDialog(context, songName);
                            },
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Regresar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Botón Reanudar
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onResume();
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.green,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Reanudar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Botón Volver a empezar
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: Colors.orange, width: 2),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onRestart();
                            },
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.orange,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Volver a\nempezar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
