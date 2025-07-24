// ignore_for_file: dead_code

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/dialogs/dialog_objets.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
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
  final Map<String, bool> _gifVisibility = {};

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus();
    _initializeUserData();
    fetchUserProfileImage();
    fetchWallpaper();
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
        await fetchUserObjects();
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

  Future<void> _initializeUserData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await ensureUserInUsersGames(userId, 'user_$userId');
      await fetchTotalCoins();
      await fetchUserProfileImage();
      await fetchWallpaper();
      await fetchUserObjects();
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
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_coins_$userId';

    try {
      if (!_isOnline) {
        setState(() {
          totalCoins = box.get(cacheKey, defaultValue: totalCoins);
          nickname = box.get('user_nickname_$userId', defaultValue: nickname);
          pointsXpTotally = box.get('points_xp_totally_$userId',
              defaultValue: pointsXpTotally);
          pointsXpWeekend = box.get('points_xp_weekend_$userId',
              defaultValue: pointsXpWeekend);
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
      setState(() {
        totalCoins = box.get(cacheKey, defaultValue: totalCoins);
        nickname = box.get('user_nickname_$userId', defaultValue: nickname);
        pointsXpTotally =
            box.get('points_xp_totally_$userId', defaultValue: pointsXpTotally);
        pointsXpWeekend =
            box.get('points_xp_weekend_$userId', defaultValue: pointsXpWeekend);
      });
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
    if (userId == null) return;

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
        setState(() {
          profileImageUrl = profileImagePath;
        });
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

  Future<void> fetchWallpaper() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

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
        setState(() {
          wallpaperUrl = wallpaperPath;
        });
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
      setState(() {
        wallpaperUrl = imageUrl;
      });
      profileImageProvider.updateWallpaper(imageUrl!,
          notify: true, isOnline: true);
      await box.put(cacheKey, imageUrl);
      await _loadImageHeight();
    } catch (e) {
      debugPrint('Error al obtener el fondo de pantalla: $e');
      final cachedWallpaper = box.get(cacheKey,
          defaultValue:
              profileImageProvider.wallpaperUrl ?? 'assets/images/refmmp.png');
      setState(() {
        wallpaperUrl = cachedWallpaper;
      });
      profileImageProvider.updateWallpaper(cachedWallpaper,
          notify: true, isOnline: false);
      await _loadImageHeight();
    }
  }

  Future<void> _loadImageHeight() async {
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final wallpaperUrl = profileImageProvider.wallpaperUrl;

    if (wallpaperUrl == null || wallpaperUrl.isEmpty) {
      setState(() {
        expandedHeight = 200.0;
      });
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

  Future<void> fetchUserObjects() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Error: userId is null');
      return;
    }

    debugPrint('Fetching objects for userId: $userId');

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objects_$userId';

    try {
      if (!_isOnline) {
        final cachedObjects = box.get(cacheKey, defaultValue: []);
        setState(() {
          userObjects =
              List<Map<String, dynamic>>.from(cachedObjects).take(3).toList();
          totalObjects = cachedObjects.length;
        });
        debugPrint('Offline: Loaded ${userObjects.length} objects from cache');
        return;
      }

      final response = await supabase
          .from('users_objets')
          .select(
              'objet_id, objets!inner(id, image_url, name, category, description, price, created_at)')
          .eq('user_id', userId)
          .order('created_at', ascending: false, referencedTable: 'objets')
          .limit(3);

      final List<Map<String, dynamic>> fetchedObjects = [];
      for (var item in response) {
        final objet = item['objets'] as Map<String, dynamic>;
        final imageUrl = objet['image_url'] ?? 'assets/images/refmmp.png';
        final objectCacheKey = 'object_image_${objet['id']}';
        final localImagePath =
            await _downloadAndCacheImage(imageUrl, objectCacheKey);
        fetchedObjects.add({
          'id': objet['id'],
          'image_url': imageUrl,
          'local_image_path': localImagePath,
          'name': objet['name'] ?? 'Objeto',
          'category': objet['category'] ?? 'otros',
          'description': objet['description'] ?? 'Sin descripción',
          'price': objet['price'] ?? 0,
          'created_at': objet['created_at'] ?? DateTime.now().toIso8601String(),
        });
        _gifVisibility['${objet['id']}'] = true;
      }

      setState(() {
        userObjects = fetchedObjects;
        totalObjects = fetchedObjects.length;
      });
      await box.put(cacheKey, fetchedObjects);
      debugPrint('Online: Fetched ${fetchedObjects.length} objects');
    } catch (e, stackTrace) {
      debugPrint('Error fetching user objects: $e\nStack trace: $stackTrace');
      setState(() {
        userObjects =
            List<Map<String, dynamic>>.from(box.get(cacheKey, defaultValue: []))
                .take(3)
                .toList();
        totalObjects = box.get(cacheKey, defaultValue: []).length;
      });
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
          setState(() {
            profileImageUrl = localImagePath;
          });
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
          setState(() {
            profileImageUrl = localImagePath;
          });
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
          setState(() {
            wallpaperUrl = localImagePath;
          });
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
          setState(() {
            wallpaperUrl = localImagePath;
          });
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
        setState(() {
          totalCoins = newCoins;
          userObjects.add(item);
          totalObjects++;
        });
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
        'status': true,
        'created_at': DateTime.now().toIso8601String(),
      });
      await supabase
          .from('users_games')
          .update({'coins': newCoins}).eq('user_id', userId);
      await box.put('user_coins_$userId', newCoins);
      final cachedObjects = box.get('user_objects_$userId', defaultValue: []);
      cachedObjects.add(item);
      await box.put('user_objects_$userId', cachedObjects);
      setState(() {
        totalCoins = newCoins;
        userObjects.add(item);
        totalObjects++;
      });
      await fetchUserObjects();
    } catch (e) {
      debugPrint('Error al comprar objeto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al comprar el objeto: $e')),
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
              setState(() {
                totalCoins = newCoins;
              });
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
              setState(() {
                wallpaperUrl = localPath;
              });
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
              setState(() {
                profileImageUrl = localPath;
              });
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
                              setState(() {
                                nickname = newNickname;
                              });

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
    // ignore: unused_local_variable
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isVisible = _gifVisibility[visibilityKey] ?? false;

    if (!isVisible || imagePath.isEmpty) {
      return Image.asset('assets/images/refmmp.png', fit: BoxFit.cover);
    }

    if (category == 'avatares') {
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isObtained ? Colors.green : Colors.blue, width: 2),
            ),
            child: ClipOval(
                child: _buildImageContent(imagePath, isVisible, category)),
          ),
        ),
      );
    } else if (category == 'trompetas') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
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
              if (isObtained)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20),
                ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
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
            if (isObtained)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildImageContent(String imagePath, bool isVisible, String category) {
    if (!imagePath.startsWith('http') && File(imagePath).existsSync()) {
      return Image.file(
        File(imagePath),
        fit: category == 'trompetas' ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading local image: $error, path: $imagePath');
          return Image.asset('assets/images/refmmp.png', fit: BoxFit.cover);
        },
      );
    } else if (Uri.tryParse(imagePath)?.isAbsolute == true) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        cacheManager: CustomCacheManager.instance,
        fit: category == 'trompetas' ? BoxFit.contain : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
        errorWidget: (context, url, error) {
          debugPrint('Error loading network image: $error, url: $url');
          return Image.asset('assets/images/refmmp.png', fit: BoxFit.cover);
        },
        memCacheWidth: 200,
        memCacheHeight: 200,
        fadeInDuration: const Duration(milliseconds: 200),
      );
    } else {
      return Image.asset('assets/images/refmmp.png', fit: BoxFit.cover);
    }
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
                                    Column(
                                      children: [
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
                                      ],
                                    ),
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
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ObjetsPage(
                                          instrumentName:
                                              widget.instrumentName),
                                    ),
                                  );
                                },
                                child: Text(
                                  'TODOS MIS OBJETOS ($totalObjects)',
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
