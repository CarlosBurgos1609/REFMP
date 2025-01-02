import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de Configuración'),
      ),
    );
  }
}
