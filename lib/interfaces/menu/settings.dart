// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/init.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});
  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPage();
}

class _SettingsPage extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  bool _checkingUpdate = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    checkPermissionStatus();
    _getCurrentVersion();
  }

  // Obtener la versión actual de la app
  Future<void> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
      debugPrint('📱 Versión actual: $_currentVersion');
    } catch (e) {
      debugPrint('❌ Error al obtener versión: $e');
    }
  }

  // Verificar si hay actualizaciones disponibles
  // ignore: unused_element
  Future<void> _checkForUpdates({bool showNoUpdateDialog = true}) async {
    setState(() {
      _checkingUpdate = true;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      debugPrint('📱 Versión actual: $currentVersion+$currentBuildNumber');

      // Consultar versión disponible en Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('app_version')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No se encontraron versiones en la tabla app_version');
        if (showNoUpdateDialog && mounted) {
          _showNoUpdateDialog();
        }
        return;
      }

      final latestVersion = response['version'] as String;
      final latestBuildNumber = response['build_number'] as int;
      final isRequired = response['required'] as bool? ?? false;
      final releaseNotes = response['release_notes'] as String? ?? '';
      final androidUrl = response['android_url'] as String? ?? '';
      final iosUrl = response['ios_url'] as String? ?? '';

      debugPrint('☁️ Versión disponible: $latestVersion+$latestBuildNumber');

      // Comparar build numbers
      if (latestBuildNumber > currentBuildNumber) {
        if (mounted) {
          _showUpdateDialog(
            latestVersion,
            releaseNotes,
            isRequired,
            Platform.isAndroid ? androidUrl : iosUrl,
          );
        }
      } else {
        if (showNoUpdateDialog && mounted) {
          _showNoUpdateDialog();
        }
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ Error de Supabase: ${e.message}');
      debugPrint('   Código: ${e.code}');
      debugPrint('   Detalles: ${e.details}');
      if (mounted) {
        String errorMsg = 'Error al verificar actualizaciones';
        if (e.code == '42P01') {
          errorMsg =
              'La tabla app_version no existe. Ejecuta el script SQL primero.';
        } else if (e.code == '42501') {
          errorMsg = 'Sin permisos. Configura las políticas RLS en Supabase.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error al verificar actualizaciones: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        String errorMsg = 'Error al verificar actualizaciones';
        if (e.toString().contains('package_info_plus')) {
          errorMsg = 'Ejecuta "flutter pub get" para instalar dependencias';
        } else if (e.toString().contains('relation') ||
            e.toString().contains('does not exist')) {
          errorMsg = 'La tabla app_version no existe. Ejecuta el script SQL.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  // Mostrar diálogo cuando hay actualización disponible
  void _showUpdateDialog(
    String version,
    String releaseNotes,
    bool isRequired,
    String storeUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !isRequired,
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.system_update, color: Colors.blue, size: 30),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRequired
                        ? '¡Actualización Requerida!'
                        : 'Actualización Disponible',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva versión: $version',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Versión actual: $_currentVersion',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (releaseNotes.isNotEmpty) ...[
                    SizedBox(height: 15),
                    Text(
                      'Novedades:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      releaseNotes,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                  if (isRequired) ...[
                    SizedBox(height: 15),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta actualización es obligatoria para continuar usando la aplicación.',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isRequired)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Más tarde',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _openStore(storeUrl);
                },
                icon: Icon(Icons.download),
                label: Text('Actualizar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mostrar diálogo cuando no hay actualizaciones
  void _showNoUpdateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text(
                'Todo al día',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Ya tienes la última versión de la aplicación instalada.\n\nVersión actual: $_currentVersion',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Abrir la tienda de aplicaciones
  Future<void> _openStore(String storeUrl) async {
    try {
      if (storeUrl.isEmpty) {
        throw 'URL de tienda no disponible';
      }

      final Uri url = Uri.parse(storeUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'No se puede abrir la tienda';
      }
    } catch (e) {
      debugPrint('❌ Error al abrir tienda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir la tienda de aplicaciones'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

              // Sección de actualizaciones - Comentar/descomentar según necesites
              // NOTA: Habilitar solo cuando la app esté en Google Play/App Store
              /*
              ListTile(
                leading: _checkingUpdate
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : Icon(Icons.system_update, color: Colors.blue, size: 28),
                title: Text(
                  "Buscar actualizaciones",
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _currentVersion.isNotEmpty
                      ? 'Versión actual: $_currentVersion'
                      : 'Verificar nuevas versiones',
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey,
                ),
                onTap: _checkingUpdate ? null : _checkForUpdates,
              ),
              const SizedBox(height: 10),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              */
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
