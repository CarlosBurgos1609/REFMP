import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> fetchUserProfileImage() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

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
        setState(() {
          profileImageUrl = response['profile_image'];
        });
        break;
      }
    }
  }

  Future<void> fetchGamesData() async {
    try {
      final response = await supabase.from('games').select('*');
      if (mounted) {
        setState(() {
          games = response;
        });
      }
    } catch (e) {
      debugPrint('Error al obtener los juegos: $e');
    }
  }

  Future<void> fetchSedes() async {
    final response = await supabase.from('sedes').select();
    if (mounted) {
      setState(() {
        sedes = response;
      });
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
              fontSize: 22,
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
                  child: profileImageUrl != null
                      ? Image.network(
                          profileImageUrl!,
                          fit: BoxFit.cover,
                          width: 35,
                          height: 35,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              "assets/images/refmmp.png",
                              fit: BoxFit.cover,
                              width: 35,
                              height: 35,
                            );
                          },
                        )
                      : Image.asset(
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
        body: RefreshIndicator(
            color: Colors.blue,
            onRefresh: () async {
              await fetchSedes();
              await fetchGamesData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Column(
                  children: [
                    Image.asset("assets/images/logofn.png"),
                    const SizedBox(height: 30),
                    Divider(
                      height: 40,
                      thickness: 2,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 34, 34, 34)
                          : const Color.fromARGB(255, 197, 196, 196),
                    ),
                    const Text(
                      'Sedes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    sedes.isEmpty
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.blue))
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius
                                                    .vertical(
                                                    top: Radius.circular(20)),
                                                child: photo != null
                                                    ? Image.network(
                                                        photo,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return Image.asset(
                                                              "assets/images/refmmp.png",
                                                              fit:
                                                                  BoxFit.cover);
                                                        },
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
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
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
                          : const Color.fromARGB(255, 197, 196, 196),
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
                            child:
                                CircularProgressIndicator(color: Colors.blue))
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
                                    final description = game['description'] ??
                                        'Sin descripción';
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
                                              child: Image.network(
                                                game['image'] ?? '',
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: 160,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 80),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Column(
                                                children: [
                                                  Text(
                                                    game['name'] ??
                                                        "Nombre desconocido",
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                  const SizedBox(height: 10),
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton
                                                        .styleFrom(
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
                                                            color:
                                                                Colors.white)),
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
                ),
              ),
            )),
      ),
    );
  }
}
