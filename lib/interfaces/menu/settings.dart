import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/init.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});
  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "¿Está seguro?",
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            "¿Desea cerrar la sesión?",
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () {
                Menu.currentIndexNotifier.value = 0;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Init()),
                );
              },
              child: const Text(
                "Cerrar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              "¿Está seguro?",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              "¿Desea salir de la aplicación?",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Salir",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 23,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tema:",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? Color.fromARGB(255, 255, 255, 255)
                      : Color.fromARGB(255, 33, 150, 243),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color:
                      themeProvider.isDarkMode ? Colors.white : Colors.yellow,
                ),
                label: Text(
                  themeProvider.isDarkMode ? 'Modo oscuro' : 'Modo claro',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text(
                  "Cerrar sesión",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  _logout(context);
                },
              ),
              SizedBox(
                height: 10,
              ),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
