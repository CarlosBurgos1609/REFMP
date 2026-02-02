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

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
    fetchSedes();
    fetchGamesData();
    _checkNotificationPermission();

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // Conexión restaurada, recarga los datos
        await fetchSedes();
        await fetchGamesData();
        await fetchUserProfileImage();
      }
    });

    _pageController = PageController(viewportFraction: 0.9);
    _startAutoScroll();

    _gamesPageController = PageController(viewportFraction: 0.95);
    _startAutoScrollGames();
  }

  @override
  void dispose() {
    _timer.cancel(); // <-- Cancela el timer primero
    _pageController.dispose();
    _gamesTimer.cancel();
    _gamesPageController.dispose();
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

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final box = Hive.box('offline_data');
      const cacheKey = 'user_profile_image';

      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        final cachedProfileImage = box.get(cacheKey);
        if (cachedProfileImage != null) {
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
          setState(() {
            profileImageUrl = imageUrl;
          });
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
    if (cachedGames != null) {
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
        setState(() {
          games = response;
        });
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
                              setState(() {
                                _currentPage = index;
                              });
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
                                          setState(() {
                                            _currentGamePage = index;
                                          });
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
