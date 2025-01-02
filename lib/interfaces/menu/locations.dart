import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart';

class LocationsPage extends StatelessWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de Ubicación'),
      ),
    );
  }
}
