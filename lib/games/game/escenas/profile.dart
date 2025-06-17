import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePageGame extends StatefulWidget {
  final String instrumentName;
  const ProfilePageGame({super.key, required this.instrumentName});

  @override
  State<ProfilePageGame> createState() => _ProfilePageGameState();
}

class _ProfilePageGameState extends State<ProfilePageGame>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? profileImageUrl;
  String? firstName;
  String? lastName;
  String? fullName;
  String? userName;

  int pointsXpTotally = 0;
  int pointsXpWeekend = 0;
  int coins = 0;

  late TabController _tabController;
  int _selectedIndex = 4;
  String? _userTable;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeHiveAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeHiveAndFetch() async {
    try {
      if (!Hive.isBoxOpen('offline_data')) {
        await Hive.openBox('offline_data');
      }
      debugPrint('Hive box offline_data opened successfully');
      await fetchData();
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
    }
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
      if (user == null) {
        debugPrint('No user logged in');
        return;
      }

      final box = Hive.box('offline_data');
      final isOnline = await _checkConnectivity();
      final cacheKey = 'user_data_${user.id}_profile_image';

      if (!isOnline) {
        final cachedProfileImage = box.get(cacheKey);
        if (cachedProfileImage != null) {
          setState(() {
            profileImageUrl = cachedProfileImage;
          });
          debugPrint('Loaded profile image from cache: $cachedProfileImage');
        } else {
          debugPrint('No cached profile image found for key: $cacheKey');
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
          setState(() {
            profileImageUrl = response['profile_image'];
          });
          await box.put(cacheKey, response['profile_image']);
          debugPrint(
              'Profile image saved to cache: ${response['profile_image']}');
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  Future<void> fetchData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return;
    }

    final box = Hive.box('offline_data');
    final cacheKeyPrefix = 'user_data_${user.id}';
    final isOnline = await _checkConnectivity();

    debugPrint('Fetching user data, Online: $isOnline');

    if (!isOnline) {
      setState(() {
        profileImageUrl = box.get('${cacheKeyPrefix}_profile_image');
        firstName = box.get('${cacheKeyPrefix}_first_name', defaultValue: '');
        lastName = box.get('${cacheKeyPrefix}_last_name', defaultValue: '');
        userName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        fullName =
            box.get('${cacheKeyPrefix}_nickname', defaultValue: 'Sin nickname');
        pointsXpTotally =
            box.get('${cacheKeyPrefix}_points_xp_totally', defaultValue: 0);
        pointsXpWeekend =
            box.get('${cacheKeyPrefix}_points_xp_weekend', defaultValue: 0);
        coins = box.get('${cacheKeyPrefix}_coins', defaultValue: 0);
      });
      debugPrint('Loaded user data from cache with prefix: $cacheKeyPrefix');
      return;
    }

    try {
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
            .select(
                'profile_image, first_name, last_name, nickname, points_xp_totally, points_xp_weekend, coins')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            profileImageUrl = response['profile_image'];
            firstName = response['first_name'];
            lastName = response['last_name'];
            userName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
            fullName = response['nickname'] ?? 'Sin nickname';
            pointsXpTotally = response['points_xp_totally'] ?? 0;
            pointsXpWeekend = response['points_xp_weekend'] ?? 0;
            coins = response['coins'] ?? 0;
            _userTable = table;
          });

          // Guardar en Hive
          await box.put(
              '${cacheKeyPrefix}_profile_image', response['profile_image']);
          await box.put('${cacheKeyPrefix}_first_name', response['first_name']);
          await box.put('${cacheKeyPrefix}_last_name', response['last_name']);
          await box.put('${cacheKeyPrefix}_nickname', response['nickname']);
          await box.put('${cacheKeyPrefix}_points_xp_totally',
              response['points_xp_totally']);
          await box.put('${cacheKeyPrefix}_points_xp_weekend',
              response['points_xp_weekend']);
          await box.put('${cacheKeyPrefix}_coins', response['coins']);
          debugPrint('User data saved to Hive with prefix: $cacheKeyPrefix');
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
      // Intentar cargar desde caché si hay error
      setState(() {
        profileImageUrl = box.get('${cacheKeyPrefix}_profile_image');
        firstName = box.get('${cacheKeyPrefix}_first_name', defaultValue: '');
        lastName = box.get('${cacheKeyPrefix}_last_name', defaultValue: '');
        userName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
        fullName =
            box.get('${cacheKeyPrefix}_nickname', defaultValue: 'Sin nickname');
        pointsXpTotally =
            box.get('${cacheKeyPrefix}_points_xp_totally', defaultValue: 0);
        pointsXpWeekend =
            box.get('${cacheKeyPrefix}_points_xp_weekend', defaultValue: 0);
        coins = box.get('${cacheKeyPrefix}_coins', defaultValue: 0);
      });
      debugPrint('Loaded user data from cache due to error');
    }
  }

  void _editFullName() async {
    final controller = TextEditingController(text: fullName);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Center(
          child: Text(
            "Editar Nickname",
            style: TextStyle(color: Colors.blue),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nuevo Nickname"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = supabase.auth.currentUser;
              if (user != null && _userTable != null) {
                final isOnline = await _checkConnectivity();
                if (!isOnline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "No hay conexión. Los cambios se guardarán cuando estés en línea.")),
                  );
                }

                setState(() {
                  fullName = controller.text;
                });

                final box = Hive.box('offline_data');
                await box.put('user_data_${user.id}_nickname', controller.text);

                if (isOnline) {
                  try {
                    await supabase.from(_userTable!).update(
                        {'nickname': controller.text}).eq('user_id', user.id);
                    debugPrint(
                        'Nickname updated in Supabase: ${controller.text}');
                  } catch (e) {
                    debugPrint('Error updating nickname: $e');
                  }
                }
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Guardar",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LearningPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MusicPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CupPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ObjetsPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfilePageGame(instrumentName: widget.instrumentName),
          ),
        );
        break;
    }
  }

  Widget _buildProfileHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        const SizedBox(height: 24),
        profileImageUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: profileImageUrl!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(color: Colors.blue),
                  errorWidget: (context, url, error) => const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                ),
              )
            : const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
        const SizedBox(height: 12),
        Text(
          userName?.isNotEmpty ?? false ? userName! : 'Usuario sin nombre',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fullName?.isNotEmpty ?? false ? fullName! : 'Sin nickname',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _editFullName,
              child: Icon(Icons.edit, size: 18, color: Colors.grey[400]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contenedor para EXP Totales
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.blue
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: Colors.yellow,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pointsXpTotally',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[200]
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EXP Totales',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[200]
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            // Contenedor para EXP Semanal
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.blue
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: Colors.yellow,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pointsXpWeekend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[200]
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EXP Semanal',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[200]
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            // Contenedor para Monedas
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? Colors.blue
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.yellow,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$coins',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[200]
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monedas',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.isDarkMode
                          ? Colors.grey[200]
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(
          height: 40,
          thickness: 2,
          color: themeProvider.isDarkMode
              ? const Color.fromARGB(255, 34, 34, 34)
              : const Color.fromARGB(255, 236, 234, 234),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Perfil",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[300],
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(icon: Icon(Icons.favorite_rounded), text: "Favoritos"),
              Tab(icon: Icon(Icons.shopping_bag_rounded), text: "Objetos"),
              Tab(icon: Icon(Icons.history_rounded), text: "Historial"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                Center(child: Text('🎵 No tienes Canciones favoritas 🎵')),
                Center(child: Text('🎁 No tienes Objetos 🎁')),
                Center(child: Text('⌚ No tienes Historial de experiencia ⌚')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
