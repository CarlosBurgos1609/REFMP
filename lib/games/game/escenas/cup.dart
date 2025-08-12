// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 200,
      fileService: HttpFileService(),
    ),
  );
}

class CupPage extends StatefulWidget {
  final String instrumentName;
  const CupPage({super.key, required this.instrumentName});

  @override
  State<CupPage> createState() => _CupPageState();
}

class _CupPageState extends State<CupPage> {
  final supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _cupFuture;
  Future<List<Map<String, dynamic>>>? _rewardsFuture;
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
      _cupFuture = fetchCupData();
      _rewardsFuture = fetchRewardsData();
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

  Future<List<Map<String, dynamic>>> fetchRewardsData() async {
    try {
      if (!_isOnline) {
        debugPrint('Offline: No rewards data available');
        return [];
      }

      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(Duration(days: 6));

      final response = await supabase
          .from('rewards')
          .select(
              'position, object_id, coins_reward, objets(image_url, category, name)')
          .eq('week_start', weekStart.toIso8601String().split('T')[0])
          .eq('week_end', weekEnd.toIso8601String().split('T')[0])
          .order('position', ascending: true);

      debugPrint(
          'Supabase rewards response: ${response.length} rewards fetched: $response');

      List<Map<String, dynamic>> rewards = [];
      for (var item in response) {
        String imageUrl =
            item['objets']?['image_url'] ?? 'assets/images/refmmp.png';
        if (imageUrl.startsWith('http')) {
          try {
            final fileInfo =
                await CustomCacheManager.instance.downloadFile(imageUrl);
            imageUrl = fileInfo.file.path;
          } catch (e) {
            debugPrint(
                'Error caching image for object ${item['objets']?['name']}: $e');
            imageUrl = 'assets/images/refmmp.png';
          }
        }
        rewards.add({
          'position': item['position'],
          'object_id': item['object_id'],
          'coins_reward': item['coins_reward'] ?? 0,
          'image_url': imageUrl,
          'object_category': item['objets']?['category'],
          'object_name': item['objets']?['name'] ?? 'Objeto desconocido',
        });
      }

      final topRewards = rewards.where((r) => r['position'] <= 3).toList();
      if (topRewards.length < 3) {
        for (int i = 1; i <= 3; i++) {
          if (!topRewards.any((r) => r['position'] == i)) {
            rewards.add({
              'position': i,
              'object_id': null,
              'coins_reward': 0,
              'image_url': 'assets/images/refmmp.png',
              'object_category': null,
              'object_name': null,
            });
          }
        }
      }

      if (!rewards.any((r) => r['position'] > 3)) {
        rewards.add({
          'position': 4,
          'object_id': null,
          'coins_reward': 100,
          'image_url': 'assets/images/refmmp.png',
          'object_category': null,
          'object_name': null,
        });
      }

      rewards.sort((a, b) => a['position'].compareTo(b['position']));
      debugPrint('Processed rewards: $rewards');
      return rewards;
    } catch (e, stackTrace) {
      debugPrint(
          'Error al obtener datos de premios: $e\nStack trace: $stackTrace');
      return [
        {
          'position': 1,
          'object_id': null,
          'coins_reward': 0,
          'image_url': 'assets/images/refmmp.png',
          'object_category': null,
          'object_name': null
        },
        {
          'position': 2,
          'object_id': null,
          'coins_reward': 0,
          'image_url': 'assets/images/refmmp.png',
          'object_category': null,
          'object_name': null
        },
        {
          'position': 3,
          'object_id': null,
          'coins_reward': 0,
          'image_url': 'assets/images/refmmp.png',
          'object_category': null,
          'object_name': null
        },
        {
          'position': 4,
          'object_id': null,
          'coins_reward': 100,
          'image_url': 'assets/images/refmmp.png',
          'object_category': null,
          'object_name': null
        },
      ];
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
    const maxWidth = 125.0;

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
          velocity: 60.0,
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
            _rewardsFuture = fetchRewardsData();
          });
          debugPrint('Refresh completed, new futures assigned');
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 350.0,
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
                  'assets/images/cupsfondo.png',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading cupsfondo.png: $error');
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
                        'Premios',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _rewardsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          debugPrint(
                              'Rewards FutureBuilder: Waiting for data...');
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue));
                        }
                        if (snapshot.hasError) {
                          debugPrint(
                              'Rewards FutureBuilder error: ${snapshot.error}');
                          return const Center(
                              child: Text('Error al cargar los premios.'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          debugPrint(
                              'Rewards FutureBuilder: No data or empty data');
                          return const Center(
                              child: Text('No hay premios disponibles.'));
                        }

                        final rewardsList = snapshot.data!;
                        debugPrint(
                            'Rewards FutureBuilder: Rendering ${rewardsList.length} rewards');

                        final topRewards = rewardsList
                            .where((reward) => reward['position'] <= 3)
                            .toList();
                        final consolationReward = rewardsList.firstWhere(
                          (reward) => reward['position'] > 3,
                          orElse: () => {
                            'position': 4,
                            'object_id': null,
                            'coins_reward': 100,
                            'image_url': 'assets/images/refmmp.png',
                            'object_category': null,
                            'object_name': null
                          },
                        );

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? Colors.black54
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...topRewards.map((reward) {
                                final position = reward['position'];
                                final imageUrl = reward['image_url'];
                                final coins = reward['coins_reward'] ?? 0;
                                final objectCategory =
                                    reward['object_category'];
                                final objectName = reward['object_name'];
                                final objectId = reward['object_id'];
                                String positionText;
                                Color trophyColor;

                                switch (position) {
                                  case 1:
                                    positionText = 'Primer Puesto';
                                    trophyColor = Colors.amber;
                                    break;
                                  case 2:
                                    positionText = 'Segundo Puesto';
                                    trophyColor = Colors.grey;
                                    break;
                                  case 3:
                                    positionText = 'Tercer Puesto';
                                    trophyColor = const Color(0xFFCD7F32);
                                    break;
                                  default:
                                    positionText = 'Puesto $position';
                                    trophyColor = Colors.grey;
                                }

                                Widget imageWidget;
                                if (objectId != null && imageUrl != null) {
                                  if (imageUrl.startsWith('assets/')) {
                                    imageWidget = Image.asset(
                                      imageUrl,
                                      fit: objectCategory == 'trompetas'
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                    );
                                  } else if (File(imageUrl).existsSync()) {
                                    imageWidget = Image.file(
                                      File(imageUrl),
                                      fit: objectCategory == 'trompetas'
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        debugPrint(
                                            'Error loading local image: $error, path: $imageUrl');
                                        return Image.asset(
                                          'assets/images/refmmp.png',
                                          fit: BoxFit.cover,
                                          width: 40,
                                          height: 40,
                                        );
                                      },
                                    );
                                  } else if (Uri.tryParse(imageUrl)
                                          ?.isAbsolute ==
                                      true) {
                                    imageWidget = CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      cacheManager: CustomCacheManager.instance,
                                      fit: objectCategory == 'trompetas'
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      placeholder: (context, url) =>
                                          const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.blue),
                                      ),
                                      errorWidget: (context, url, error) {
                                        debugPrint(
                                            'Error loading network image: $error, url: $url');
                                        return Image.asset(
                                          'assets/images/refmmp.png',
                                          fit: BoxFit.cover,
                                          width: 40,
                                          height: 40,
                                        );
                                      },
                                      memCacheWidth: 80,
                                      memCacheHeight: 80,
                                      fadeInDuration:
                                          const Duration(milliseconds: 200),
                                    );
                                  } else {
                                    imageWidget = Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                    );
                                  }
                                } else {
                                  imageWidget = Image.asset(
                                    'assets/images/refmmp.png',
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                  );
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: GestureDetector(
                                    onTap: objectId != null
                                        ? () {
                                            // TODO: Implementar diálogo con descripción del objeto
                                          }
                                        : null,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.emoji_events_rounded,
                                          color: trophyColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            positionText,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            shape: objectCategory == 'avatares'
                                                ? BoxShape.circle
                                                : BoxShape.rectangle,
                                            borderRadius:
                                                objectCategory != 'avatares'
                                                    ? BorderRadius.circular(8)
                                                    : null,
                                            border: Border.all(
                                                color: Colors.blue, width: 1.5),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                objectCategory == 'avatares'
                                                    ? BorderRadius.circular(20)
                                                    : BorderRadius.circular(8),
                                            child: objectId != null
                                                ? imageWidget
                                                : (coins > 0
                                                    ? Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Image.asset(
                                                            'assets/images/coin.png',
                                                            width: 24,
                                                            height: 24,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (context,
                                                                    error,
                                                                    stackTrace) =>
                                                                Image.asset(
                                                              'assets/images/refmmp.png',
                                                              width: 24,
                                                              height: 24,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              '$coins monedas',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: Colors
                                                                    .blue
                                                                    .shade700,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : imageWidget),
                                          ),
                                        ),
                                        if (objectName != null &&
                                            objectId != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Flexible(
                                              child: Text(
                                                objectName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Puestos 4 al 50',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Image.asset(
                                    'assets/images/coin.png',
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                      'assets/images/refmmp.png',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${consolationReward['coins_reward']} monedas',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Clasificación',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cupFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          debugPrint('Cup FutureBuilder: Waiting for data...');
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue));
                        }
                        if (snapshot.hasError) {
                          debugPrint(
                              'Cup FutureBuilder error: ${snapshot.error}');
                          return const Center(
                              child: Text('Error al cargar los datos.'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          debugPrint(
                              'Cup FutureBuilder: No data or empty data');
                          return const Center(
                              child: Text(
                                  'No hay usuarios con puntos disponibles.'));
                        }

                        final cupList = snapshot.data!;
                        debugPrint(
                            'Cup FutureBuilder: Rendering ${cupList.length} users');

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
                                  width: double.infinity,
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
                                        '${index + 1}',
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
