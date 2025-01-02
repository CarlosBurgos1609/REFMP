import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de Perfil'),
      ),
    );
  }
}
