// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
  int _selectedIndex = 2;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInitialize();
    fetchUserProfileImage();
  }

  Future<void> _checkConnectivityAndInitialize() async {
    bool isOnline = await _checkConnectivity();
    setState(() {
      _isOnline = isOnline;
    });
    _cupFuture = fetchCupData();
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;
    debugPrint('Connectivity status: ${isOnline ? 'Online' : 'Offline'}');
    return isOnline;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return;
      }

      final isOnline = await _checkConnectivity();
      final box = Hive.box('offline_data');
      final cacheKey = 'user_profile_image_${user.id}';

      if (!isOnline) {
        final cached = box.get(cacheKey);
        if (cached != null) {
          setState(() => profileImageUrl = cached);
        }
        debugPrint('Offline: Using cached profile image: $cached');
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'directors'
      ];
      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', user.id)
            .maybeSingle();
        if (response != null && response['profile_image'] != null) {
          setState(() => profileImageUrl = response['profile_image']);
          await box.put(cacheKey, response['profile_image']);
          debugPrint(
              'Fetched profile image from $table: ${response['profile_image']}');
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener imagen de perfil: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCupData() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'cup_data_${widget.instrumentName}';

    try {
      if (!_isOnline) {
        final cached = box.get(cacheKey, defaultValue: []);
        if (cached is List && cached.isNotEmpty) {
          debugPrint('Returning cached data: $cached');
          return List<Map<String, dynamic>>.from(
              cached.map((item) => Map<String, dynamic>.from(item)));
        }
        debugPrint('No cached data available');
        return [];
      }

      // Fetch all users from users_games, no filtering by points
      final response = await supabase
          .from('users_games')
          .select('nickname, points_xp_weekend, users.profile_image')
          .order('points_xp_weekend', ascending: false)
          .limit(50);

      debugPrint('Supabase response: $response');

      final data = response
          .map<Map<String, dynamic>>((item) => {
                'nickname': item['nickname'] ?? 'Anónimo',
                'points_xp_weekend': item['points_xp_weekend'] ?? 0,
                'profile_image':
                    item['profile_image'] ?? 'assets/images/refmmp.png',
              })
          .toList();

      if (data.isEmpty) {
        debugPrint('No users found in users_games');
      } else {
        debugPrint('Fetched ${data.length} users: $data');
      }

      await box.put(cacheKey, data);
      return data;
    } catch (e) {
      debugPrint('Error al obtener datos de la copa: $e');
      final cached = box.get(cacheKey, defaultValue: []);
      if (cached is List && cached.isNotEmpty) {
        debugPrint('Returning cached data due to error: $cached');
        return List<Map<String, dynamic>>.from(
            cached.map((item) => Map<String, dynamic>.from(item)));
      }
      return [];
    }
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = supabase.auth.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          await _checkConnectivityAndInitialize();
          final newData = await fetchCupData();
          setState(() {
            _cupFuture = Future.value(newData);
          });
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400.0,
              floating: false,
              pinned: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          LearningPage(instrumentName: widget.instrumentName),
                    ),
                  );
                },
              ),
              backgroundColor: Colors.blue,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text(
                  'Torneo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                background: Image.asset(
                  'assets/images/cups.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading cups.png: $error');
                    return Image.asset(
                      'assets/images/refmmp.png',
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Clasificación',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(2, 1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 40,
                      thickness: 2,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 34, 34, 34)
                          : const Color.fromARGB(255, 236, 234, 234),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cupFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('No hay usuarios disponibles.'));
                        }

                        final cupList = snapshot.data!;

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cupList.length,
                          itemBuilder: (context, index) {
                            final item = cupList[index];
                            final String nickname = item['nickname'];
                            final int points = item['points_xp_weekend'];
                            final String? profileImage = item['profile_image'];
                            final bool isCurrentUser = user != null &&
                                nickname.toLowerCase().contains(
                                    (user.userMetadata?['full_name'] ?? '')
                                        .toString()
                                        .toLowerCase());
                            final borderColor =
                                isCurrentUser ? Colors.blue : Colors.grey;

                            return VisibilityDetector(
                              key: Key('user_$index'),
                              onVisibilityChanged: (visibilityInfo) {
                                // Optional: Handle visibility changes
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: borderColor, width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                    color: themeProvider.isDarkMode
                                        ? Colors.black54
                                        : Colors.white,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text('${index + 1}',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: index < 3
                                                  ? Colors.blue
                                                  : Colors.black87)),
                                      const SizedBox(width: 5),
                                      if (index < 3)
                                        Icon(
                                          Icons.emoji_events_rounded,
                                          color: index == 0
                                              ? Colors.amber
                                              : index == 1
                                                  ? Colors.grey
                                                  : const Color(0xFFCD7F32),
                                          size: 30,
                                        ),
                                      const SizedBox(width: 12),
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: profileImage != null &&
                                                Uri.tryParse(profileImage)
                                                        ?.isAbsolute ==
                                                    true
                                            ? NetworkImage(profileImage)
                                            : null,
                                        child: profileImage == null
                                            ? const Icon(Icons.person, size: 32)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                nickname,
                                                style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text('$points ',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .blue.shade700,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14)),
                                                Text('XP',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .blue.shade700,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
