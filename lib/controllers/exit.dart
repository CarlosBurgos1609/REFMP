import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final shouldPop = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Estás seguro?'),
      content: const Text('¿Quieres salir de la aplicación?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Retorna false
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => SystemNavigator.pop(), // Cierra la app
          child: const Text('Sí'),
        ),
      ],
    ),
  );
  return shouldPop ?? false; // Maneja el caso nulo
}
