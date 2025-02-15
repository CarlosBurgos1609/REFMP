import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final shouldPop = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(
        '¿Estás seguro?',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.blue),
      ),
      content: const Text(
        '¿Quieres salir de la aplicación?',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Retorna false
          child: const Text(
            'No',
            style: TextStyle(color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ),
        TextButton(
          onPressed: () => SystemNavigator.pop(), // Cierra la app
          child: const Text(
            'Sí',
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
  return shouldPop ?? false; // Maneja el caso nulo
}
