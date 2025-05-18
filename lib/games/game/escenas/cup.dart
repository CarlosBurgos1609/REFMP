import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CupPage extends StatefulWidget {
  final String instrumentName;

  const CupPage({super.key, required this.instrumentName});

  @override
  State<CupPage> createState() => _CupPageState();
}

class _CupPageState extends State<CupPage> {
  final supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _cupFuture;
  String? profileImageUrl;

  int _selectedIndex = 2; // 0: Aprende, 1: Canciones, 2: Torneo, 3: Recompensas

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // evitar recargar la misma página

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
        // Aquí puedes añadir la navegación a RewardsPage cuando esté lista
        break;
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint('Conectividad: $connectivityResult');
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        final box = Hive.box('offline_data');
        const cacheKey = 'user_profile_image';
        final cachedProfileImage = box.get(cacheKey, defaultValue: null);
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
          setState(() {
            profileImageUrl = response['profile_image'];
          });

          final box = Hive.box('offline_data');
          await box.put('user_profile_image', response['profile_image']);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _cupFuture = fetchCupData();
    fetchUserProfileImage();
  }

  Future<List<Map<String, dynamic>>> fetchCupData() async {
    final response = await supabase
        .from('cup')
        .select(
            'user_id, instrument_id, experience_points, user_type, profile_image, full_name')
        .order('experience_points', ascending: false);

    List<Map<String, dynamic>> rankedUsers = [];

    for (final item in response) {
      rankedUsers.add({
        'name': item['full_name'],
        'profile_image': item['profile_image'],
        'experience_points': item['experience_points'],
      });
    }

    return rankedUsers;
  }

  Widget buildMedal(int index) {
    const medalIcons = [
      Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32), // 🥇
      Icon(Icons.emoji_events_rounded, color: Colors.grey, size: 30), // 🥈
      Icon(Icons.emoji_events_rounded,
          color: Color(0xFFCD7F32), size: 30), // 🥉
    ];

    return index < 3
        ? medalIcons[index]
        : Text('${index + 1}', style: const TextStyle(fontSize: 18));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tabla de la Copa",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay datos en la copa."));
          }

          final cupList = snapshot.data!;

          return Column(
            children: [
              const SizedBox(height: 24),
              // Copa grande azul arriba
              Icon(
                Icons.emoji_events_rounded,
                color: Colors.blue.shade700,
                size: 150,
              ),
              const SizedBox(height: 12),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              const SizedBox(height: 8),
              Text(
                "Clasificación",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? Color.fromARGB(255, 255, 255, 255)
                      : Color.fromARGB(255, 33, 150, 243),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.builder(
                  itemCount: cupList.length,
                  itemBuilder: (context, index) {
                    final item = cupList[index];
                    final String name = item['name'];
                    final String? profileImage = item['profile_image'];
                    final int points = item['experience_points'];

                    // ¿Está en el top 3?
                    bool isTop3 = index < 3;

                    // Icono copa dorada para top 3
                    Widget medalIcon = Icon(
                      Icons.emoji_events_rounded,
                      color: index == 0
                          ? Colors.amber
                          : index == 1
                              ? Colors.grey
                              : const Color(0xFFCD7F32),
                      size: 30,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Número de posición
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isTop3 ? Colors.blue : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Copa dorada al lado del número si está en top 3
                          if (isTop3) ...[
                            medalIcon,
                            const SizedBox(width: 12),
                          ],

                          // Imagen perfil redondeada
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: profileImage != null
                                ? NetworkImage(profileImage)
                                : null,
                            child: profileImage == null
                                ? const Icon(Icons.person, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 16),

                          // Nombre y puntos XP
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Nombre
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Puntos experiencia en azul con "XP"
                                Row(
                                  children: [
                                    Text(
                                      "$points ",
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      "XP",
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
