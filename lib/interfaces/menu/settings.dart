import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/init.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});
  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  bool _notificationsEnabled = false;

  Future<void> checkPermissionStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> requestPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    } else {
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

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
              onPressed: () async {
                // Cerrar el diálogo inmediatamente
                Navigator.of(context).pop();

                try {
                  // Limpiar credenciales guardadas en SharedPreferences solo si NO tiene recuerdame
                  final prefs = await SharedPreferences.getInstance();
                  final rememberMe = prefs.getBool('remember_me') ?? false;

                  if (!rememberMe) {
                    // Solo borrar si NO está marcado recuerdame
                    await prefs.remove('saved_email');
                    await prefs.remove('saved_password');
                  }
                  // No modificar remember_me, mantenerlo como está

                  // Limpiar el cache de roles
                  Menu.clearRoleCache();
                  Menu.currentIndexNotifier.value = 0;

                  // Cerrar sesión en Supabase Auth sin esperar (fire and forget)
                  Supabase.instance.client.auth.signOut().timeout(
                    const Duration(milliseconds: 500),
                    onTimeout: () {
                      debugPrint('SignOut timeout, continuando...');
                    },
                  ).catchError((e) {
                    debugPrint('Error en signOut: $e');
                  });

                  // Navegar a Init inmediatamente sin esperar
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Init()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  debugPrint('Error al cerrar sesión: $e');
                  // Navegar de todas formas
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const Init()),
                      (route) => false,
                    );
                  }
                }
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
  void initState() {
    super.initState();
    checkPermissionStatus();
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
          centerTitle: true,
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

              // Opción: Usar tema del sistema
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.useSystemTheme
                      ? Colors.blue
                      : Colors.grey.shade300,
                  foregroundColor: themeProvider.useSystemTheme
                      ? Colors.white
                      : Colors.black54,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (!themeProvider.useSystemTheme) {
                    final brightness =
                        MediaQuery.of(context).platformBrightness;
                    themeProvider.useSystemThemeMode(brightness);
                  }
                },
                icon: const Icon(Icons.brightness_auto),
                label: const Text(
                  'Predeterminado del sistema',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              // Opción: Modo claro
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      !themeProvider.useSystemTheme && !themeProvider.isDarkMode
                          ? Colors.blue
                          : Colors.grey.shade300,
                  foregroundColor:
                      !themeProvider.useSystemTheme && !themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black54,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (themeProvider.useSystemTheme ||
                      themeProvider.isDarkMode) {
                    // Si está en modo sistema o modo oscuro, cambiar a modo claro
                    if (themeProvider.isDarkMode) {
                      themeProvider.toggleTheme();
                    } else {
                      // Ya está en modo claro pero usando sistema, solo desactivar sistema
                      themeProvider.toggleTheme();
                      if (themeProvider.isDarkMode) {
                        themeProvider.toggleTheme();
                      }
                    }
                  }
                },
                icon: const Icon(Icons.light_mode, color: Colors.amber),
                label: const Text(
                  'Modo claro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              // Opción: Modo oscuro
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      !themeProvider.useSystemTheme && themeProvider.isDarkMode
                          ? Colors.blue
                          : Colors.grey.shade300,
                  foregroundColor:
                      !themeProvider.useSystemTheme && themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black54,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (themeProvider.useSystemTheme ||
                      !themeProvider.isDarkMode) {
                    // Si está en modo sistema o modo claro, cambiar a modo oscuro
                    if (!themeProvider.isDarkMode) {
                      themeProvider.toggleTheme();
                    } else {
                      // Ya está en modo oscuro pero usando sistema, solo desactivar sistema
                      themeProvider.toggleTheme();
                      if (!themeProvider.isDarkMode) {
                        themeProvider.toggleTheme();
                      }
                    }
                  }
                },
                icon: const Icon(Icons.dark_mode, color: Colors.white),
                label: const Text(
                  'Modo oscuro',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Permitir notificaciones",
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : const Color.fromARGB(255, 33, 150, 243),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: requestPermission,
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
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
