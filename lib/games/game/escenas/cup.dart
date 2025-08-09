// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
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
    ensureCurrentUserInUsersGames();
  }

  Future<void> _checkConnectivityAndInitialize() async {
    bool isOnline = await _checkConnectivity();
    setState(() {
      _isOnline = isOnline;
      _cupFuture = fetchCupData(); // Initialize with fresh data
    });
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;
    debugPrint('Connectivity status: ${isOnline ? 'Online' : 'Offline'}');
    return isOnline;
  }

  Future<void> ensureCurrentUserInUsersGames() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('No authenticated user found for users_games insertion');
      return;
    }

    try {
      if (_isOnline) {
        final response = await supabase
            .from('users_games')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (response == null) {
          final nickname = user.userMetadata?['full_name'] ?? 'user_${user.id}';
          await supabase.from('users_games').insert({
            'user_id': user.id,
            'nickname': nickname,
            'points_xp_totally': 0,
            'points_xp_weekend': 0,
            'coins': 0,
          });
          debugPrint(
              'Inserted current user ${user.id} into users_games with nickname $nickname');
        } else {
          debugPrint('Current user ${user.id} already exists in users_games');
        }
      }
    } catch (e) {
      debugPrint(
          'Error al asegurar registro del usuario actual en users_games: $e');
    }
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return;
      }

      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        debugPrint('Offline: No profile image available');
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
    try {
      if (!_isOnline) {
        debugPrint('Offline: No data available');
        return [];
      }

      final currentUser = supabase.auth.currentUser;
      debugPrint('Fetching cup data for user_id: ${currentUser?.id}');

      // Fetch top 50 users from users_games with points_xp_weekend > 0
      final response = await supabase
          .from('users_games')
          .select('user_id, nickname, points_xp_weekend')
          .gt('points_xp_weekend', 0)
          .order('points_xp_weekend', ascending: false)
          .limit(50);

      debugPrint(
          'Supabase response: ${response.length} users fetched: $response');

      List<Map<String, dynamic>> data = [];
      final tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'directors'
      ];

      for (var item in response) {
        String? profileImage;
        final userId = item['user_id'];
        for (String table in tables) {
          final profileResponse = await supabase
              .from(table)
              .select('profile_image')
              .eq('user_id', userId)
              .maybeSingle();
          if (profileResponse != null &&
              profileResponse['profile_image'] != null) {
            profileImage = profileResponse['profile_image'];
            debugPrint(
                'Found profile_image for user_id $userId in $table: $profileImage');
            break;
          }
        }

        data.add({
          'user_id': item['user_id'],
          'nickname': item['nickname'] ?? 'Anónimo',
          'points_xp_weekend': item['points_xp_weekend'] ?? 0,
          'profile_image': profileImage ?? 'assets/images/refmmp.png',
        });
      }

      if (data.isEmpty) {
        debugPrint('No users with points found in users_games');
      } else {
        debugPrint('Processed ${data.length} users: $data');
      }

      return data;
    } catch (e, stackTrace) {
      debugPrint(
          'Error al obtener datos de la copa: $e\nStack trace: $stackTrace');
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
                  LearningPage(instrumentName: widget.instrumentName)),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  MusicPage(instrumentName: widget.instrumentName)),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  CupPage(instrumentName: widget.instrumentName)),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ObjetsPage(instrumentName: widget.instrumentName)),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  ProfilePageGame(instrumentName: widget.instrumentName)),
        );
        break;
    }
  }

  bool _needsMarquee(String text, double maxWidth, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return textPainter.size.width > maxWidth;
  }

  Widget _buildNicknameWidget(String nickname, bool isCurrentUser) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
    );
    const maxWidth = 125.0; // Aumentamos el maxWidth para dar más espacio

    if (_needsMarquee(nickname, maxWidth, textStyle)) {
      return SizedBox(
        width: maxWidth,
        height: 24,
        child: Marquee(
          text: nickname,
          style: textStyle,
          scrollAxis: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.center,
          blankSpace: 20.0,
          velocity: 60.0, // Aumentamos la velocidad
          pauseAfterRound: const Duration(milliseconds: 1000),
          startPadding: 10.0,
          accelerationDuration: const Duration(milliseconds: 500),
          accelerationCurve: Curves.easeInOut,
          decelerationDuration: const Duration(milliseconds: 500),
          decelerationCurve: Curves.easeInOut,
        ),
      );
    } else {
      return Text(
        nickname,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
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
          debugPrint('Refreshing data...');
          await _checkConnectivityAndInitialize();
          setState(() {
            _cupFuture = fetchCupData();
          });
          debugPrint('Refresh completed, new _cupFuture assigned');
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Clasificación',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          // shadows: [
                          //   Shadow(
                          //     color: Colors.black,
                          //     offset: Offset(1, 0),
                          //     blurRadius: 8,
                          //   ),
                          // ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 1),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cupFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          debugPrint('FutureBuilder: Waiting for data...');
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue));
                        }
                        if (snapshot.hasError) {
                          debugPrint('FutureBuilder error: ${snapshot.error}');
                          return const Center(
                              child: Text('Error al cargar los datos.'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          debugPrint('FutureBuilder: No data or empty data');
                          return const Center(
                              child: Text(
                                  'No hay usuarios con puntos disponibles.'));
                        }

                        final cupList = snapshot.data!;
                        debugPrint(
                            'FutureBuilder: Rendering ${cupList.length} users');

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cupList.length,
                          itemBuilder: (context, index) {
                            final item = cupList[index];
                            final String nickname =
                                item['nickname'] ?? 'Anónimo';
                            final int points = item['points_xp_weekend'] ?? 0;
                            final String? profileImage = item['profile_image'];
                            final bool isCurrentUser =
                                user != null && item['user_id'] == user.id;
                            final borderColor =
                                isCurrentUser ? Colors.blue : Colors.grey;

                            debugPrint(
                                'Building item $index: nickname=$nickname, points=$points, user_id=${item['user_id']}');

                            return VisibilityDetector(
                              key: Key('user_$index'),
                              onVisibilityChanged: (visibilityInfo) {
                                // Optional: Handle visibility changes
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Container(
                                  width: double
                                      .infinity, // Ocupa el ancho completo
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
                                      Text(
                                        '${index + 1}', // Continúa el contador (1, 2, 3, 4, ...)
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: index < 3
                                              ? Colors.blue
                                              : Colors.blue,
                                        ),
                                      ),
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
                                        backgroundColor: Colors.transparent,
                                        backgroundImage: (profileImage !=
                                                    null &&
                                                Uri.tryParse(profileImage)
                                                        ?.isAbsolute ==
                                                    true)
                                            ? NetworkImage(profileImage)
                                            : const AssetImage(
                                                    'assets/images/refmmp.png')
                                                as ImageProvider,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: _buildNicknameWidget(
                                                  nickname, isCurrentUser),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '$points ',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  'XP',
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
