import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart'; // Importa la clase Menu

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.blue),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      drawer: Menu.buildDrawer(
          context), // Usa la clase Menu para construir el Drawer
      body: const Center(
        // Agregué un body de ejemplo
        child: Text("Contenido de la página principal"),
      ),
    );
  }
}
