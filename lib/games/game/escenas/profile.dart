import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'dart:ui' as ui;

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );
}

class ProfilePageGame extends StatefulWidget {
  final String instrumentName;
  const ProfilePageGame({Key? key, required this.instrumentName})
      : super(key: key);

  @override
  _ProfilePageGameState createState() => _ProfilePageGameState();
}

class _ProfilePageGameState extends State<ProfilePageGame> {
  final supabase = Supabase.instance.client;
  String? profileImageUrl;
  String? wallpaperUrl;
  int totalCoins = 0;
  String? nickname;
  int pointsXpTotally = 0;
  int pointsXpWeekend = 0;
  bool _isOnline = false;
  int _selectedIndex = 4;
  double? expandedHeight;
  List<Map<String, dynamic>> userObjects = [];
  int totalObjects = 0;
  bool isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus();
    _initializeUserData();
    fetchUserProfileImage();
    fetchWallpaper();
    fetchUserGameData();
    fetchUserObjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageHeight();
    });
    Connectivity().onConnectivityChanged.listen((result) async {
      bool isOnline = result != ConnectivityResult.none;
      setState(() {
        _isOnline = isOnline;
      });
      if (isOnline) {
        await _syncPendingActions();
        await fetchUserGameData();
        await fetchUserProfileImage();
        await fetchWallpaper();
        await fetchUserObjects();
      }
    });
  }

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Hive box offline_data opened successfully');
    }
    if (!Hive.isBoxOpen('pending_actions')) {
      await Hive.openBox('pending_actions');
      debugPrint('Hive box pending_actions opened successfully');
    }
  }

  Future<bool> _checkConnectivityStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool isOnline = connectivityResult != ConnectivityResult.none;
    try {
      final result = await InternetAddress.lookup('google.com');
      isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      isOnline = false;
    }
    setState(() {
      _isOnline = isOnline;
    });
    return isOnline;
  }

  Future<void> _loadImageHeight() async {
    if (wallpaperUrl == null) {
      setState(() {
        expandedHeight = 200.0;
      });
      return;
    }

    try {
      late ImageProvider imageProvider;
      if (wallpaperUrl!.startsWith('assets/')) {
        imageProvider = AssetImage(wallpaperUrl!);
      } else if (!wallpaperUrl!.startsWith('http') &&
          File(wallpaperUrl!).existsSync()) {
        imageProvider = FileImage(File(wallpaperUrl!));
      } else {
        imageProvider = NetworkImage(wallpaperUrl!);
      }

      final image = await _loadImage(imageProvider);
      final screenWidth = MediaQuery.of(context).size.width;
      final aspectRatio = image.width / image.height;
      setState(() {
        expandedHeight = screenWidth / aspectRatio;
      });
    } catch (e) {
      debugPrint('Error loading image height: $e');
      setState(() {
        expandedHeight = 200.0;
      });
    }
  }

  Future<ui.Image> _loadImage(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final imageStream = provider.resolve(ImageConfiguration(
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      textDirection: Directionality.of(context),
    ));
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        completer.complete(info.image);
        imageStream.removeListener(listener!);
      },
      onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
        imageStream.removeListener(listener!);
      },
    );
    imageStream.addListener(listener);
    return await completer.future;
  }

  Future<String> _downloadAndCacheImage(String url, String cacheKey) async {
    final box = Hive.box('offline_data');
    final cachedData = box.get(cacheKey, defaultValue: null);

    if (cachedData != null &&
        cachedData['url'] == url &&
        cachedData['path'] != null &&
        File(cachedData['path']).existsSync()) {
      debugPrint('Using cached image: ${cachedData['path']}');
      return cachedData['path'];
    }

    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) {
      debugPrint('Invalid URL: $url, returning default image');
      return 'assets/images/refmmp.png';
    }

    try {
      if (cachedData != null &&
          cachedData['path'] != null &&
          File(cachedData['path']).existsSync()) {
        await File(cachedData['path']).delete();
        debugPrint('Deleted old cached image: ${cachedData['path']}');
      }

      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      await box.put(cacheKey, {'path': filePath, 'url': url});
      debugPrint('Image downloaded and cached: $filePath for URL: $url');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return 'assets/images/refmmp.png';
    }
  }

  Future<void> _initializeUserData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await ensureUserInUsersGames(userId, 'user_$userId');
      await fetchUserGameData();
    }
  }

  Future<void> ensureUserInUsersGames(String userId, String nickname) async {
    final box = Hive.box('offline_data');
    try {
      if (_isOnline) {
        final response = await supabase
            .from('users_games')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (response == null) {
          await supabase.from('users_games').insert({
            'user_id': userId,
            'nickname': nickname,
            'points_xp_totally': 0,
            'points_xp_weekend': 0,
            'coins': 0,
          });
          await box.put('user_coins_$userId', 0);
          await box.put('user_nickname_$userId', nickname);
          await box.put('user_points_xp_totally_$userId', 0);
          await box.put('user_points_xp_weekend_$userId', 0);
        }
      }
    } catch (e) {
      debugPrint('Error al asegurar registro en users_games: $e');
    }
  }

  Future<void> fetchUserGameData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final coinsCacheKey = 'user_coins_$userId';
    final nicknameCacheKey = 'user_nickname_$userId';
    final pointsTotallyCacheKey = 'user_points_xp_totally_$userId';
    final pointsWeekendCacheKey = 'user_points_xp_weekend_$userId';

    try {
      if (!_isOnline) {
        setState(() {
          totalCoins = box.get(coinsCacheKey, defaultValue: 0);
          nickname = box.get(nicknameCacheKey, defaultValue: 'Usuario');
          pointsXpTotally = box.get(pointsTotallyCacheKey, defaultValue: 0);
          pointsXpWeekend = box.get(pointsWeekendCacheKey, defaultValue: 0);
        });
        return;
      }

      final response = await supabase
          .from('users_games')
          .select('coins, nickname, points_xp_totally, points_xp_weekend')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          totalCoins = response['coins'] as int? ?? 0;
          nickname = response['nickname'] as String? ?? 'Usuario';
          pointsXpTotally = response['points_xp_totally'] as int? ?? 0;
          pointsXpWeekend = response['points_xp_weekend'] as int? ?? 0;
        });
        await box.put(coinsCacheKey, totalCoins);
        await box.put(nicknameCacheKey, nickname);
        await box.put(pointsTotallyCacheKey, pointsXpTotally);
        await box.put(pointsWeekendCacheKey, pointsXpWeekend);
      } else {
        setState(() {
          totalCoins = 0;
          nickname = 'Usuario';
          pointsXpTotally = 0;
          pointsXpWeekend = 0;
        });
        await box.put(coinsCacheKey, 0);
        await box.put(nicknameCacheKey, 'Usuario');
        await box.put(pointsTotallyCacheKey, 0);
        await box.put(pointsWeekendCacheKey, 0);
      }
    } catch (e) {
      debugPrint('Error al obtener datos del usuario: $e');
      setState(() {
        totalCoins = box.get(coinsCacheKey, defaultValue: 0);
        nickname = box.get(nicknameCacheKey, defaultValue: 'Usuario');
        pointsXpTotally = box.get(pointsTotallyCacheKey, defaultValue: 0);
        pointsXpWeekend = box.get(pointsWeekendCacheKey, defaultValue: 0);
      });
    }
  }

  Future<void> fetchUserProfileImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_profile_image_${user.id}';

    try {
      if (!_isOnline) {
        final cachedProfileImage = box.get(cacheKey, defaultValue: null);
        final profileImagePath = (cachedProfileImage != null &&
                cachedProfileImage.isNotEmpty &&
                !cachedProfileImage.startsWith('http') &&
                File(cachedProfileImage).existsSync())
            ? cachedProfileImage
            : 'assets/images/refmmp.png';
        setState(() {
          profileImageUrl = profileImagePath;
        });
        debugPrint('Loaded cached profile image: $profileImagePath');
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
      String? imageUrl;
      String? userTable;
      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', user.id)
            .maybeSingle();
        if (response != null && response['profile_image'] != null) {
          imageUrl = response['profile_image'];
          userTable = table;
          if (Uri.tryParse(imageUrl!)?.isAbsolute == true) {
            try {
              final localPath = await _downloadAndCacheImage(
                  imageUrl, 'profile_image_${user.id}');
              imageUrl = localPath;
            } catch (e) {
              debugPrint('Error caching profile image: $e');
              imageUrl = 'assets/images/refmmp.png';
            }
          }
          break;
        }
      }
      imageUrl ??= 'assets/images/refmmp.png';
      setState(() {
        profileImageUrl = imageUrl;
      });
      await box.put(cacheKey, imageUrl);
      if (userTable != null) {
        await box.put('user_table_${user.id}', userTable);
      }
      debugPrint('Fetched profile image: $imageUrl');
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
      setState(() {
        profileImageUrl =
            box.get(cacheKey, defaultValue: 'assets/images/refmmp.png');
      });
    }
  }

  Future<void> fetchWallpaper() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_wallpaper_$userId';

    try {
      if (!_isOnline) {
        final cachedWallpaper = box.get(cacheKey, defaultValue: null);
        final wallpaperPath = (cachedWallpaper != null &&
                cachedWallpaper.isNotEmpty &&
                !cachedWallpaper.startsWith('http') &&
                File(cachedWallpaper).existsSync())
            ? cachedWallpaper
            : 'assets/images/refmmp.png';
        setState(() {
          wallpaperUrl = wallpaperPath;
        });
        debugPrint('Loaded cached wallpaper: $wallpaperPath');
        await _loadImageHeight();
        return;
      }

      final response = await supabase
          .from('users_games')
          .select('wallpapers')
          .eq('user_id', userId)
          .maybeSingle();

      String? imageUrl = response != null && response['wallpapers'] != null
          ? response['wallpapers']
          : 'assets/images/refmmp.png';

      if (imageUrl != 'assets/images/refmmp.png' &&
          Uri.tryParse(imageUrl!)?.isAbsolute == true) {
        try {
          final localPath =
              await _downloadAndCacheImage(imageUrl, 'wallpaper_$userId');
          imageUrl = localPath;
        } catch (e) {
          debugPrint('Error caching wallpaper: $e');
          imageUrl = 'assets/images/refmmp.png';
        }
      }
      setState(() {
        wallpaperUrl = imageUrl;
      });
      await box.put(cacheKey, imageUrl);
      debugPrint('Fetched wallpaper: $imageUrl');
      await _loadImageHeight();
    } catch (e) {
      debugPrint('Error al obtener el fondo de pantalla: $e');
      setState(() {
        wallpaperUrl =
            box.get(cacheKey, defaultValue: 'assets/images/refmmp.png');
      });
      await _loadImageHeight();
    }
  }

  Future<void> fetchUserObjects() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objects_$userId';

    try {
      if (!_isOnline) {
        final cachedObjects = box.get(cacheKey, defaultValue: []);
        setState(() {
          userObjects = List<Map<String, dynamic>>.from(cachedObjects);
          totalObjects = userObjects.length;
        });
        return;
      }

      final response = await supabase
          .from('user_objets')
          .select('objet_id, objets(image, name)')
          .eq('user_id', userId)
          .eq('status', true);

      final List<Map<String, dynamic>> fetchedObjects = [];
      for (var item in response) {
        final objet = item['objets'] as Map<String, dynamic>?;
        if (objet != null) {
          fetchedObjects.add({
            'objet_id': item['objet_id'],
            'image': objet['image'] ?? 'assets/images/refmmp.png',
            'name': objet['name'] ?? 'Objeto',
          });
        }
      }

      setState(() {
        userObjects = fetchedObjects;
        totalObjects = fetchedObjects.length;
      });
      await box.put(cacheKey, fetchedObjects);
    } catch (e) {
      debugPrint('Error al obtener objetos del usuario: $e');
      setState(() {
        userObjects = List<Map<String, dynamic>>.from(
            box.get(cacheKey, defaultValue: []));
        totalObjects = userObjects.length;
      });
    }
  }

  Future<void> _syncPendingActions() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user ID found, skipping sync');
      return;
    }

    final pendingBox = Hive.box('pending_actions');
    final pendingActions = pendingBox.values.toList();
    if (pendingActions.isEmpty) {
      debugPrint('No pending actions to sync');
      return;
    }

    bool isSyncing = false;
    if (isSyncing) {
      debugPrint('Sync already in progress, skipping');
      return;
    }
    isSyncing = true;

    try {
      for (var action in List.from(pendingActions)) {
        final actionUserId = action['user_id'] as String?;
        if (actionUserId != userId) {
          debugPrint('Skipping action for different user: $actionUserId');
          continue;
        }

        final actionType = action['action'] as String?;
        if (actionType == null) {
          debugPrint('Invalid action type, skipping');
          continue;
        }

        try {
          if (actionType == 'use_wallpaper') {
            final imageUrl = action['image_url'] as String?;
            if (imageUrl != null) {
              if (_isOnline) {
                await supabase
                    .from('users_games')
                    .update({'wallpapers': imageUrl}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_wallpaper_$userId', imageUrl);
              if (mounted) {
                setState(() {
                  wallpaperUrl = imageUrl;
                });
                await _loadImageHeight();
              }
            }
          } else if (actionType == 'use_avatar') {
            final table = action['table'] as String? ?? await _getUserTable();
            final imageUrl = action['image_url'] as String?;
            if (table != null && imageUrl != null) {
              if (_isOnline) {
                await supabase
                    .from(table)
                    .update({'profile_image': imageUrl}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_profile_image_$userId', imageUrl);
              if (mounted) {
                setState(() {
                  profileImageUrl = imageUrl;
                });
              }
            } else {
              debugPrint(
                  'Error: Missing table or image_url for use_avatar action');
              continue;
            }
          } else if (actionType == 'update_nickname') {
            final newNickname = action['nickname'] as String?;
            if (newNickname != null) {
              if (_isOnline) {
                await supabase
                    .from('users_games')
                    .update({'nickname': newNickname}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_nickname_$userId', newNickname);
              if (mounted) {
                setState(() {
                  nickname = newNickname;
                });
              }
            }
          }
          final index = pendingBox.values.toList().indexOf(action);
          if (index != -1) {
            await pendingBox.deleteAt(index);
            debugPrint(
                'Synced action: $actionType for object ${action['objet_id'] ?? 'nickname'}');
          }
        } catch (e) {
          debugPrint('Error syncing action $actionType: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error processing pending actions: $e');
    } finally {
      isSyncing = false;
    }
  }

  Future<String?> _getUserTable() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final box = Hive.box('offline_data');
    final cachedTable = box.get('user_table_$userId', defaultValue: null);
    if (!_isOnline && cachedTable != null) {
      return cachedTable;
    }

    final tables = [
      'users',
      'students',
      'graduates',
      'teachers',
      'advisors',
      'parents',
      'directors'
    ];

    for (final table in tables) {
      final response = await supabase
          .from(table)
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null) {
        await box.put('user_table_$userId', table);
        return table;
      }
    }
    return null;
  }

  Future<bool> _isNicknameUnique(String newNickname) async {
    if (!_isOnline) {
      return true; // Asumir que es único en modo offline
    }
    try {
      final response = await supabase
          .from('users_games')
          .select('nickname')
          .eq('nickname', newNickname)
          .maybeSingle();
      return response == null;
    } catch (e) {
      debugPrint('Error verificando unicidad del nickname: $e');
      return false;
    }
  }

  Future<void> _showEditNicknameDialog() async {
    final TextEditingController controller =
        TextEditingController(text: nickname);
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Cambiar Nickname'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ingresa tu nuevo nickname:'),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Nuevo nickname',
                      errorText: errorMessage,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    final newNickname = controller.text.trim();
                    if (newNickname.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'El nickname no puede estar vacío';
                      });
                      return;
                    }
                    if (await _isNicknameUnique(newNickname)) {
                      final userId = supabase.auth.currentUser?.id;
                      if (userId != null) {
                        try {
                          if (_isOnline) {
                            await supabase.from('users_games').update({
                              'nickname': newNickname,
                            }).eq('user_id', userId);
                          } else {
                            final pendingBox = Hive.box('pending_actions');
                            await pendingBox.add({
                              'user_id': userId,
                              'action': 'update_nickname',
                              'nickname': newNickname,
                            });
                          }
                          final box = Hive.box('offline_data');
                          await box.put('user_nickname_$userId', newNickname);
                          setState(() {
                            nickname = newNickname;
                          });
                          Navigator.pop(context);
                        } catch (e) {
                          setDialogState(() {
                            errorMessage = 'Error al actualizar el nickname';
                          });
                        }
                      }
                    } else {
                      setDialogState(() {
                        errorMessage = 'El nickname ya está en uso';
                      });
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
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

  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          await _checkConnectivityStatus();
          await fetchUserGameData();
          await fetchUserProfileImage();
          await fetchWallpaper();
          await fetchUserObjects();
          if (_isOnline) {
            await _syncPendingActions();
          }
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollUpdateNotification) {
              setState(() {
                isCollapsed = scrollNotification.metrics.pixels >=
                    (expandedHeight ?? 200.0) - kToolbarHeight;
              });
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: expandedHeight ?? 200.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.blue,
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
                  onPressed: () => Navigator.pop(context),
                ),
                title: isCollapsed
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (profileImageUrl != null)
                            CircleAvatar(
                              radius: 20.0,
                              backgroundImage: profileImageUrl!
                                      .startsWith('assets/')
                                  ? AssetImage(profileImageUrl!)
                                      as ImageProvider
                                  : (!profileImageUrl!.startsWith('http') &&
                                          File(profileImageUrl!).existsSync()
                                      ? FileImage(File(profileImageUrl!))
                                      : NetworkImage(profileImageUrl!)),
                              backgroundColor: Colors.transparent,
                              onBackgroundImageError: (_, __) =>
                                  AssetImage('assets/images/refmmp.png'),
                            ),
                          Expanded(
                            child: Center(
                              child: Text(
                                nickname?.toUpperCase() ?? 'USUARIO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      wallpaperUrl != null &&
                              wallpaperUrl!.isNotEmpty &&
                              !wallpaperUrl!.startsWith('http') &&
                              File(wallpaperUrl!).existsSync()
                          ? Image.file(
                              File(wallpaperUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint(
                                    'Error loading local wallpaper: $error, path: $wallpaperUrl');
                                return Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : wallpaperUrl != null &&
                                  wallpaperUrl!.isNotEmpty &&
                                  Uri.tryParse(wallpaperUrl!)?.isAbsolute ==
                                      true
                              ? CachedNetworkImage(
                                  imageUrl: wallpaperUrl!,
                                  cacheManager: CustomCacheManager.instance,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) {
                                    debugPrint(
                                        'Error loading network wallpaper: $error, url: $url');
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover,
                                ),
                      if (!isCollapsed && profileImageUrl != null)
                        Positioned(
                          bottom: 0,
                          left: (MediaQuery.of(context).size.width - 120) / 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 70.0,
                                backgroundImage: profileImageUrl!
                                        .startsWith('assets/')
                                    ? AssetImage(profileImageUrl!)
                                        as ImageProvider
                                    : (!profileImageUrl!.startsWith('http') &&
                                            File(profileImageUrl!).existsSync()
                                        ? FileImage(File(profileImageUrl!))
                                        : NetworkImage(profileImageUrl!)),
                                backgroundColor: Colors.transparent,
                                onBackgroundImageError: (_, __) =>
                                    AssetImage('assets/images/refmmp.png'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            nickname ?? 'Usuario',
                            style: TextStyle(
                              fontSize: 24, // Texto grande
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.blue),
                            onPressed: _showEditNicknameDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/coin.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Mis Monedas: ${numberFormat.format(totalCoins)}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'XP Semanal: ${numberFormat.format(pointsXpWeekend)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'XP Total: ${numberFormat.format(pointsXpTotally)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 400),
                      const Text(
                        '| Objetos Obtenidos',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      userObjects.isEmpty
                          ? const Center(
                              child: Text(
                                'No tienes objetos obtenidos.',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          : Column(
                              children: [
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.8,
                                  ),
                                  itemCount: userObjects.length > 6
                                      ? 6
                                      : userObjects.length,
                                  itemBuilder: (context, index) {
                                    final objet = userObjects[index];
                                    return Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                      top: Radius.circular(12)),
                                              child: objet['image']
                                                      .startsWith('assets/')
                                                  ? Image.asset(
                                                      objet['image'],
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Image.asset(
                                                          'assets/images/refmmp.png',
                                                          fit: BoxFit.cover,
                                                        );
                                                      },
                                                    )
                                                  : (!objet['image'].startsWith(
                                                              'http') &&
                                                          File(objet['image'])
                                                              .existsSync()
                                                      ? Image.file(
                                                          File(objet['image']),
                                                          fit: BoxFit.cover,
                                                          width:
                                                              double.infinity,
                                                          errorBuilder:
                                                              (context, error,
                                                                  stackTrace) {
                                                            return Image.asset(
                                                              'assets/images/refmmp.png',
                                                              fit: BoxFit.cover,
                                                            );
                                                          },
                                                        )
                                                      : CachedNetworkImage(
                                                          imageUrl:
                                                              objet['image'],
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
                                                              url, error) {
                                                            return Image.asset(
                                                              'assets/images/refmmp.png',
                                                              fit: BoxFit.cover,
                                                            );
                                                          },
                                                        )),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              objet['name'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ObjetsPage(
                                            instrumentName:
                                                widget.instrumentName),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                  ),
                                  child: Text(
                                    'Ver todos los objetos ($totalObjects)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
