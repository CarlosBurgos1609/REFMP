import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart'; // Importa la clase Menu

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de Contactos'),
      ),
    );
  }
}
