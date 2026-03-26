// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/details/headquartersInfo.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

// Custom Cache Manager for CachedNetworkImage
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30), // Cache images for 30 days
      maxNrOfCacheObjects: 100, // Limit number of cached objects
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? profileImageUrl;
  final supabase = Supabase.instance.client;

  late final PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  late final PageController _gamesPageController;
  late Timer _gamesTimer;
  int _currentGamePage = 0;

  List<dynamic> sedes = [];
  List<dynamic> games = [];

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _hasCheckedForUpdates = false;
  bool _checkingUpdate = false;
  String _currentVersion = '';
  bool _pageControllerInitialized = false;
  bool _gamesPageControllerInitialized = false;
  bool _autoScrollStarted = false;
  bool _gamesAutoScrollStarted = false;
  final ValueNotifier<double?> _downloadProgressNotifier =
      ValueNotifier<double?>(0.0);
  final ValueNotifier<int> _downloadedBytesNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _downloadTotalBytesNotifier = ValueNotifier<int>(0);
  CancelToken? _apkDownloadCancelToken;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
    fetchSedes();
    fetchGamesData();
    _checkNotificationPermission();
    _checkForUpdatesOnce(); // Verificar actualizaciones al iniciar

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      if (!mounted) return;
      if (result != ConnectivityResult.none) {
        // Conexión restaurada, recarga los datos
        await fetchSedes();
        await fetchGamesData();
        await fetchUserProfileImage();
      }
    });

    _pageController = PageController(viewportFraction: 0.9);
    _pageControllerInitialized = true;
    _startAutoScroll();
    _autoScrollStarted = true;

    _gamesPageController = PageController(viewportFraction: 0.95);
    _gamesPageControllerInitialized = true;
    _startAutoScrollGames();
    _gamesAutoScrollStarted = true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _apkDownloadCancelToken?.cancel('HomePage disposed');
    _connectivitySubscription?.cancel();
    if (_autoScrollStarted) {
      _timer.cancel();
    }
    if (_pageControllerInitialized) {
      _pageController.dispose();
    }
    if (_gamesAutoScrollStarted) {
      _gamesTimer.cancel();
    }
    if (_gamesPageControllerInitialized) {
      _gamesPageController.dispose();
    }
    _downloadProgressNotifier.dispose();
    _downloadedBytesNotifier.dispose();
    _downloadTotalBytesNotifier.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!mounted) return; // <-- Agregado
      if (sedes.isNotEmpty) {
        if (_currentPage < sedes.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          // <-- Chequeo correcto
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _startAutoScrollGames() {
    _gamesTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return; // <-- Agregado
      if (games.isNotEmpty) {
        if (_currentGamePage < games.length - 1) {
          _currentGamePage++;
        } else {
          _currentGamePage = 0;
        }
        if (_gamesPageController.hasClients) {
          // <-- Chequeo correcto
          _gamesPageController.animateToPage(
            _currentGamePage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Conectividad: $connectivityResult');
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  Future<bool> _isGuest() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final response = await supabase
          .from('guests')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error al verificar si es invitado: $e');
      return false;
    }
  }

  Future<void> _checkNotificationPermission() async {
    // Esperar un poco para que la UI esté lista
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final hasAskedBefore = prefs.getBool('has_asked_notifications') ?? false;

    // Si ya preguntamos antes, no volver a preguntar
    if (hasAskedBefore) return;

    final status = await Permission.notification.status;

    if (!status.isGranted && mounted) {
      _showNotificationDialog();
    }
  }

  void _showNotificationDialog() {
    final scaffoldContext =
        context; // Guardar referencia al contexto del Scaffold
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¿Activar notificaciones?',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Activa las notificaciones para recibir actualizaciones importantes sobre tus clases, eventos y más.',
            style: TextStyle(fontSize: 15),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Guardar que ya preguntamos
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_asked_notifications', true);
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Ahora no',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Guardar que ya preguntamos
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_asked_notifications', true);

                Navigator.of(dialogContext).pop();

                // Solicitar permiso
                final status = await Permission.notification.request();

                if (status.isGranted && scaffoldContext.mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(
                      content: Text('Notificaciones activadas correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (status.isPermanentlyDenied &&
                    scaffoldContext.mounted) {
                  // El usuario denegó permanentemente, ofrecer ir a configuración
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Por favor, activa las notificaciones desde la configuración'),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: 'Abrir',
                        textColor: Colors.white,
                        onPressed: () {
                          openAppSettings();
                        },
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Activar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🆕 Verificar actualizaciones solo una vez al iniciar
  Future<void> _checkForUpdatesOnce() async {
    if (_hasCheckedForUpdates) return;

    // Esperar un poco para que la UI esté lista
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    _hasCheckedForUpdates = true;
    await _checkForUpdates(showNoUpdateDialog: false);
  }

  // Verificar si hay actualizaciones disponibles
  Future<void> _checkForUpdates({bool showNoUpdateDialog = false}) async {
    if (_checkingUpdate) return;

    setState(() {
      _checkingUpdate = true;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      setState(() {
        _currentVersion = '$currentVersion+$currentBuildNumber';
      });

      debugPrint('📱 Versión actual: $_currentVersion');

      // Consultar versión disponible en Supabase
      final response = await supabase
          .from('app_version')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No se encontraron versiones en la tabla app_version');
        return;
      }

      final latestVersion = response['version'] as String;
      final latestBuildNumber = response['build_number'] as int;
      final isRequired = response['required'] as bool? ?? false;
      final releaseNotes = response['release_notes'] as String? ?? '';
      final androidUrl = response['android_url'] as String? ?? '';

      debugPrint('☁️ Versión disponible: $latestVersion+$latestBuildNumber');

      // Comparar build numbers
      if (latestBuildNumber > currentBuildNumber) {
        if (mounted) {
          _showUpdateDialog(
            latestVersion,
            releaseNotes,
            isRequired,
            androidUrl,
          );
        }
      } else if (showNoUpdateDialog && mounted) {
        // Mostrar que está al día
        _showUpToDateDialog();
      }
    } catch (e) {
      debugPrint('❌ Error al verificar actualizaciones: $e');
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
    String downloadUrl,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !isRequired,
          child: AlertDialog(
            backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            contentPadding: EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRequired
                        ? Icons.warning_rounded
                        : Icons.system_update_rounded,
                    color: isRequired ? Colors.orange : Colors.blue,
                    size: MediaQuery.of(context).size.width * 0.25,
                  ),
                  SizedBox(height: 12),
                  Text(
                    isRequired
                        ? '¡Actualización Requerida!'
                        : 'Nueva Actualización',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isRequired ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.shade900.withOpacity(0.3)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.new_releases,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Versión $version',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.blue.shade200
                                      : Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tu versión: $_currentVersion',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (releaseNotes.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '🎉 Novedades:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        releaseNotes,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                  if (isRequired) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withOpacity(0.3)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.shade700
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esta actualización es obligatoria para continuar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.red.shade300
                                    : Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRequired ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(isRequired ? double.infinity : 120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (Platform.isAndroid && downloadUrl.isNotEmpty) {
                    _downloadAndInstallApk(downloadUrl, version);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Actualizar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mostrar diálogo cuando la app está actualizada
  void _showUpToDateDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: MediaQuery.of(context).size.width * 0.3,
              ),
              const SizedBox(height: 8),
              Text(
                '¡Todo al día!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ya tienes la versión más reciente instalada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versión $_currentVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade200 : Colors.blue,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Aceptar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Descargar e instalar APK
  final Dio _dio = Dio();
  // ignore: unused_field
  double _downloadProgress = 0.0;

  Future<void> _downloadAndInstallApk(String apkUrl, String version) async {
    if (!Platform.isAndroid) return;

    try {
      // 🔒 Verificar/Solicitar permiso de instalación (REQUEST_INSTALL_PACKAGES)
      // Este es el único permiso realmente necesario para instalar APKs
      final installStatus = await Permission.requestInstallPackages.status;
      debugPrint('📋 Estado permiso instalación: $installStatus');

      if (!installStatus.isGranted) {
        // Mostrar diálogo explicativo
        final shouldRequest = await _showInstallPermissionDialog();
        if (!shouldRequest) {
          debugPrint('❌ Usuario canceló solicitud de permiso');
          return;
        }

        // Solicitar el permiso
        final installResult = await Permission.requestInstallPackages.request();
        debugPrint('📋 Resultado solicitud permiso: $installResult');

        if (!installResult.isGranted) {
          if (installResult.isPermanentlyDenied) {
            debugPrint('🚫 Permiso denegado permanentemente');
            _showOpenSettingsDialog();
          } else {
            debugPrint('❌ Permiso denegado');
            _showPermissionError(
                'Para instalar actualizaciones necesitas activar "Instalar apps desconocidas"');
          }
          return;
        }
      }

      debugPrint('✅ Permisos verificados, iniciando descarga...');

      _apkDownloadCancelToken?.cancel('Starting a new download');
      _apkDownloadCancelToken = CancelToken();

      if (mounted && !_isDisposed) {
        setState(() {
          _downloadProgress = 0.0;
        });
      }
      if (!_isDisposed) {
        _downloadProgressNotifier.value = 0.0;
        _downloadedBytesNotifier.value = 0;
        _downloadTotalBytesNotifier.value = 0;
      }

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildDownloadDialog(version),
      );

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

      // Descargar el APK
      await _dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (_isDisposed) return;

          _downloadedBytesNotifier.value = received;
          _downloadTotalBytesNotifier.value = total;

          if (total != -1) {
            final progress = received / total;
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
            _downloadProgressNotifier.value = progress;
          } else {
            // Sin content-length: mostrar barra indeterminada para indicar actividad.
            _downloadProgressNotifier.value = null;
          }
        },
        cancelToken: _apkDownloadCancelToken,
        options: Options(
          followRedirects: true,
          receiveTimeout: Duration(minutes: 5),
        ),
      );

      debugPrint('✅ Descarga completada: $filePath');

      // Cerrar diálogo de progreso
      if (mounted) {
        _closeDownloadDialogIfOpen();
      }

      // Instalar el APK
      await _installApk(filePath);
      _apkDownloadCancelToken = null;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint('ℹ️ Descarga cancelada por dispose/navegación');
        return;
      }

      debugPrint('❌ Error al descargar/instalar: $e');
      if (mounted) {
        _closeDownloadDialogIfOpen();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _downloadProgress = 0.0;
        });
      }
      if (!_isDisposed) {
        _downloadProgressNotifier.value = 0.0;
        _downloadedBytesNotifier.value = 0;
        _downloadTotalBytesNotifier.value = 0;
      }
      _apkDownloadCancelToken = null;
    }
  }

  void _closeDownloadDialogIfOpen() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Construir diálogo de descarga con progreso
  Widget _buildDownloadDialog(String version) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return AlertDialog(
      backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      contentPadding: EdgeInsets.all(20),
      content: ValueListenableBuilder<double?>(
        valueListenable: _downloadProgressNotifier,
        builder: (context, progress, _) {
          return ValueListenableBuilder<int>(
            valueListenable: _downloadedBytesNotifier,
            builder: (context, downloadedBytes, __) {
              return ValueListenableBuilder<int>(
                valueListenable: _downloadTotalBytesNotifier,
                builder: (context, totalBytes, ___) {
                  final downloadedMb = downloadedBytes / (1024 * 1024);
                  final totalMb =
                      totalBytes > 0 ? totalBytes / (1024 * 1024) : 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_download_rounded,
                        color: Colors.blue,
                        size: MediaQuery.of(context).size.width * 0.25,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Descargando',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Versión $version',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        progress != null
                            ? '${(progress * 100).toStringAsFixed(0)}%'
                            : '${downloadedMb.toStringAsFixed(1)} MB descargados',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        totalBytes > 0
                            ? '${downloadedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB'
                            : 'Conectando al servidor...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
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
              content: Text('Instalación iniciada. Sigue las instrucciones.'),
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

  // Mostrar diálogo para solicitar permiso de instalación
  Future<bool> _showInstallPermissionDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            contentPadding: EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.install_mobile_rounded,
                  color: Colors.blue,
                  size: MediaQuery.of(context).size.width * 0.25,
                ),
                SizedBox(height: 12),
                Text(
                  'Permiso Necesario',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Para instalar actualizaciones automáticamente, necesitas activar:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.shade900.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '"Instalar apps desconocidas"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Es seguro, solo se usará para actualizar esta aplicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar', style: TextStyle(fontSize: 15)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(120, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Activar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Mostrar diálogo para abrir configuración
  void _showOpenSettingsDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        contentPadding: EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_rounded,
              color: Colors.orange,
              size: MediaQuery.of(context).size.width * 0.25,
            ),
            SizedBox(height: 12),
            Text(
              'Configuración Necesaria',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Para instalar actualizaciones, sigue estos pasos:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildStep('1', 'Abre la Configuración de REFMP', isDark),
            _buildStep('2', 'Busca "Instalar apps desconocidas"', isDark),
            _buildStep('3', 'Activa el interruptor', isDark),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.shade900.withOpacity(0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Te llevaremos directamente a la configuración',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: Size(120, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 18),
                SizedBox(width: 6),
                Text(
                  'Ir a Ajustes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para los pasos del diálogo
  Widget _buildStep(String number, String text, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // Mostrar error de permisos
  void _showPermissionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Configuración',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final box = Hive.box('offline_data');
      const cacheKey = 'user_profile_image';

      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        final cachedProfileImage = box.get(cacheKey);
        if (cachedProfileImage != null && mounted) {
          setState(() {
            profileImageUrl = cachedProfileImage;
          });
        }
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'guests'
      ];

      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && response['profile_image'] != null) {
          final imageUrl = response['profile_image'];
          // Pre-cache the profile image
          await CustomCacheManager.instance.downloadFile(imageUrl);
          if (mounted) {
            setState(() {
              profileImageUrl = imageUrl;
            });
          }
          await box.put(cacheKey, imageUrl);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  Future<void> fetchGamesData() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'games_data';

    final cachedGames = box.get(cacheKey);
    if (cachedGames != null && mounted) {
      setState(() {
        games = cachedGames;
      });
      debugPrint('Juegos cargados desde cache');
    }

    final isOnline = await _checkConnectivity();
    if (!isOnline) return;

    try {
      final response = await supabase.from('games').select();
      if (mounted && response != null) {
        // Pre-cache game images
        for (var game in response) {
          final imageUrl = game['image'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        if (mounted) {
          setState(() {
            games = response;
          });
        }
        await box.put(cacheKey, response);
        debugPrint('Juegos actualizados y guardados en cache');
      }
    } catch (e) {
      debugPrint('Error al obtener juegos: $e');
    }
  }

  Future<void> fetchSedes() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'sedes_data';

    final cachedSedes = box.get(cacheKey);
    if (cachedSedes != null) {
      if (!mounted) return;
      setState(() {
        sedes = cachedSedes;
      });
      debugPrint('Sedes cargadas desde cache');
    }
    final isOnline = await _checkConnectivity();
    if (!isOnline) return;

    try {
      final response =
          await supabase.from('sedes').select().order('name', ascending: true);
      if (!mounted) return;
      if (response != null) {
        // Pre-cache sede images
        for (var sede in response) {
          final imageUrl = sede['photo'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        setState(() {
          sedes = response;
        });
        await box.put(cacheKey, response);
        debugPrint('Sedes actualizadas y guardadas en cache');
      }
    } catch (e) {
      debugPrint('Error al obtener sedes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTeachers() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'all_teachers_data';

    final cachedTeachers = box.get(cacheKey);
    if (cachedTeachers != null) {
      return List<Map<String, dynamic>>.from(
        cachedTeachers.map((item) => Map<String, dynamic>.from(item)),
      );
    }

    final isOnline = await _checkConnectivity();
    if (!isOnline) return [];

    try {
      final response = await supabase.from('teachers').select();
      if (response != null) {
        await box.put(cacheKey, response);
        return List<Map<String, dynamic>>.from(
          response.map((item) => Map<String, dynamic>.from(item)),
        );
      }
    } catch (e) {
      debugPrint('Error al obtener todos los profesores: $e');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
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
          centerTitle: true,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          actions: [
            GestureDetector(
              onTap: () {
                Menu.currentIndexNotifier.value = 1;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(title: "Perfil"),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: ClipOval(
                  child: profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: profileImageUrl!,
                          cacheManager: CustomCacheManager.instance,
                          fit: BoxFit.cover,
                          width: 35,
                          height: 35,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(
                                  color: Colors.white),
                          errorWidget: (context, url, error) => Image.asset(
                            "assets/images/refmmp.png",
                            fit: BoxFit.cover,
                            width: 35,
                            height: 35,
                          ),
                        )
                      : Image.asset(
                          "assets/images/refmmp.png",
                          fit: BoxFit.cover,
                          width: 35,
                          height: 35,
                        ),
                ),
              ),
            ),
          ],
        ),
        drawer: Menu.buildDrawer(context),
        body: RefreshIndicator(
          color: Colors.blue,
          onRefresh: () async {
            await fetchSedes();
            await fetchGamesData();
            await fetchUserProfileImage();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    child: Image.asset(
                      themeProvider.isDarkMode
                          ? "assets/images/appbar.png"
                          : "assets/images/logofn.png",
                    ),
                  ),
                  const SizedBox(height: 3),
                  Divider(
                    height: 40,
                    thickness: 2,
                    color: themeProvider.isDarkMode
                        ? const Color.fromARGB(255, 34, 34, 34)
                        : const Color.fromARGB(255, 236, 234, 234),
                  ),
                  const Text(
                    'Sedes',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 340, // Aumenta la altura aquí
                    child: sedes.isEmpty
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.blue))
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: sedes.length,
                            onPageChanged: (index) {
                              if (mounted) {
                                setState(() {
                                  _currentPage = index;
                                });
                              }
                            },
                            itemBuilder: (context, index) {
                              final sede = sedes[index];
                              final id = sede["id"]?.toString() ?? "";
                              final name =
                                  sede["name"] ?? "Nombre no disponible";
                              final address =
                                  sede["address"] ?? "Dirección no disponible";
                              final description =
                                  (sede["description"] ?? "Sin descripción")
                                      .toString();
                              final contactNumber =
                                  sede["contact_number"] ?? "No disponible";
                              final photo = sede["photo"] ?? "";

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HeadquartersInfo(
                                        id: id,
                                        name: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.all(10),
                                  elevation: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(10)),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height:
                                              150, // Imagen un poco más grande
                                          child: (photo.isNotEmpty)
                                              ? CachedNetworkImage(
                                                  imageUrl: photo,
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.blue),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/refmmp.png',
                                                    width: double.infinity,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Image.asset(
                                                  'assets/images/refmmp.png',
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              description.length > 100
                                                  ? '${description.substring(0, 100)}...'
                                                  : description,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on,
                                                    color: Colors.blue,
                                                    size: 18),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    address,
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      decoration: TextDecoration
                                                          .underline,
                                                      decorationColor:
                                                          Colors.blue,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                const Icon(Icons.phone,
                                                    color: Colors.blue,
                                                    size: 18),
                                                const SizedBox(width: 5),
                                                const Text("🇨🇴",
                                                    style: TextStyle(
                                                        fontSize: 13)),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  "+57 ",
                                                  style:
                                                      TextStyle(fontSize: 14),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    contactNumber,
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      sedes.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.blue
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Aprende y Juega - Solo visible si NO es invitado
                  FutureBuilder<bool>(
                    future: _isGuest(),
                    builder: (context, snapshot) {
                      // Si es invitado, no mostrar nada
                      if (snapshot.hasData && snapshot.data == true) {
                        return const SizedBox.shrink();
                      }

                      // Si no es invitado, mostrar la sección
                      return Column(
                        children: [
                          Divider(
                            height: 40,
                            thickness: 2,
                            color: themeProvider.isDarkMode
                                ? const Color.fromARGB(255, 34, 34, 34)
                                : const Color.fromARGB(255, 236, 234, 234),
                          ),
                          const Text(
                            "Aprende y Juega",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(height: 20),
                          games.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blue))
                              : Column(
                                  children: [
                                    SizedBox(
                                      height: 400,
                                      child: PageView.builder(
                                        controller: _gamesPageController,
                                        itemCount: games.length,
                                        onPageChanged: (index) {
                                          if (mounted) {
                                            setState(() {
                                              _currentGamePage = index;
                                            });
                                          }
                                        },
                                        itemBuilder: (context, index) {
                                          final game = games[index];
                                          final description =
                                              game['description'] ??
                                                  'Sin descripción';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            child: Card(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              elevation: 4,
                                              child: Column(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                            top:
                                                                Radius.circular(
                                                                    16)),
                                                    child: game['image'] !=
                                                                null &&
                                                            game['image']
                                                                .isNotEmpty
                                                        ? CachedNetworkImage(
                                                            imageUrl:
                                                                game['image'],
                                                            cacheManager:
                                                                CustomCacheManager
                                                                    .instance,
                                                            fit: BoxFit.cover,
                                                            width:
                                                                double.infinity,
                                                            height: 180,
                                                            placeholder: (context,
                                                                    url) =>
                                                                const Center(
                                                                    child: CircularProgressIndicator(
                                                                        color: Colors
                                                                            .blue)),
                                                            errorWidget: (context,
                                                                    url,
                                                                    error) =>
                                                                const Icon(
                                                                    Icons
                                                                        .image_not_supported,
                                                                    size: 80),
                                                          )
                                                        : const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 80),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12.0),
                                                    child: Column(
                                                      children: [
                                                        const SizedBox(
                                                            height: 10),
                                                        Text(
                                                          game['name'] ??
                                                              "Nombre desconocido",
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          description,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 15),
                                                        ),
                                                        const SizedBox(
                                                            height: 15),
                                                        ElevatedButton.icon(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors.blue,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10)),
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        20,
                                                                    vertical:
                                                                        12),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    LearningPage(
                                                                        instrumentName:
                                                                            game['name']),
                                                              ),
                                                            );
                                                          },
                                                          icon: const Icon(
                                                              Icons
                                                                  .sports_esports_rounded,
                                                              color:
                                                                  Colors.white),
                                                          label: const Text(
                                                              "Aprende y Juega",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        games.length,
                                        (index) => AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentGamePage == index
                                                ? Colors.blue
                                                : Colors.grey[400],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
