import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart'; // Importa el controlador

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(
          context), // Llama a la función del controlador
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.blue),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          actions: [
            GestureDetector(
              onTap: () {
                // Actualizamos el índice en el ValueNotifier
                Menu.currentIndexNotifier.value =
                    1; // Cambiar al índice de Perfil
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(title: "Perfil"),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(right: 24),
                child: ClipOval(
                  child: Image.asset(
                    "assets/images/refmmp.png",
                    fit: BoxFit.cover,
                    width: 45,
                    height: 45,
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Menu.buildDrawer(context),
        body: const Center(
          child: Text(
            "Contenido de la página Principal",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
