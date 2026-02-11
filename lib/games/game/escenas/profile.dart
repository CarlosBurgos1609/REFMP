import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:refmp/details/myobjets.dart';
import 'package:refmp/dialogs/dialog_achievements.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/play.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/dialogs/dialog_objets.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';

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
  final Map<String, bool> _gifVisibility = {};
  List<Map<String, dynamic>> userAchievements = [];
  int totalAchievements = 0;
  int totalAvailableObjects = 0;
  List<Map<String, dynamic>> userFavoriteSongs = [];
  int totalFavoriteSongs = 0;
  Map<int, double> weeklyXpData =
      {}; // Datos de XP por día de la semana (0=Dom, 6=Sáb)
  List<Map<String, dynamic>> topUserWeeklyXp = []; // Top usuario con más XP

  bool _isDisposed = false; // Agregar esta variable para control adicional

  @override
  void dispose() {
    _isDisposed = true; // Marcar como disposed
    super.dispose();
  }

  // Función helper para verificar si es seguro actualizar el estado
  bool _canUpdateState() {
    return mounted && !_isDisposed;
  }

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus().then((isOnline) {
      if (!_canUpdateState()) return; // Verificar antes de continuar

      _initializeUserData();
      fetchUserProfileImage();
      fetchWallpaper();

      // Primero obtener los puntos, luego cargar la gráfica
      fetchTotalCoins().then((_) {
        if (!_canUpdateState()) return;

        // Después de obtener los puntos, cargar el resto de datos incluyendo la gráfica
        Future.wait([
          fetchUserAchievements(),
          fetchUserObjects(),
          fetchTotalAvailableObjects(),
          fetchUserFavoriteSongs(),
          fetchWeeklyXpData(), // Ahora se ejecuta después de tener los puntos
        ]).then((_) {
          if (_canUpdateState()) {
            setState(
                () {}); // Asegurar la actualización de la UI solo si es seguro
          }
        }).catchError((error) {
          debugPrint('Error in initialization: $error');
        });
      }).catchError((error) {
        debugPrint('Error fetching coins: $error');
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canUpdateState()) {
          _loadImageHeight();
        }
      });
    }).catchError((error) {
      debugPrint('Error checking connectivity: $error');
    });

    Connectivity().onConnectivityChanged.listen((result) async {
      if (!_canUpdateState()) return;

      bool isOnline = result != ConnectivityResult.none;
      try {
        final result = await InternetAddress.lookup('google.com');
        isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        debugPrint('Error en verificación de internet: $e');
        isOnline = false;
      }

      if (_canUpdateState()) {
        setState(() {
          _isOnline = isOnline;
        });
      }

      if (isOnline && _canUpdateState()) {
        await _syncPendingActions();
        await fetchUserObjects();
        await fetchUserAchievements();
        await fetchTotalAvailableObjects();
        await fetchUserFavoriteSongs();
        if (_canUpdateState()) {
          setState(() {}); // Actualizar UI después de sincronizar
        }
      }
    });
  }

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
    }
    if (!Hive.isBoxOpen('pending_actions')) {
      await Hive.openBox('pending_actions');
    }
    if (!Hive.isBoxOpen('pending_favorite_actions')) {
      await Hive.openBox('pending_favorite_actions');
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

    if (_canUpdateState()) {
      setState(() {
        _isOnline = isOnline;
      });
    }
    return isOnline;
  }

  Future<void> _initializeUserData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await ensureUserInUsersGames(userId, 'user_$userId');
      await fetchTotalCoins();
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
        }
      }
    } catch (e) {
      debugPrint('Error al asegurar registro en users_games: $e');
    }
  }

  Future<void> fetchTotalCoins() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_coins_$userId';

    try {
      if (!_isOnline) {
        if (_canUpdateState()) {
          setState(() {
            totalCoins = box.get(cacheKey, defaultValue: totalCoins);
            nickname = box.get('user_nickname_$userId', defaultValue: nickname);
            pointsXpTotally = box.get('points_xp_totally_$userId',
                defaultValue: pointsXpTotally);
            pointsXpWeekend = box.get('points_xp_weekend_$userId',
                defaultValue: pointsXpWeekend);
          });
        }
        return;
      }

      final response = await supabase
          .from('users_games')
          .select('coins, nickname, points_xp_totally, points_xp_weekend')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && _canUpdateState()) {
        setState(() {
          totalCoins = response['coins'] as int? ?? totalCoins;
          nickname = response['nickname'] as String? ?? nickname;
          pointsXpTotally =
              response['points_xp_totally'] as int? ?? pointsXpTotally;
          pointsXpWeekend =
              response['points_xp_weekend'] as int? ?? pointsXpWeekend;
        });
        await box.put(cacheKey, totalCoins);
        await box.put('user_nickname_$userId', nickname);
        await box.put('points_xp_totally_$userId', pointsXpTotally);
        await box.put('points_xp_weekend_$userId', pointsXpWeekend);
      }
    } catch (e) {
      debugPrint('Error al obtener datos del usuario: $e');
      if (_canUpdateState()) {
        setState(() {
          totalCoins = box.get(cacheKey, defaultValue: totalCoins);
          nickname = box.get('user_nickname_$userId', defaultValue: nickname);
          pointsXpTotally = box.get('points_xp_totally_$userId',
              defaultValue: pointsXpTotally);
          pointsXpWeekend = box.get('points_xp_weekend_$userId',
              defaultValue: pointsXpWeekend);
        });
      }
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

  Future<String> _downloadAndCacheImage(String url, String cacheKey) async {
    final box = Hive.box('offline_data');
    final cachedData = box.get(cacheKey, defaultValue: null);

    if (cachedData != null &&
        cachedData['url'] == url &&
        cachedData['path'] != null &&
        File(cachedData['path']).existsSync()) {
      return cachedData['path'];
    }

    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) {
      return 'assets/images/refmmp.png';
    }

    try {
      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      await box.put(cacheKey, {'path': filePath, 'url': url});
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return 'assets/images/refmmp.png';
    }
  }

  Future<void> fetchUserProfileImage() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_profile_image_$userId';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    try {
      if (!_isOnline) {
        final cachedProfileImage = box.get(cacheKey,
            defaultValue: profileImageProvider.profileImageUrl);
        final profileImagePath = (cachedProfileImage != null &&
                cachedProfileImage.isNotEmpty &&
                !cachedProfileImage.startsWith('http') &&
                File(cachedProfileImage).existsSync())
            ? cachedProfileImage
            : profileImageProvider.profileImageUrl ??
                'assets/images/refmmp.png';

        if (_canUpdateState()) {
          setState(() {
            profileImageUrl = profileImagePath;
          });
        }
        profileImageProvider.updateProfileImage(profileImagePath,
            notify: true, isOnline: false);
        return;
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
      String? imageUrl;
      String? userTable;
      for (String table in tables) {
        if (!_canUpdateState()) return; // Verificar en cada iteración

        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', userId)
            .maybeSingle();
        if (response != null && response['profile_image'] != null) {
          imageUrl = response['profile_image'];
          userTable = table;
          if (Uri.tryParse(imageUrl!)?.isAbsolute == true) {
            try {
              final localPath = await _downloadAndCacheImage(
                  imageUrl, 'profile_image_$userId');
              imageUrl = localPath;
            } catch (e) {
              debugPrint('Error caching profile image: $e');
              imageUrl = profileImageProvider.profileImageUrl ??
                  'assets/images/refmmp.png';
            }
          }
          break;
        }
      }

      if (!_canUpdateState()) return;

      imageUrl ??=
          profileImageProvider.profileImageUrl ?? 'assets/images/refmmp.png';

      setState(() {
        profileImageUrl = imageUrl;
      });
      profileImageProvider.updateProfileImage(imageUrl,
          notify: true, isOnline: true, userTable: userTable);
      await box.put(cacheKey, imageUrl);
      if (userTable != null) {
        await box.put('user_table_$userId', userTable);
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
      if (_canUpdateState()) {
        final cachedProfileImage = box.get(cacheKey,
            defaultValue: profileImageProvider.profileImageUrl ??
                'assets/images/refmmp.png');
        setState(() {
          profileImageUrl = cachedProfileImage;
        });
        profileImageProvider.updateProfileImage(cachedProfileImage,
            notify: true, isOnline: false);
      }
    }
  }

  Future<void> fetchWallpaper() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_wallpaper_$userId';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    try {
      if (!_isOnline) {
        final cachedWallpaper =
            box.get(cacheKey, defaultValue: profileImageProvider.wallpaperUrl);
        final wallpaperPath = (cachedWallpaper != null &&
                cachedWallpaper.isNotEmpty &&
                !cachedWallpaper.startsWith('http') &&
                File(cachedWallpaper).existsSync())
            ? cachedWallpaper
            : profileImageProvider.wallpaperUrl ?? 'assets/images/refmmp.png';

        if (_canUpdateState()) {
          setState(() {
            wallpaperUrl = wallpaperPath;
          });
        }
        profileImageProvider.updateWallpaper(wallpaperPath,
            notify: true, isOnline: false);
        await _loadImageHeight();
        return;
      }

      final response = await supabase
          .from('users_games')
          .select('wallpapers')
          .eq('user_id', userId)
          .maybeSingle();

      if (!_canUpdateState()) return;

      String? imageUrl = response != null && response['wallpapers'] != null
          ? response['wallpapers']
          : profileImageProvider.wallpaperUrl ?? 'assets/images/refmmp.png';

      if (imageUrl != 'assets/images/refmmp.png' &&
          Uri.tryParse(imageUrl!)?.isAbsolute == true) {
        try {
          final localPath =
              await _downloadAndCacheImage(imageUrl, 'wallpaper_$userId');
          imageUrl = localPath;
        } catch (e) {
          debugPrint('Error caching wallpaper: $e');
          imageUrl =
              profileImageProvider.wallpaperUrl ?? 'assets/images/refmmp.png';
        }
      }

      if (_canUpdateState()) {
        setState(() {
          wallpaperUrl = imageUrl;
        });
      }
      profileImageProvider.updateWallpaper(imageUrl!,
          notify: true, isOnline: true);
      await box.put(cacheKey, imageUrl);
      await _loadImageHeight();
    } catch (e) {
      debugPrint('Error al obtener el fondo de pantalla: $e');
      if (_canUpdateState()) {
        final cachedWallpaper = box.get(cacheKey,
            defaultValue: profileImageProvider.wallpaperUrl ??
                'assets/images/refmmp.png');
        setState(() {
          wallpaperUrl = cachedWallpaper;
        });
        profileImageProvider.updateWallpaper(cachedWallpaper,
            notify: true, isOnline: false);
        await _loadImageHeight();
      }
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

  Future<void> _loadImageHeight() async {
    if (!_canUpdateState()) return;

    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final wallpaperUrl = profileImageProvider.wallpaperUrl;

    if (wallpaperUrl == null || wallpaperUrl.isEmpty) {
      if (_canUpdateState()) {
        setState(() {
          expandedHeight = 200.0;
        });
      }
      return;
    }

    try {
      late ImageProvider imageProvider;
      if (wallpaperUrl.startsWith('assets/')) {
        imageProvider = AssetImage(wallpaperUrl);
      } else if (!wallpaperUrl.startsWith('http') &&
          File(wallpaperUrl).existsSync()) {
        imageProvider = FileImage(File(wallpaperUrl));
      } else {
        imageProvider = NetworkImage(wallpaperUrl);
      }

      final image = await _loadImage(imageProvider);
      if (_canUpdateState()) {
        final screenWidth = MediaQuery.of(context).size.width;
        final aspectRatio = image.width / image.height;
        setState(() {
          expandedHeight = screenWidth / aspectRatio;
        });
      }
    } catch (e) {
      debugPrint('Error loading image height: $e');
      if (_canUpdateState()) {
        setState(() {
          expandedHeight = 200.0;
        });
      }
    }
  }

  Future<void> fetchTotalAvailableObjects() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'total_available_objects_$userId';

    try {
      if (!_isOnline) {
        if (_canUpdateState()) {
          setState(() {
            totalAvailableObjects = box.get(cacheKey, defaultValue: 0);
          });
        }
        return;
      }

      final response =
          await supabase.from('objets').select('id').count(CountOption.exact);

      final count = response.count;
      if (_canUpdateState()) {
        setState(() {
          totalAvailableObjects = count;
        });
      }
      await box.put(cacheKey, count);
    } catch (e) {
      debugPrint('Error fetching total available objects: $e');
      if (_canUpdateState()) {
        setState(() {
          totalAvailableObjects = box.get(cacheKey, defaultValue: 0);
        });
      }
    }
  }

  Future<void> fetchUserAchievements() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) {
      debugPrint('Error: userId is null or widget disposed');
      return;
    }

    debugPrint('Fetching achievements for userId: $userId');

    final box = Hive.box('offline_data');
    final cacheKey = 'user_achievements_$userId';
    final countCacheKey = 'total_achievements_$userId';

    try {
      if (!_isOnline) {
        final cachedAchievements = box.get(cacheKey, defaultValue: []);
        if (_canUpdateState()) {
          setState(() {
            userAchievements = List<Map<String, dynamic>>.from(
              cachedAchievements
                  .map((item) => Map<String, dynamic>.from(item as Map)),
            ).take(3).toList();
            totalAchievements =
                box.get(countCacheKey, defaultValue: cachedAchievements.length);
          });
        }
        debugPrint(
            'Offline: Loaded ${userAchievements.length} achievements from cache');
        for (var item in userAchievements) {
          if (!_canUpdateState()) return;
          final imageUrl = item['image'] ?? 'assets/images/refmmp.png';
          final objectCacheKey = 'achievement_image_${item['id']}';
          final localImagePath =
              await _downloadAndCacheImage(imageUrl, objectCacheKey);
          item['local_image_path'] = localImagePath;
          _gifVisibility['achievement_${item['id']}'] = true;
        }
        if (_canUpdateState()) {
          setState(() {});
        }
        return;
      }

      final response = await supabase
          .from('users_achievements')
          .select(
              'id, created_at, achievements!inner(name, image, description)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      if (!_canUpdateState()) return;

      final List<Map<String, dynamic>> fetchedAchievements = [];
      for (var item in response) {
        if (!_canUpdateState()) return;
        final achievement = item['achievements'] as Map<String, dynamic>;
        final imageUrl = achievement['image'] ?? 'assets/images/refmmp.png';
        final objectCacheKey = 'achievement_image_${item['id']}';
        final localImagePath =
            await _downloadAndCacheImage(imageUrl, objectCacheKey);
        fetchedAchievements.add({
          'id': item['id'],
          'image': imageUrl,
          'local_image_path': localImagePath,
          'name': achievement['name'] ?? 'Logro',
          'description': achievement['description'] ?? 'Sin descripción',
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        });
        _gifVisibility['achievement_${item['id']}'] = true;
      }

      if (!_canUpdateState()) return;

      final countResponse = await supabase
          .from('users_achievements')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      if (_canUpdateState()) {
        setState(() {
          userAchievements = fetchedAchievements;
          totalAchievements = countResponse.count;
        });
      }
      await box.put(cacheKey, fetchedAchievements);
      await box.put(countCacheKey, countResponse.count);
      debugPrint('Online: Fetched ${fetchedAchievements.length} achievements');
    } catch (e, stackTrace) {
      debugPrint(
          'Error fetching user achievements: $e\nStack trace: $stackTrace');
      if (_canUpdateState()) {
        setState(() {
          final cachedAchievements = box.get(cacheKey, defaultValue: []);
          userAchievements = List<Map<String, dynamic>>.from(
            cachedAchievements
                .map((item) => Map<String, dynamic>.from(item as Map)),
          ).take(3).toList();
          totalAchievements =
              box.get(countCacheKey, defaultValue: cachedAchievements.length);
        });
      }
    }
  }

  Future<void> fetchUserObjects() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) {
      debugPrint('Error: userId is null or widget disposed');
      return;
    }

    debugPrint('Fetching objects for userId: $userId');

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objects_$userId';
    final countCacheKey = 'total_objects_$userId';

    try {
      if (!_isOnline) {
        final cachedObjects = box.get(cacheKey, defaultValue: []);
        if (_canUpdateState()) {
          setState(() {
            userObjects = List<Map<String, dynamic>>.from(
              cachedObjects
                  .map((item) => Map<String, dynamic>.from(item as Map)),
            ).take(3).toList();
            totalObjects =
                box.get(countCacheKey, defaultValue: cachedObjects.length);
          });
        }
        debugPrint('Offline: Loaded ${userObjects.length} objects from cache');
        for (var item in userObjects) {
          if (!_canUpdateState()) return;
          final imageUrl = item['image_url'] ?? 'assets/images/refmmp.png';
          final objectCacheKey = 'object_image_${item['id']}';
          final localImagePath =
              await _downloadAndCacheImage(imageUrl, objectCacheKey);
          item['local_image_path'] = localImagePath;
          _gifVisibility['${item['id']}'] = true;
        }
        if (_canUpdateState()) {
          setState(() {});
        }
        return;
      }

      final response = await supabase
          .from('users_objets')
          .select(
              'objet_id, created_at, objets!inner(id, image_url, name, category, description, price)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3);

      if (!_canUpdateState()) return;

      final List<Map<String, dynamic>> fetchedObjects = [];
      for (var item in response) {
        if (!_canUpdateState()) return;
        final objet = item['objets'] as Map<String, dynamic>;
        fetchedObjects.add({
          'id': objet['id'],
          'image_url': objet['image_url'] ?? 'assets/images/refmmp.png',
          'local_image_path': null,
          'name': objet['name'] ?? 'Objeto',
          'category': objet['category'] ?? 'otros',
          'description': objet['description'] ?? 'Sin descripción',
          'price': objet['price'] ?? 0,
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      if (!_canUpdateState()) return;

      final countResponse = await supabase
          .from('users_objets')
          .select('objet_id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      if (_canUpdateState()) {
        setState(() {
          userObjects = fetchedObjects;
          totalObjects = countResponse.count;
        });
      }
      await box.put(cacheKey, fetchedObjects);
      await box.put(countCacheKey, countResponse.count);
      debugPrint('Online: Fetched ${fetchedObjects.length} objects metadata');

      for (var item in fetchedObjects) {
        if (!_canUpdateState()) return;
        final imageUrl = item['image_url'];
        final objectCacheKey = 'object_image_${item['id']}';
        final localImagePath =
            await _downloadAndCacheImage(imageUrl, objectCacheKey);
        item['local_image_path'] = localImagePath;
        _gifVisibility['${item['id']}'] = true;
      }
      if (_canUpdateState()) {
        setState(() {});
      }
      debugPrint('Online: Loaded images for ${fetchedObjects.length} objects');
    } catch (e, stackTrace) {
      debugPrint('Error fetching user objects: $e\nStack trace: $stackTrace');
      if (_canUpdateState()) {
        setState(() {
          final cachedObjects = box.get(cacheKey, defaultValue: []);
          userObjects = List<Map<String, dynamic>>.from(
            cachedObjects.map((item) => Map<String, dynamic>.from(item as Map)),
          ).take(3).toList();
          totalObjects =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
        });
      }
    }
  }

  Future<void> fetchUserFavoriteSongs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) {
      debugPrint('Error: userId is null or widget disposed');
      return;
    }

    debugPrint('Fetching favorite songs for userId: $userId');

    final box = Hive.box('offline_data');
    final cacheKey = 'user_favorite_songs_$userId';
    final countCacheKey = 'total_favorite_songs_$userId';

    try {
      if (!_isOnline) {
        final cachedSongs = box.get(cacheKey, defaultValue: []);
        final cachedCount = box.get(countCacheKey, defaultValue: 0);
        debugPrint(
            'Offline: Attempting to load $cachedCount favorite songs from cache');
        if (cachedSongs.isNotEmpty && _canUpdateState()) {
          setState(() {
            userFavoriteSongs = List<Map<String, dynamic>>.from(
              cachedSongs.map((item) => Map<String, dynamic>.from(item as Map)),
            ).take(3).toList();
            totalFavoriteSongs = cachedCount;
          });
          debugPrint(
              'Offline: Loaded ${userFavoriteSongs.length} favorite songs from cache');
          for (var item in userFavoriteSongs) {
            if (!_canUpdateState()) return;
            final imageUrl = item['image'] ?? 'assets/images/refmmp.png';
            final songCacheKey = 'song_image_${item['id']}';
            final localImagePath =
                await _downloadAndCacheImage(imageUrl, songCacheKey);
            item['local_image_path'] = localImagePath;
            _gifVisibility['song_${item['id']}'] = true;
          }
          if (_canUpdateState()) {
            setState(() {});
          }
        } else {
          debugPrint('Offline: No cached favorite songs found');
        }
        return;
      }

      debugPrint('Online: Querying favorite songs from Supabase');
      final response = await supabase
          .from('songs_favorite')
          .select('song_id, created_at, songs!inner(id, name, image)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!_canUpdateState()) return;

      debugPrint('Online: Received response with ${response.length} songs');

      final List<Map<String, dynamic>> fetchedSongs = [];
      for (var item in response) {
        if (!_canUpdateState()) return;
        final song = item['songs'] as Map<String, dynamic>;
        final imageUrl = song['image'] ?? 'assets/images/refmmp.png';
        final songCacheKey = 'song_image_${item['song_id']}';
        final localImagePath =
            await _downloadAndCacheImage(imageUrl, songCacheKey);
        fetchedSongs.add({
          'id': item['song_id'],
          'name': song['name'] ?? 'Canción',
          'image': imageUrl,
          'local_image_path': localImagePath,
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        });
        _gifVisibility['song_${item['song_id']}'] = true;
      }

      if (!_canUpdateState()) return;

      final countResponse = await supabase
          .from('songs_favorite')
          .select('song_id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      debugPrint('Online: Total favorite songs count: ${countResponse.count}');

      if (_canUpdateState()) {
        setState(() {
          userFavoriteSongs = fetchedSongs.take(3).toList();
          totalFavoriteSongs = countResponse.count;
        });
      }
      await box.put(cacheKey, fetchedSongs);
      await box.put(countCacheKey, countResponse.count);
      debugPrint(
          'Online: Fetched and cached ${fetchedSongs.length} favorite songs');
    } catch (e, stackTrace) {
      debugPrint('Error fetching favorite songs: $e\nStack trace: $stackTrace');
      if (_canUpdateState()) {
        final cachedSongs = box.get(cacheKey, defaultValue: []);
        final cachedCount = box.get(countCacheKey, defaultValue: 0);
        setState(() {
          userFavoriteSongs = List<Map<String, dynamic>>.from(
            cachedSongs.map((item) => Map<String, dynamic>.from(item as Map)),
          ).take(3).toList();
          totalFavoriteSongs = cachedCount;
        });
        debugPrint(
            'Fallback: Loaded ${userFavoriteSongs.length} favorite songs from cache');
      }
    }
  }

  Future<void> fetchWeeklyXpData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !_canUpdateState()) {
      debugPrint('Error: userId is null or widget disposed');
      return;
    }

    debugPrint('Fetching weekly XP data for userId: $userId');

    final box = Hive.box('offline_data');
    final cacheKey = 'weekly_xp_data_$userId';

    try {
      if (!_isOnline) {
        final cachedXpData = box.get(cacheKey, defaultValue: {});
        if (_canUpdateState()) {
          setState(() {
            weeklyXpData = Map<int, double>.from(
              (cachedXpData as Map).map(
                (key, value) => MapEntry(
                    int.parse(key.toString()), (value as num).toDouble()),
              ),
            );
          });
        }
        debugPrint('Offline: Loaded weekly XP data from cache');
        return;
      }

      // Obtener los últimos 7 días (hoy es el día 6)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Calcular el inicio de los últimos 7 días (hace 6 días)
      final startDate = today.subtract(const Duration(days: 6));

      // Nombres de los días para debug
      final dayNames = [
        'Domingo',
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado'
      ];

      debugPrint('📅 Fetching last 7 days XP:');
      debugPrint('   Start: $startDate');
      debugPrint('   Today: $today');

      // Consultar el historial de XP de los últimos 7 días
      final response = await supabase
          .from('xp_history')
          .select('points_earned, created_at, source, source_name')
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at',
              today.add(const Duration(days: 1)).toIso8601String())
          .order('created_at', ascending: true);

      debugPrint('Query result: ${response.length} XP records found');

      // Agrupar puntos por índice de día (0 = hace 6 días, 6 = hoy)
      Map<int, double> xpByDay = {
        0: 0.0, // Hace 6 días
        1: 0.0, // Hace 5 días
        2: 0.0, // Hace 4 días
        3: 0.0, // Hace 3 días
        4: 0.0, // Hace 2 días
        5: 0.0, // Ayer
        6: 0.0, // Hoy
      };

      if (response.isEmpty) {
        // Si no hay historial, mostrar los puntos del día actual
        debugPrint('⚠️ No xp_history found, using pointsXpWeekend for today');
        if (pointsXpWeekend > 0) {
          xpByDay[6] = pointsXpWeekend.toDouble(); // Índice 6 = hoy
          debugPrint('Showing $pointsXpWeekend XP on today');
        }
      } else {
        // Procesar historial de XP
        for (var record in response) {
          final createdAt = DateTime.parse(record['created_at']);
          final recordDate =
              DateTime(createdAt.year, createdAt.month, createdAt.day);

          // Calcular cuántos días atrás fue este registro
          final daysDifference = today.difference(recordDate).inDays;

          // Mapear a índice (0 = hace 6 días, 6 = hoy)
          final dayIndex = 6 - daysDifference;

          if (dayIndex >= 0 && dayIndex <= 6) {
            final points = (record['points_earned'] as num?)?.toDouble() ?? 0.0;
            xpByDay[dayIndex] = (xpByDay[dayIndex] ?? 0.0) + points;

            final dayName = dayNames[recordDate.weekday % 7];
            debugPrint(
                'XP on $dayName (${recordDate.day}/${recordDate.month}): +$points XP -> Total: ${xpByDay[dayIndex]}');
          }
        }
      }

      if (_canUpdateState()) {
        setState(() {
          weeklyXpData = xpByDay;
        });
      }

      // Guardar en caché
      await box.put(cacheKey,
          xpByDay.map((key, value) => MapEntry(key.toString(), value)));

      debugPrint('Online: Fetched last 7 days XP data:');
      for (int i = 0; i < 7; i++) {
        final date = today.subtract(Duration(days: 6 - i));
        final dayName = dayNames[date.weekday % 7];
        final label = i == 6 ? 'Hoy' : dayName;
        debugPrint(
            '  Day $i ($label - ${date.day}/${date.month}): ${xpByDay[i]} XP');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching weekly XP data: $e\nStack trace: $stackTrace');
      if (_canUpdateState()) {
        final cachedXpData = box.get(cacheKey, defaultValue: {});
        setState(() {
          weeklyXpData = Map<int, double>.from(
            (cachedXpData as Map).map(
              (key, value) => MapEntry(
                  int.parse(key.toString()), (value as num).toDouble()),
            ),
          );
        });
      }
    }
  }

  Future<void> _purchaseObject(Map<String, dynamic> item) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final pendingBox = Hive.box('pending_actions');
    final price = (item['price'] ?? 0) as int;
    final newCoins = totalCoins - price;

    if (newCoins < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No tienes suficientes monedas')),
      );
      return;
    }

    try {
      if (!_isOnline) {
        await pendingBox.add({
          'user_id': userId,
          'action': 'purchase',
          'objet_id': item['id'],
          'price': price,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await box.put('user_coins_$userId', newCoins);
        final cachedObjects = box.get('user_objects_$userId', defaultValue: []);
        cachedObjects.add(item);
        await box.put('user_objects_$userId', cachedObjects);
        if (_canUpdateState()) {
          setState(() {
            totalCoins = newCoins;
            userObjects.add(item);
            totalObjects++;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Compra guardada para sincronizar cuando estés en línea')),
        );
        return;
      }

      await supabase.from('users_objets').insert({
        'user_id': userId,
        'objet_id': item['id'],
      });
      await supabase
          .from('users_games')
          .update({'coins': newCoins}).eq('user_id', userId);
      await box.put('user_coins_$userId', newCoins);
      final cachedObjects = box.get('user_objects_$userId', defaultValue: []);
      cachedObjects.add(item);
      await box.put('user_objects_$userId', cachedObjects);
      if (_canUpdateState()) {
        setState(() {
          totalCoins = newCoins;
          userObjects.add(item);
          totalObjects++;
        });
      }
      await fetchUserObjects();
    } catch (e) {
      debugPrint('Error al comprar objeto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al comprar el objeto: $e')),
      );
    }
  }

  Future<void> _useObject(Map<String, dynamic> item, String category) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final pendingBox = Hive.box('pending_actions');
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final imageUrl = item['image_url'] ?? 'assets/images/refmmp.png';
    final localImagePath = item['local_image_path'] ??
        await _downloadAndCacheImage(imageUrl, 'object_image_${item['id']}');

    try {
      if (category == 'avatares') {
        final table = await _getUserTable();
        if (table == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: No se encontró la tabla del usuario')),
          );
          return;
        }
        if (!_isOnline) {
          await pendingBox.add({
            'user_id': userId,
            'action': 'use_avatar',
            'image_url': imageUrl,
            'objet_id': item['id'],
            'table': table,
            'timestamp': DateTime.now().toIso8601String(),
          });
          await box.put('user_profile_image_$userId', localImagePath);
          if (_canUpdateState()) {
            setState(() {
              profileImageUrl = localImagePath;
            });
          }
          profileImageProvider.updateProfileImage(localImagePath,
              notify: true, isOnline: false, userTable: table);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Foto de perfil actualizada offline, se sincronizará cuando estés en línea')),
          );
        } else {
          await supabase
              .from(table)
              .update({'profile_image': imageUrl}).eq('user_id', userId);
          await box.put('user_profile_image_$userId', localImagePath);
          await box.put('user_table_$userId', table);
          if (_canUpdateState()) {
            setState(() {
              profileImageUrl = localImagePath;
            });
          }
          profileImageProvider.updateProfileImage(localImagePath,
              notify: true, isOnline: true, userTable: table);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Foto de perfil actualizada con éxito')),
          );
        }
      } else if (category == 'fondos') {
        if (!_isOnline) {
          await pendingBox.add({
            'user_id': userId,
            'action': 'use_wallpaper',
            'image_url': imageUrl,
            'objet_id': item['id'],
            'timestamp': DateTime.now().toIso8601String(),
          });
          await box.put('user_wallpaper_$userId', localImagePath);
          if (_canUpdateState()) {
            setState(() {
              wallpaperUrl = localImagePath;
            });
          }
          profileImageProvider.updateWallpaper(localImagePath,
              notify: true, isOnline: false);
          await _loadImageHeight();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Fondo de pantalla actualizado offline, se sincronizará cuando estés en línea')),
          );
        } else {
          await supabase
              .from('users_games')
              .update({'wallpapers': imageUrl}).eq('user_id', userId);
          await box.put('user_wallpaper_$userId', localImagePath);
          if (_canUpdateState()) {
            setState(() {
              wallpaperUrl = localImagePath;
            });
          }
          profileImageProvider.updateWallpaper(localImagePath,
              notify: true, isOnline: true);
          await _loadImageHeight();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fondo de pantalla actualizado con éxito')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Objeto ${item['name']} usado${_isOnline ? '' : ' offline'}')),
        );
      }
    } catch (e) {
      debugPrint('Error al usar objeto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al usar el objeto: $e')),
      );
    }
  }

  Future<void> _syncPendingActions() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final pendingBox = Hive.box('pending_actions');
    final pendingActions = pendingBox.values.toList();
    if (pendingActions.isEmpty) return;

    bool isSyncing = false;
    // ignore: dead_code
    if (isSyncing) return;
    isSyncing = true;

    try {
      for (var action in List.from(pendingActions)) {
        final actionUserId = action['user_id'] as String?;
        if (actionUserId != userId) continue;

        final actionType = action['action'] as String?;
        if (actionType == null) continue;

        try {
          if (actionType == 'purchase') {
            final price = (action['price'] as num?)?.toInt() ?? 0;
            final newCoins = totalCoins - price;
            if (newCoins >= 0) {
              if (_isOnline) {
                await supabase.from('users_objets').insert({
                  'user_id': userId,
                  'objet_id': action['objet_id'],
                  'status': true,
                  'created_at': action['timestamp'],
                });
                await supabase
                    .from('users_games')
                    .update({'coins': newCoins}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_coins_$userId', newCoins);
              if (_canUpdateState()) {
                setState(() {
                  totalCoins = newCoins;
                });
              }
            }
          } else if (actionType == 'use_wallpaper') {
            final imageUrl = action['image_url'] as String?;
            if (imageUrl != null) {
              final localPath =
                  await _downloadAndCacheImage(imageUrl, 'wallpaper_$userId');
              if (_isOnline) {
                await supabase
                    .from('users_games')
                    .update({'wallpapers': imageUrl}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_wallpaper_$userId', localPath);
              if (_canUpdateState()) {
                setState(() {
                  wallpaperUrl = localPath;
                });
              }
              final profileImageProvider =
                  Provider.of<ProfileImageProvider>(context, listen: false);
              profileImageProvider.updateWallpaper(localPath,
                  notify: true, isOnline: _isOnline);
              await _loadImageHeight();
            }
          } else if (actionType == 'use_avatar') {
            final table = action['table'] as String? ?? await _getUserTable();
            final imageUrl = action['image_url'] as String?;
            if (table != null && imageUrl != null) {
              final localPath = await _downloadAndCacheImage(
                  imageUrl, 'profile_image_$userId');
              if (_isOnline) {
                await supabase
                    .from(table)
                    .update({'profile_image': imageUrl}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_profile_image_$userId', localPath);
              await box.put('user_table_$userId', table);
              if (_canUpdateState()) {
                setState(() {
                  profileImageUrl = localPath;
                });
              }
              final profileImageProvider =
                  Provider.of<ProfileImageProvider>(context, listen: false);
              profileImageProvider.updateProfileImage(localPath,
                  notify: true, isOnline: _isOnline, userTable: table);
            }
          }
          final index = pendingBox.values.toList().indexOf(action);
          if (index != -1) {
            await pendingBox.deleteAt(index);
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

  void _showEditNicknameDialog() {
    TextEditingController nicknameController =
        TextEditingController(text: nickname);
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor:
              themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Editar Nickname',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nicknameController,
                  maxLength: 14,
                  cursorColor: Colors.blue,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.bottom,
                  decoration: InputDecoration(
                    hintText: 'Maximo 14 letras, Escribelo...',
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    counterText: '',
                  ),
                  style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                  cursorHeight: 20,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(1),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnline ? Colors.blue : Colors.grey,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isOnline
                      ? () async {
                          final newNickname = nicknameController.text.trim();
                          if (newNickname.isEmpty || newNickname.length > 14) {
                            return;
                          }
                          final userId = supabase.auth.currentUser?.id;
                          if (userId != null) {
                            try {
                              final response = await supabase
                                  .from('users_games')
                                  .select()
                                  .eq('user_id', userId)
                                  .maybeSingle();

                              if (response == null) {
                                try {
                                  await supabase.from('users_games').insert({
                                    'user_id': userId,
                                    'nickname': newNickname,
                                    'points_xp_totally': 0,
                                    'points_xp_weekend': 0,
                                    'coins': 0,
                                  });
                                } catch (e) {
                                  if (e.toString().contains('23505')) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        backgroundColor:
                                            themeProvider.isDarkMode
                                                ? Colors.grey[900]
                                                : Colors.white,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close_rounded,
                                                color: Colors.red,
                                                size: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.3,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'No puedes cambiar el nombre',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  minimumSize: const Size(
                                                      double.infinity, 48),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  rethrow;
                                }
                              } else {
                                try {
                                  await supabase
                                      .from('users_games')
                                      .update({'nickname': newNickname}).eq(
                                          'user_id', userId);
                                } catch (e) {
                                  if (e.toString().contains('23505')) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        backgroundColor:
                                            themeProvider.isDarkMode
                                                ? Colors.grey[900]
                                                : Colors.white,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close_rounded,
                                                color: Colors.red,
                                                size: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.3,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'No puedes cambiar el nombre',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  minimumSize: const Size(
                                                      double.infinity, 48),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  rethrow;
                                }
                              }

                              final box = Hive.box('offline_data');
                              await box.put(
                                  'user_nickname_$userId', newNickname);
                              if (_canUpdateState()) {
                                setState(() {
                                  nickname = newNickname;
                                });
                              }

                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: themeProvider.isDarkMode
                                      ? Colors.grey[900]
                                      : Colors.white,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.green,
                                          size: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.3,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '¡Se cambió correctamente!',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            minimumSize:
                                                const Size(double.infinity, 48),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(
                                                context); // Close success dialog
                                            Navigator.pop(
                                                context); // Close edit dialog
                                          },
                                          child: const Text(
                                            'OK',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error al actualizar nickname: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Error al actualizar nickname: $e')),
                              );
                            }
                          }
                        }
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: themeProvider.isDarkMode
                                  ? Colors.grey[900]
                                  : Colors.white,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.close_rounded,
                                      color: Colors.red,
                                      size: MediaQuery.of(context).size.width *
                                          0.3,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No puedes cambiar el nombre porque estás offline',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        minimumSize:
                                            const Size(double.infinity, 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        'OK',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildNicknameWidget(bool isAppBar) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textStyle = TextStyle(
      color: isAppBar
          ? Colors.white
          : (themeProvider.isDarkMode ? Colors.white : Colors.black87),
      fontWeight: FontWeight.bold,
      fontSize: isAppBar ? 20 : 24,
      shadows: isAppBar
          ? [
              const Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 4,
              ),
            ]
          : [],
    );
    const maxWidth = 220.0;
    final text = nickname?.toUpperCase() ?? 'JUGADOR';

    return _needsMarquee(text, maxWidth, textStyle)
        ? SizedBox(
            width: maxWidth,
            height: isAppBar ? 40 : 50,
            child: Marquee(
              text: text,
              style: textStyle,
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: 30.0,
              velocity: 40.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.bounceIn,
            ),
          )
        : Text(
            text,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
  }

  Widget _buildImageWidget(String category, String imagePath, bool isObtained,
      String visibilityKey) {
    final isVisible = _gifVisibility[visibilityKey] ?? false;

    Widget imageWidget;

    if (category == 'avatares') {
      // Diseño circular para avatares
      imageWidget = Padding(
        padding: const EdgeInsets.all(4.0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isObtained ? Colors.green : Colors.blue,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildImageContent(imagePath, isVisible, category),
            ),
          ),
        ),
      );
    } else {
      // Diseño redondeado para trompetas, fondos, logros y canciones
      imageWidget = Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: category == 'trompetas' ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageContent(imagePath, isVisible, category),
                ),
              ),
              // if (isObtained)
              //   Positioned(
              //     top: 8,
              //     right: 8,
              //     child: Icon(
              //       Icons.check_circle_rounded,
              //       color: Colors.green,
              //       size: 20,
              //     ),
              //   ),
            ],
          ),
        ),
      );
    }

    return imageWidget;
  }

  Widget _buildImageContent(String imagePath, bool isVisible, String category) {
    final fit = BoxFit.cover;

    if (!isVisible || imagePath.isEmpty) {
      return Image.asset(
        'assets/images/refmmp.png',
        fit: fit,
      );
    }

    Widget imageWidget;

    if (!imagePath.startsWith('http') && File(imagePath).existsSync()) {
      imageWidget = Image.file(
        File(imagePath),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/refmmp.png',
            fit: fit,
          );
        },
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        cacheManager: CustomCacheManager.instance,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
        errorWidget: (context, url, error) {
          return Image.asset(
            'assets/images/refmmp.png',
            fit: fit,
          );
        },
        memCacheWidth: 200,
        memCacheHeight: 200,
        fadeInDuration: const Duration(milliseconds: 200),
      );
    }

    return imageWidget;
  }

  Widget _buildWeeklyXpChart() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Preparar datos para el gráfico
    List<FlSpot> userSpots = [];

    // Calcular los últimos 7 días con nombres dinámicos
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayNamesShort = ['D', 'L', 'Ma', 'Mi', 'J', 'V', 'S'];

    // Generar etiquetas de días dinámicas (últimos 7 días hasta hoy)
    List<String> dynamicDayLabels = [];
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: 6 - i));
      final dayName = dayNamesShort[date.weekday % 7];
      final isToday = i == 6;
      dynamicDayLabels.add(isToday ? 'Hoy' : dayName);
    }

    // Obtener datos del usuario actual
    debugPrint('📊 Building chart with weeklyXpData: $weeklyXpData');
    for (int i = 0; i < 7; i++) {
      final xp = weeklyXpData[i] ?? 0.0;
      userSpots.add(FlSpot(i.toDouble(), xp));
      debugPrint('  Day $i (${dynamicDayLabels[i]}): $xp XP');
    }

    // Calcular máximo para el eje Y
    double maxY = 100;
    final allValues = userSpots.map((s) => s.y).toList();
    if (allValues.isNotEmpty) {
      maxY = allValues.reduce((a, b) => a > b ? a : b);
      maxY = (maxY * 1.2).ceilToDouble(); // Agregar 20% de margen
      if (maxY < 100) maxY = 100;
    }
    debugPrint('📊 Chart maxY: $maxY');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color.fromARGB(255, 34, 34, 34)
              : const Color.fromARGB(255, 202, 202, 209),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EXP últimos 7 días',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pointsXpWeekend EXP',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Gráfico
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value < 0 || value >= 7) return Container();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            dynamicDayLabels[value.toInt()],
                            style: TextStyle(
                              color: value.toInt() == 6
                                  ? Colors.blue // Resaltar "Hoy" en azul
                                  : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight: value.toInt() == 6
                                  ? FontWeight.w900 // "Hoy" más bold
                                  : FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 4,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                      width: 1,
                    ),
                    left: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black26,
                      width: 1,
                    ),
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Línea del usuario actual
                  LineChartBarData(
                    spots: userSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) =>
                        isDark ? Colors.black87 : Colors.white,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        final dayIndex = flSpot.x.toInt();
                        final date =
                            today.subtract(Duration(days: 6 - dayIndex));
                        final dayLabel =
                            dayIndex == 6 ? 'Hoy' : '${date.day}/${date.month}';

                        return LineTooltipItem(
                          '$dayLabel\n${flSpot.y.toInt()} XP',
                          TextStyle(
                            color: barSpot.bar.color,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LearningPage(instrumentName: widget.instrumentName),
          ),
        );
        return false;
      },
      child: Scaffold(
        body: RefreshIndicator(
          color: Colors.blue,
          onRefresh: () async {
            await _checkConnectivityStatus();
            await fetchTotalCoins();
            await fetchUserProfileImage();
            await fetchWallpaper();
            await fetchUserAchievements();
            await fetchUserObjects();
            await fetchTotalAvailableObjects();
            await fetchUserFavoriteSongs();
            await fetchWeeklyXpData();
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
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LearningPage(
                              instrumentName: widget.instrumentName)),
                    ),
                  ),
                  title: isCollapsed
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            const SizedBox(width: 10),
                            _buildNicknameWidget(true),
                          ],
                        )
                      : null,
                  centerTitle: true,
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
                                Center(
                                  child: CircleAvatar(
                                    radius: 60.0,
                                    backgroundImage: profileImageUrl!
                                            .startsWith('assets/')
                                        ? AssetImage(profileImageUrl!)
                                            as ImageProvider
                                        : (!profileImageUrl!
                                                    .startsWith('http') &&
                                                File(profileImageUrl!)
                                                    .existsSync()
                                            ? FileImage(File(profileImageUrl!))
                                            : NetworkImage(profileImageUrl!)),
                                    backgroundColor: Colors.transparent,
                                    onBackgroundImageError: (_, __) =>
                                        AssetImage('assets/images/refmmp.png'),
                                  ),
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
                            _buildNicknameWidget(false),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Mis monedas',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'assets/images/coin.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                numberFormat.format(totalCoins),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(1, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'XP Semanal',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.bolt,
                                                color: Colors.yellow, size: 20),
                                            const SizedBox(width: 4),
                                            Text(
                                              numberFormat
                                                  .format(pointsXpWeekend),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Column(children: [
                                      Text(
                                        'XP Total',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.bolt,
                                              color: Colors.yellow, size: 20),
                                          const SizedBox(width: 4),
                                          Text(
                                            numberFormat
                                                .format(pointsXpTotally),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "| ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'LOGROS OBTENIDOS',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.isDarkMode
                                  ? const Color.fromARGB(255, 34, 34, 34)
                                  : const Color.fromARGB(255, 202, 202, 209),
                              width: 2,
                            ),
                          ),
                          child: userAchievements.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No tienes logros obtenidos.',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.6,
                                  ),
                                  itemCount: userAchievements.length,
                                  itemBuilder: (context, index) {
                                    final achievement = userAchievements[index];
                                    final visibilityKey =
                                        'achievement_${achievement['id']}';
                                    return VisibilityDetector(
                                      key: Key(visibilityKey),
                                      onVisibilityChanged: (visibilityInfo) {
                                        final visiblePercentage =
                                            visibilityInfo.visibleFraction *
                                                100;
                                        if (mounted) {
                                          setState(() {
                                            _gifVisibility[visibilityKey] =
                                                visiblePercentage > 10;
                                          });
                                        }
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          showAchievementDialog(
                                              context, achievement);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.green,
                                                width: 1.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AspectRatio(
                                                aspectRatio: 1.0,
                                                child: _buildImageWidget(
                                                  'achievements',
                                                  achievement[
                                                          'local_image_path'] ??
                                                      achievement['image'] ??
                                                      'assets/images/refmmp.png',
                                                  true,
                                                  visibilityKey,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                achievement['name'] ?? 'Logro',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.green,
                                                    size: 11,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Obtenido',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (totalAchievements > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MyObjectsPage(
                                                instrumentName:
                                                    widget.instrumentName,
                                                selectedIndex: 0,
                                              )));
                                },
                                child: Text(
                                  'TODOS MIS LOGROS ($totalAchievements)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "| ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'ESTADÍSTICAS',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildWeeklyXpChart(),
                        const SizedBox(height: 10),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "| ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'OBJETOS OBTENIDOS',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.isDarkMode
                                  ? const Color.fromARGB(255, 34, 34, 34)
                                  : const Color.fromARGB(255, 202, 202, 209),
                              width: 2,
                            ),
                          ),
                          child: userObjects.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No tienes objetos obtenidos.',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.9,
                                  ),
                                  itemCount: userObjects.length,
                                  itemBuilder: (context, index) {
                                    final objet = userObjects[index];
                                    final category =
                                        objet['category'].toLowerCase();
                                    final visibilityKey = '${objet['id']}';
                                    return VisibilityDetector(
                                      key: Key(visibilityKey),
                                      onVisibilityChanged: (visibilityInfo) {
                                        final visiblePercentage =
                                            visibilityInfo.visibleFraction *
                                                100;
                                        setState(() {
                                          _gifVisibility[visibilityKey] =
                                              visiblePercentage > 10;
                                        });
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          showObjectDialog(
                                            context,
                                            objet,
                                            category,
                                            totalCoins,
                                            _useObject,
                                            _purchaseObject,
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.green,
                                                width: 1.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Expanded(
                                                child: _buildImageWidget(
                                                  category,
                                                  objet['local_image_path'] ??
                                                      objet['image_url'] ??
                                                      'assets/images/refmmp.png',
                                                  true,
                                                  visibilityKey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                objet['name'] ?? 'Objeto',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.green,
                                                    size: 11,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Obtenido',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (totalObjects > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MyObjectsPage(
                                                instrumentName:
                                                    widget.instrumentName,
                                                selectedIndex: 2,
                                              )));
                                },
                                child: Text(
                                  'TODOS MIS OBJETOS ($totalObjects / $totalAvailableObjects)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
                        ),
                        // Agregar después del contenedor de "Objetos Obtenidos" en el método build

                        Row(
                          children: [
                            Text(
                              "| ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              'MIS CANCIONES FAVORITAS',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeProvider.isDarkMode
                                  ? const Color.fromARGB(255, 34, 34, 34)
                                  : const Color.fromARGB(255, 202, 202, 209),
                              width: 2,
                            ),
                          ),
                          child: userFavoriteSongs.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No tienes canciones favoritas.',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio:
                                        0.7, // Ajustado para mejor proporción sin botón
                                  ),
                                  itemCount: userFavoriteSongs.length,
                                  itemBuilder: (context, index) {
                                    final song = userFavoriteSongs[index];
                                    final visibilityKey = 'song_${song['id']}';
                                    return VisibilityDetector(
                                      key: Key(visibilityKey),
                                      onVisibilityChanged: (visibilityInfo) {
                                        final visiblePercentage =
                                            visibilityInfo.visibleFraction *
                                                100;
                                        setState(() {
                                          _gifVisibility[visibilityKey] =
                                              visiblePercentage > 10;
                                        });
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          debugPrint(
                                              'Profile.dart navigating to PlayPage');
                                          debugPrint(
                                              'Profile Image URL: $profileImageUrl');
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlayPage(
                                                songId: song['id'].toString(),
                                                songName: song['name'] ??
                                                    'Sin nombre',
                                                profileImageUrl:
                                                    profileImageUrl,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(
                                              2), // Padding interno para el contenedor
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.blue, width: 1.5),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Stack(
                                                children: [
                                                  AspectRatio(
                                                    aspectRatio: 1.0,
                                                    child: _buildImageWidget(
                                                      'songs',
                                                      song['local_image_path'] ??
                                                          song['image'] ??
                                                          'assets/images/refmmp.png',
                                                      true,
                                                      visibilityKey,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Icon(
                                                      Icons.favorite,
                                                      color: Colors.red,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                song['name'] ?? 'Canción',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      themeProvider.isDarkMode
                                                          ? Colors.white
                                                          : Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (totalFavoriteSongs > 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  // Navegar a una página que muestre todas las canciones favoritas
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => MyObjectsPage(
                                                instrumentName:
                                                    widget.instrumentName,
                                                selectedIndex: 1,
                                              )));
                                },
                                child: Text(
                                  'TODAS MIS CANCIONES FAVORITAS ($totalFavoriteSongs)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 40,
                          thickness: 2,
                          color: themeProvider.isDarkMode
                              ? const Color.fromARGB(255, 34, 34, 34)
                              : const Color.fromARGB(255, 236, 234, 234),
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
      ),
    );
  }
}
