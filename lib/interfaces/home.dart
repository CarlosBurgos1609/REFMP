// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
    _pageController.dispose();
    _timer.cancel();
    _gamesPageController.dispose();
    _gamesTimer.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (sedes.isNotEmpty) {
        if (_currentPage < sedes.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startAutoScrollGames() {
    _gamesTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (games.isNotEmpty) {
        if (_currentGamePage < games.length - 1) {
          _currentGamePage++;
        } else {
          _currentGamePage = 0;
        }
        _gamesPageController.animateToPage(
          _currentGamePage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
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
        'parents'
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
      final response = await supabase.from('sedes').select();
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
                  sedes.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.blue))
                      : Column(
                          children: [
                            SizedBox(
                              height: 300,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: sedes.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPage = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final sede = sedes[index];
                                  final name =
                                      sede["name"] ?? "Nombre no disponible";
                                  final address = sede["address"] ??
                                      "Dirección no disponible";
                                  final photo = sede["photo"];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2.0),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(20)),
                                              child: photo != null &&
                                                      photo.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: photo,
                                                      cacheManager:
                                                          CustomCacheManager
                                                              .instance,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context,
                                                              url) =>
                                                          const Center(
                                                              child: CircularProgressIndicator(
                                                                  color: Colors
                                                                      .blue)),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Image.asset(
                                                              "assets/images/refmmp.png",
                                                              fit:
                                                                  BoxFit.cover),
                                                    )
                                                  : Image.asset(
                                                      "assets/images/refmmp.png",
                                                      fit: BoxFit.cover),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Dirección: $address",
                                                    style: const TextStyle(
                                                        fontSize: 13),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
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
                          ],
                        ),
                  const SizedBox(height: 20),
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
                          child: CircularProgressIndicator(color: Colors.blue))
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
                                      game['description'] ?? 'Sin descripción';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      elevation: 4,
                                      child: Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(16)),
                                            child: game['image'] != null &&
                                                    game['image'].isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: game['image'],
                                                    cacheManager:
                                                        CustomCacheManager
                                                            .instance,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 180,
                                                    placeholder: (context,
                                                            url) =>
                                                        const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                                    color: Colors
                                                                        .blue)),
                                                    errorWidget: (context, url,
                                                            error) =>
                                                        const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 80),
                                                  )
                                                : const Icon(
                                                    Icons.image_not_supported,
                                                    size: 80),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 10),
                                                Text(
                                                  game['name'] ??
                                                      "Nombre desconocido",
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  description,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 15),
                                                ),
                                                const SizedBox(height: 15),
                                                ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 20,
                                                        vertical: 12),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            LearningPage(
                                                                instrumentName:
                                                                    game[
                                                                        'name']),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                      Icons
                                                          .sports_esports_rounded,
                                                      color: Colors.white),
                                                  label: const Text(
                                                      "Aprende y Juega",
                                                      style: TextStyle(
                                                          color: Colors.white)),
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
                                games.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
