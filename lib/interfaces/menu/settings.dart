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
import 'dart:io' show Platform, File;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_file/open_file.dart';

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
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final Dio _dio = Dio();

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
                  // En Android siempre intentar descargar e instalar el APK
                  if (Platform.isAndroid && storeUrl.isNotEmpty) {
                    _downloadAndInstallApk(storeUrl, version);
                  } else {
                    _openStore(storeUrl);
                  }
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

  // Descargar e instalar APK automáticamente desde GitHub
  Future<void> _downloadAndInstallApk(String apkUrl, String version) async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ Instalación de APK solo disponible en Android');
      return;
    }

    try {
      // 🔒 Solicitar permisos de almacenamiento primero
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final storageResult = await Permission.storage.request();
        if (!storageResult.isGranted) {
          throw 'Se requiere permiso de almacenamiento para descargar la actualización';
        }
      }

      // 🔒 Verificar y solicitar permisos de instalación
      if (await _needsInstallPermission()) {
        final hasPermission = await _requestInstallPermission();
        if (!hasPermission) {
          throw 'Se requiere permiso para instalar aplicaciones. Por favor, activa "Fuentes desconocidas" en la configuración';
        }
      }

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Mostrar diálogo de progreso
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildDownloadDialog(version),
        );
      }

      // Obtener directorio de descargas
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw 'No se pudo acceder al almacenamiento';
      }

      final filePath = '${directory.path}/refmp_v$version.apk';

      debugPrint('📥 Descargando APK desde: $apkUrl');
      debugPrint('💾 Guardando en: $filePath');

      // Eliminar archivo anterior si existe
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Descargar el APK con progreso
      await _dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            setState(() {
              _downloadProgress = progress;
            });
            debugPrint('📊 Progreso: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
        options: Options(
          followRedirects: true,
          receiveTimeout: Duration(minutes: 5),
        ),
      );

      debugPrint('✅ Descarga completada: $filePath');

      // Verificar que el archivo se descargó correctamente
      if (!await file.exists()) {
        throw 'El archivo no se descargó correctamente';
      }

      final fileSize = await file.length();
      debugPrint(
          '📦 Tamaño del archivo: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Instalar el APK
      await _installApk(filePath);
    } catch (e, stackTrace) {
      debugPrint('❌ Error al descargar/instalar APK: $e');
      debugPrint('   Stack trace: $stackTrace');

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _downloadAndInstallApk(apkUrl, version),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  // Construir diálogo de descarga con progreso
  Widget _buildDownloadDialog(String version) {
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.download, color: Colors.blue),
              SizedBox(width: 10),
              Text('Descargando actualización'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Versión: $version', style: TextStyle(fontSize: 14)),
              SizedBox(height: 20),
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              SizedBox(height: 10),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Por favor espera...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  // Instalar el APK descargado
  Future<void> _installApk(String filePath) async {
    try {
      debugPrint('📲 Instalando APK: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw 'El archivo APK no existe';
      }

      // Usar open_file que maneja automáticamente FileProvider
      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint(
          '📦 Resultado de instalación: ${result.type} - ${result.message}');

      if (mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Instalación iniciada. Sigue las instrucciones en pantalla.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (result.type == ResultType.noAppToOpen) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No se encontró una aplicación para instalar el APK'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (result.type == ResultType.permissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso denegado para instalar'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abrir el instalador: ${result.message}'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al instalar APK: $e');
      rethrow;
    }
  }

  // Verificar si se necesita permiso de instalación (Android 8.0+)
  Future<bool> _needsInstallPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 8.0 (API 26) o superior requiere permiso
      return sdkInt >= 26;
    } catch (e) {
      debugPrint('⚠️ Error al verificar versión de Android: $e');
      return true; // Por seguridad, asumir que sí se necesita
    }
  }

  // Solicitar permiso de instalación
  Future<bool> _requestInstallPermission() async {
    try {
      // Verificar si ya tiene el permiso
      final status = await Permission.requestInstallPackages.status;

      if (status.isGranted) {
        debugPrint('✅ Permiso de instalación ya otorgado');
        return true;
      }

      // Mostrar diálogo explicativo antes de solicitar
      if (mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.security, color: Colors.blue),
                SizedBox(width: 10),
                Expanded(child: Text('Permiso necesario')),
              ],
            ),
            content: Text(
              'Para instalar actualizaciones, la aplicación necesita permiso para '
              'instalar aplicaciones de fuentes desconocidas.\n\n'
              '¿Deseas otorgar este permiso?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Permitir'),
              ),
            ],
          ),
        );

        if (shouldRequest != true) {
          return false;
        }
      }

      // Solicitar el permiso
      debugPrint('🔒 Solicitando permiso de instalación...');
      final result = await Permission.requestInstallPackages.request();

      if (result.isGranted) {
        debugPrint('✅ Permiso de instalación otorgado');
        return true;
      } else if (result.isDenied) {
        debugPrint('❌ Permiso de instalación denegado');
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return false;
      } else if (result.isPermanentlyDenied) {
        debugPrint('🚫 Permiso de instalación permanentemente denegado');
        if (mounted) {
          _showOpenSettingsDialog();
        }
        return false;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error al solicitar permiso de instalación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al solicitar permisos. Activa manualmente "Fuentes desconocidas" '
              'en Configuración > Seguridad',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  // Diálogo cuando el permiso es denegado
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Permiso denegado')),
          ],
        ),
        content: Text(
          'Sin este permiso no podemos instalar actualizaciones automáticamente.\n\n'
          'Puedes activarlo manualmente en:\n'
          'Configuración > Seguridad > Fuentes desconocidas',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // Diálogo para abrir configuración
  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(child: Text('Abrir configuración')),
          ],
        ),
        content: Text(
          'Para instalar actualizaciones, debes activar "Fuentes desconocidas" '
          'en la configuración del sistema.\n\n'
          '¿Deseas abrir la configuración ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text('Abrir'),
          ),
        ],
      ),
    );
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

              // Sección de actualizaciones
              // Habilitar cuando tengas versiones en la tabla app_version de Supabase
              ListTile(
                leading: _checkingUpdate
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      )
                    : Icon(Icons.system_update, color: Colors.blue, size: 28),
                title: Text(
                  "Buscar actualizaciones",
                  style: TextStyle(
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.blue,
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
                  color:
                      themeProvider.isDarkMode ? Colors.white70 : Colors.grey,
                ),
                onTap: _checkingUpdate
                    ? null
                    : () => _checkForUpdates(showNoUpdateDialog: true),
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
