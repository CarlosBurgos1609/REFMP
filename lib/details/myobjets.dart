// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:refmp/details/objetsDetails.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:refmp/dialogs/dialog_achievements.dart';
import 'package:refmp/dialogs/dialog_objets.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:refmp/games/play.dart';
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

class MyObjectsPage extends StatefulWidget {
  final String instrumentName;
  const MyObjectsPage({Key? key, required this.instrumentName})
      : super(key: key);

  @override
  _MyObjectsPageState createState() => _MyObjectsPageState();
}

class _MyObjectsPageState extends State<MyObjectsPage> {
  final supabase = Supabase.instance.client;
  int totalCoins = 0;
  bool _isOnline = false;
  String? wallpaperUrl;
  String? profileImageUrl;
  bool isSearching = false;
  bool isCollapsed = false;
  final _searchController = TextEditingController();
  String? selectedSortOption;
  double? expandedHeight;
  final Map<String, bool> _gifVisibility = {};
  int _selectedIndex = 0;

  List<Map<String, dynamic>> userAchievements = [];
  List<Map<String, dynamic>> userFavoriteSongs = [];
  List<Map<String, dynamic>> userObjects = [];
  List<Map<String, dynamic>> userAvatars = [];
  List<Map<String, dynamic>> userWallpapers = [];
  List<Map<String, dynamic>> userTrumpets = [];
  List<Map<String, dynamic>> filteredItems = [];
  int totalAchievements = 0;
  int totalFavoriteSongs = 0;
  int totalObjects = 0;
  int totalAvatars = 0;
  int totalWallpapers = 0;
  int totalTrumpets = 0;
  int totalAvailableAvatars = 0;
  int totalAvailableWallpapers = 0;
  int totalAvailableTrumpets = 0;
  int totalAvailableObjects = 0;
  int totalAvailableAchievements = 0;
  int totalAvailableSongs = 0;

  final List<Map<String, dynamic>> categories = [
    {'label': 'Logros', 'icon': Icons.star_border, 'selectedIcon': Icons.star},
    {
      'label': 'Canciones',
      'icon': Icons.favorite_border,
      'selectedIcon': Icons.favorite
    },
    {
      'label': 'Objetos',
      'icon': Icons.inventory_2_outlined,
      'selectedIcon': Icons.inventory_2
    },
    {
      'label': 'Avatares',
      'icon': Icons.account_circle_outlined,
      'selectedIcon': Icons.account_circle
    },
    {
      'label': 'Fondos',
      'icon': Icons.image_outlined,
      'selectedIcon': Icons.image
    },
    {
      'label': 'Trompetas',
      'icon': Icons.music_note_outlined,
      'selectedIcon': Icons.music_note
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus();
    _initializeData();
    _searchController.addListener(() {
      filterItems(_searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageHeight();
    });
    Connectivity().onConnectivityChanged.listen((result) async {
      bool isOnline = result != ConnectivityResult.none;
      setState(() {
        _isOnline = isOnline;
      });
      if (isOnline) {
        await _initializeData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _initializeData() async {
    await Future.wait([
      fetchTotalCoins(),
      fetchWallpaper(),
      fetchProfileImage(),
      fetchUserAchievements(),
      fetchUserFavoriteSongs(),
      fetchUserObjects(),
    ]);
    updateFilteredItems();
  }

  void updateFilteredItems() {
    setState(() {
      switch (_selectedIndex) {
        case 0:
          filteredItems = List.from(userAchievements);
          break;
        case 1:
          filteredItems = List.from(userFavoriteSongs);
          break;
        case 2:
          filteredItems = List.from(userObjects);
          break;
        case 3:
          filteredItems = List.from(userAvatars);
          break;
        case 4:
          filteredItems = List.from(userWallpapers);
          break;
        case 5:
          filteredItems = List.from(userTrumpets);
          break;
      }
      applySort(selectedSortOption);
    });
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
        });
        return;
      }

      final response = await supabase
          .from('users_games')
          .select('coins')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['coins'] != null) {
        setState(() {
          totalCoins = response['coins'] as int;
        });
        await box.put(cacheKey, totalCoins);
      } else {
        setState(() {
          totalCoins = box.get(cacheKey, defaultValue: totalCoins);
        });
      }
    } catch (e) {
      debugPrint('Error al obtener las monedas: $e');
      setState(() {
        totalCoins = box.get(cacheKey, defaultValue: totalCoins);
      });
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
        final cachedWallpaper = box.get(cacheKey, defaultValue: wallpaperUrl);
        final wallpaperPath = (cachedWallpaper != null &&
                cachedWallpaper.isNotEmpty &&
                !cachedWallpaper.startsWith('http') &&
                File(cachedWallpaper).existsSync())
            ? cachedWallpaper
            : wallpaperUrl ?? 'assets/images/refmmp.png';
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
          : wallpaperUrl ?? 'assets/images/refmmp.png';

      if (imageUrl != 'assets/images/refmmp.png' &&
          Uri.tryParse(imageUrl!)?.isAbsolute == true) {
        try {
          final localPath =
              await _downloadAndCacheImage(imageUrl, 'wallpaper_$userId');
          imageUrl = localPath;
        } catch (e) {
          debugPrint('Error caching wallpaper: $e');
          imageUrl = wallpaperUrl ?? 'assets/images/refmmp.png';
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
      setState(() {
        wallpaperUrl = box.get(cacheKey,
            defaultValue: wallpaperUrl ?? 'assets/images/refmmp.png');
      });
      profileImageProvider.updateWallpaper(wallpaperUrl!,
          notify: true, isOnline: false);
      await _loadImageHeight();
    }
  }

  Future<void> fetchProfileImage() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_profile_image_$userId';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    try {
      if (!_isOnline) {
        final cachedProfileImage =
            box.get(cacheKey, defaultValue: profileImageUrl);
        final profileImagePath = (cachedProfileImage != null &&
                cachedProfileImage.isNotEmpty &&
                !cachedProfileImage.startsWith('http') &&
                File(cachedProfileImage).existsSync())
            ? cachedProfileImage
            : profileImageUrl ?? 'assets/images/refmmp.png';
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
              imageUrl = profileImageUrl ?? 'assets/images/refmmp.png';
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
      setState(() {
        profileImageUrl = box.get(cacheKey,
            defaultValue: profileImageUrl ?? 'assets/images/refmmp.png');
      });
      profileImageProvider.updateProfileImage(profileImageUrl!,
          notify: true, isOnline: false);
    }
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

  Future<void> fetchUserAchievements() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_achievements_$userId';
    final countCacheKey = 'total_achievements_$userId';
    final totalAvailableCacheKey = 'total_available_achievements_$userId';

    try {
      if (!_isOnline) {
        final cachedAchievements = box.get(cacheKey, defaultValue: []);
        setState(() {
          userAchievements = List<Map<String, dynamic>>.from(
            cachedAchievements.map((item) => Map<String, dynamic>.from(item)),
          );
          totalAchievements =
              box.get(countCacheKey, defaultValue: cachedAchievements.length);
          totalAvailableAchievements = box.get(totalAvailableCacheKey,
              defaultValue: cachedAchievements.length);
        });
        for (var item in userAchievements) {
          final imageUrl = item['image'] ?? 'assets/images/refmmp.png';
          final objectCacheKey = 'achievement_image_${item['id']}';
          final localImagePath =
              await _downloadAndCacheImage(imageUrl, objectCacheKey);
          item['local_image_path'] = localImagePath;
          _gifVisibility['achievement_${item['id']}'] = true;
        }
        return;
      }

      final response = await supabase
          .from('users_achievements')
          .select(
              'id, created_at, achievements!inner(name, image, description)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> fetchedAchievements = [];
      for (var item in response) {
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

      final countResponse = await supabase
          .from('users_achievements')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      final totalAvailableResponse = await supabase
          .from('achievements')
          .select('id')
          .count(CountOption.exact);

      setState(() {
        userAchievements = fetchedAchievements;
        totalAchievements = countResponse.count;
        totalAvailableAchievements = totalAvailableResponse.count;
      });
      await box.put(cacheKey, fetchedAchievements);
      await box.put(countCacheKey, countResponse.count);
      await box.put(totalAvailableCacheKey, totalAvailableResponse.count);
    } catch (e) {
      debugPrint('Error fetching user achievements: $e');
      final cachedAchievements = box.get(cacheKey, defaultValue: []);
      setState(() {
        userAchievements = List<Map<String, dynamic>>.from(
          cachedAchievements.map((item) => Map<String, dynamic>.from(item)),
        );
        totalAchievements =
            box.get(countCacheKey, defaultValue: cachedAchievements.length);
        totalAvailableAchievements = box.get(totalAvailableCacheKey,
            defaultValue: cachedAchievements.length);
      });
    }
  }

  Future<void> fetchUserFavoriteSongs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_favorite_songs_$userId';
    final countCacheKey = 'total_favorite_songs_$userId';
    final totalAvailableCacheKey = 'total_available_songs_$userId';

    try {
      if (!_isOnline) {
        final cachedSongs = box.get(cacheKey, defaultValue: []);
        setState(() {
          userFavoriteSongs = List<Map<String, dynamic>>.from(
            cachedSongs.map((item) => Map<String, dynamic>.from(item)),
          );
          totalFavoriteSongs =
              box.get(countCacheKey, defaultValue: cachedSongs.length);
          totalAvailableSongs =
              box.get(totalAvailableCacheKey, defaultValue: cachedSongs.length);
        });
        for (var item in userFavoriteSongs) {
          final imageUrl = item['image'] ?? 'assets/images/refmmp.png';
          final songCacheKey = 'song_image_${item['id']}';
          final localImagePath =
              await _downloadAndCacheImage(imageUrl, songCacheKey);
          item['local_image_path'] = localImagePath;
          _gifVisibility['song_${item['id']}'] = true;
        }
        return;
      }

      final response = await supabase
          .from('songs_favorite')
          .select('song_id, created_at, songs!inner(id, name, image)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> fetchedSongs = [];
      for (var item in response) {
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

      final countResponse = await supabase
          .from('songs_favorite')
          .select('song_id')
          .eq('user_id', userId)
          .count(CountOption.exact);

      final totalAvailableResponse =
          await supabase.from('songs').select('id').count(CountOption.exact);

      setState(() {
        userFavoriteSongs = fetchedSongs;
        totalFavoriteSongs = countResponse.count;
        totalAvailableSongs = totalAvailableResponse.count;
      });
      await box.put(cacheKey, fetchedSongs);
      await box.put(countCacheKey, countResponse.count);
      await box.put(totalAvailableCacheKey, totalAvailableResponse.count);
    } catch (e) {
      debugPrint('Error fetching favorite songs: $e');
      final cachedSongs = box.get(cacheKey, defaultValue: []);
      setState(() {
        userFavoriteSongs = List<Map<String, dynamic>>.from(
          cachedSongs.map((item) => Map<String, dynamic>.from(item)),
        );
        totalFavoriteSongs =
            box.get(countCacheKey, defaultValue: cachedSongs.length);
        totalAvailableSongs =
            box.get(totalAvailableCacheKey, defaultValue: cachedSongs.length);
      });
    }
  }

  Future<void> fetchUserObjects() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Error: userId is null in fetchUserObjects');
      return;
    }

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objects_$userId';
    final countCacheKey = 'total_objects_$userId';
    final avatarCacheKey = 'user_avatares_$userId';
    final wallpaperCacheKey = 'user_fondos_$userId';
    final trumpetCacheKey = 'user_trompetas_$userId';
    final totalAvailableObjectsKey = 'total_available_objects_$userId';
    final totalAvailableAvatarsKey = 'total_available_avatares_$userId';
    final totalAvailableWallpapersKey = 'total_available_fondos_$userId';
    final totalAvailableTrumpetsKey = 'total_available_trompetas_$userId';

    try {
      if (!_isOnline) {
        final cachedObjects = box.get(cacheKey, defaultValue: []);
        final cachedAvatars = box.get(avatarCacheKey, defaultValue: []);
        final cachedWallpapers = box.get(wallpaperCacheKey, defaultValue: []);
        final cachedTrumpets = box.get(trumpetCacheKey, defaultValue: []);
        setState(() {
          userObjects = List<Map<String, dynamic>>.from(
            cachedObjects.map((item) => Map<String, dynamic>.from(item)),
          );
          userAvatars = List<Map<String, dynamic>>.from(
            cachedAvatars.map((item) => Map<String, dynamic>.from(item)),
          );
          userWallpapers = List<Map<String, dynamic>>.from(
            cachedWallpapers.map((item) => Map<String, dynamic>.from(item)),
          );
          userTrumpets = List<Map<String, dynamic>>.from(
            cachedTrumpets.map((item) => Map<String, dynamic>.from(item)),
          );
          totalObjects =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
          totalAvatars =
              box.get(avatarCacheKey, defaultValue: cachedAvatars.length);
          totalWallpapers =
              box.get(wallpaperCacheKey, defaultValue: cachedWallpapers.length);
          totalTrumpets =
              box.get(trumpetCacheKey, defaultValue: cachedTrumpets.length);
          totalAvailableObjects = box.get(totalAvailableObjectsKey,
              defaultValue: cachedObjects.length);
          totalAvailableAvatars = box.get(totalAvailableAvatarsKey,
              defaultValue: cachedAvatars.length);
          totalAvailableWallpapers = box.get(totalAvailableWallpapersKey,
              defaultValue: cachedWallpapers.length);
          totalAvailableTrumpets = box.get(totalAvailableTrumpetsKey,
              defaultValue: cachedTrumpets.length);
        });
        for (var item in userObjects) {
          final imageUrl = item['image_url'] ?? 'assets/images/refmmp.png';
          final objectCacheKey = 'object_image_${item['id']}';
          final localImagePath =
              await _downloadAndCacheImage(imageUrl, objectCacheKey);
          item['local_image_path'] = localImagePath;
          _gifVisibility['${item['id']}'] = true;
        }
        return;
      }

      final response = await supabase
          .from('users_objets')
          .select(
              'objet_id, objets!inner(id, image_url, name, category, description, price, created_at)')
          .eq('user_id', userId)
          .order('created_at', ascending: false, referencedTable: 'objets');

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
          'category': objet['category']?.toLowerCase() ?? 'otros',
          'description': objet['description'] ?? 'Sin descripción',
          'price': objet['price'] ?? 0,
          'created_at': objet['created_at'] ?? DateTime.now().toIso8601String(),
        });
        _gifVisibility['${objet['id']}'] = true;
      }

      final totalAvailableObjectsResponse =
          await supabase.from('objets').select('id').count(CountOption.exact);

      final totalAvailableAvatarsResponse = await supabase
          .from('objets')
          .select('id')
          .eq('category', 'avatares')
          .count(CountOption.exact);

      final totalAvailableWallpapersResponse = await supabase
          .from('objets')
          .select('id')
          .eq('category', 'fondos')
          .count(CountOption.exact);

      final totalAvailableTrumpetsResponse = await supabase
          .from('objets')
          .select('id')
          .eq('category', 'trompetas')
          .count(CountOption.exact);

      setState(() {
        userObjects = fetchedObjects;
        userAvatars = fetchedObjects
            .where((obj) => obj['category'].toLowerCase() == 'avatares')
            .toList();
        userWallpapers = fetchedObjects
            .where((obj) => obj['category'].toLowerCase() == 'fondos')
            .toList();
        userTrumpets = fetchedObjects
            .where((obj) => obj['category'].toLowerCase() == 'trompetas')
            .toList();
        totalObjects = fetchedObjects.length;
        totalAvatars = userAvatars.length;
        totalWallpapers = userWallpapers.length;
        totalTrumpets = userTrumpets.length;
        totalAvailableObjects = totalAvailableObjectsResponse.count;
        totalAvailableAvatars = totalAvailableAvatarsResponse.count;
        totalAvailableWallpapers = totalAvailableWallpapersResponse.count;
        totalAvailableTrumpets = totalAvailableTrumpetsResponse.count;
      });

      await box.put(cacheKey, fetchedObjects);
      await box.put(avatarCacheKey, userAvatars);
      await box.put(wallpaperCacheKey, userWallpapers);
      await box.put(trumpetCacheKey, userTrumpets);
      await box.put(countCacheKey, fetchedObjects.length);
      await box.put(
          totalAvailableObjectsKey, totalAvailableObjectsResponse.count);
      await box.put(
          totalAvailableAvatarsKey, totalAvailableAvatarsResponse.count);
      await box.put(
          totalAvailableWallpapersKey, totalAvailableWallpapersResponse.count);
      await box.put(
          totalAvailableTrumpetsKey, totalAvailableTrumpetsResponse.count);
    } catch (e, stackTrace) {
      debugPrint('Error fetching objects: $e\nStack trace: $stackTrace');
      final cachedObjects = box.get(cacheKey, defaultValue: []);
      final cachedAvatars = box.get(avatarCacheKey, defaultValue: []);
      final cachedWallpapers = box.get(wallpaperCacheKey, defaultValue: []);
      final cachedTrumpets = box.get(trumpetCacheKey, defaultValue: []);
      setState(() {
        userObjects = List<Map<String, dynamic>>.from(
          cachedObjects.map((item) => Map<String, dynamic>.from(item)),
        );
        userAvatars = List<Map<String, dynamic>>.from(
          cachedAvatars.map((item) => Map<String, dynamic>.from(item)),
        );
        userWallpapers = List<Map<String, dynamic>>.from(
          cachedWallpapers.map((item) => Map<String, dynamic>.from(item)),
        );
        userTrumpets = List<Map<String, dynamic>>.from(
          cachedTrumpets.map((item) => Map<String, dynamic>.from(item)),
        );
        totalObjects =
            box.get(countCacheKey, defaultValue: cachedObjects.length);
        totalAvatars =
            box.get(avatarCacheKey, defaultValue: cachedAvatars.length);
        totalWallpapers =
            box.get(wallpaperCacheKey, defaultValue: cachedWallpapers.length);
        totalTrumpets =
            box.get(trumpetCacheKey, defaultValue: cachedTrumpets.length);
        totalAvailableObjects = box.get(totalAvailableObjectsKey,
            defaultValue: cachedObjects.length);
        totalAvailableAvatars = box.get(totalAvailableAvatarsKey,
            defaultValue: cachedAvatars.length);
        totalAvailableWallpapers = box.get(totalAvailableWallpapersKey,
            defaultValue: cachedWallpapers.length);
        totalAvailableTrumpets = box.get(totalAvailableTrumpetsKey,
            defaultValue: cachedTrumpets.length);
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

  Future<void> _useObject(Map<String, dynamic> item, String category) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final pendingBox = Hive.box('pending_actions');
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final imageUrl = item['local_image_path'] ??
        item['image_url'] ??
        'assets/images/refmmp.png';

    try {
      if (category == 'fondos') {
        final localPath = item['local_image_path'] != null &&
                File(item['local_image_path']).existsSync()
            ? item['local_image_path']
            : await _downloadAndCacheImage(
                item['image_url'], 'wallpaper_$userId');
        if (!_isOnline) {
          await pendingBox.add({
            'user_id': userId,
            'action': 'use_wallpaper',
            'image_url': item['image_url'],
            'objet_id': item['id'],
            'timestamp': DateTime.now().toIso8601String(),
          });
          await box.put('user_wallpaper_$userId', localPath);
          setState(() {
            wallpaperUrl = localPath;
          });
          profileImageProvider.updateWallpaper(localPath,
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
              .update({'wallpapers': item['image_url']}).eq('user_id', userId);
          await box.put('user_wallpaper_$userId', localPath);
          setState(() {
            wallpaperUrl = localPath;
          });
          profileImageProvider.updateWallpaper(localPath,
              notify: true, isOnline: true);
          await _loadImageHeight();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fondo de pantalla actualizado con éxito')),
          );
        }
      } else if (category == 'avatares') {
        final table = await _getUserTable();
        if (table == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: No se encontró la tabla del usuario')),
          );
          return;
        }
        final localPath = item['local_image_path'] != null &&
                File(item['local_image_path']).existsSync()
            ? item['local_image_path']
            : await _downloadAndCacheImage(
                item['image_url'], 'objet_${item['id']}');
        if (!_isOnline) {
          await pendingBox.add({
            'user_id': userId,
            'action': 'use_avatar',
            'image_url': item['image_url'],
            'objet_id': item['id'],
            'table': table,
            'timestamp': DateTime.now().toIso8601String(),
          });
          await box.put('user_profile_image_$userId', localPath);
          setState(() {
            profileImageUrl = localPath;
          });
          profileImageProvider.updateProfileImage(localPath,
              notify: true, isOnline: false, userTable: table);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Foto de perfil actualizada offline, se sincronizará cuando estés en línea')),
          );
        } else {
          await supabase.from(table).update(
              {'profile_image': item['image_url']}).eq('user_id', userId);
          await box.put('user_profile_image_$userId', localPath);
          await box.put('user_table_$userId', table);
          setState(() {
            profileImageUrl = localPath;
          });
          profileImageProvider.updateProfileImage(localPath,
              notify: true, isOnline: true, userTable: table);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Foto de perfil actualizada con éxito')),
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

  void filterItems(String query) {
    setState(() {
      List<Map<String, dynamic>> sourceItems;
      switch (_selectedIndex) {
        case 0:
          sourceItems = userAchievements;
          break;
        case 1:
          sourceItems = userFavoriteSongs;
          break;
        case 2:
          sourceItems = userObjects;
          break;
        case 3:
          sourceItems = userAvatars;
          break;
        case 4:
          sourceItems = userWallpapers;
          break;
        case 5:
          sourceItems = userTrumpets;
          break;
        default:
          sourceItems = [];
      }
      if (query.isEmpty) {
        filteredItems = List.from(sourceItems);
      } else {
        filteredItems = sourceItems.where((item) {
          final name = (item['name'] as String?)?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase());
        }).toList();
      }
      applySort(selectedSortOption);
    });
  }

  void applySort(String? sortOption) {
    setState(() {
      selectedSortOption = sortOption;
      if (sortOption == null) return;

      switch (sortOption) {
        case 'Nombre Ascendente':
          filteredItems
              .sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
          break;
        case 'Nombre Descendente':
          filteredItems
              .sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
          break;
        case 'Más Reciente':
          filteredItems.sort((a, b) {
            final aDate = a['created_at'] != null
                ? DateTime.tryParse(a['created_at'])
                : null;
            final bDate = b['created_at'] != null
                ? DateTime.tryParse(b['created_at'])
                : null;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.compareTo(aDate);
          });
          break;
        case 'Más Antiguo':
          filteredItems.sort((a, b) {
            final aDate = a['created_at'] != null
                ? DateTime.tryParse(a['created_at'])
                : null;
            final bDate = b['created_at'] != null
                ? DateTime.tryParse(b['created_at'])
                : null;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
          break;
      }
    });
  }

  void showFilterDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color.fromARGB(31, 31, 28, 28).withOpacity(0.9)
        : Colors.white.withOpacity(0.9);
    final textColor = isDarkMode ? Colors.white : Colors.blue;
    final iconColor = textColor;

    String? tempSortOption = selectedSortOption;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.all(16.0),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filtros',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Ordenar por',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: Icon(Icons.sort, color: iconColor),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: textColor)),
                  ),
                  dropdownColor: backgroundColor,
                  value: tempSortOption,
                  iconEnabledColor: iconColor,
                  items: [
                    'Nombre Ascendente',
                    'Nombre Descendente',
                    'Más Reciente',
                    'Más Antiguo'
                  ]
                      .map((option) => DropdownMenuItem(
                          value: option,
                          child:
                              Text(option, style: TextStyle(color: textColor))))
                      .toList(),
                  onChanged: (value) {
                    tempSortOption = value;
                  },
                  isExpanded: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                applySort(tempSortOption);
                Navigator.pop(context);
              },
              child: Text('Aplicar', style: TextStyle(color: textColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageWidget(String category, String imagePath, bool isObtained,
      String visibilityKey) {
    final isVisible = _gifVisibility[visibilityKey] ?? false;

    Widget imageWidget;
    if (category == 'trompetas') {
      imageWidget = Padding(
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
              if (isObtained && category != 'songs')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20),
                ),
              if (category == 'songs')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(Icons.favorite, color: Colors.red, size: 20),
                ),
            ],
          ),
        ),
      );
    } else if (category == 'avatares') {
      imageWidget = Padding(
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
              child: _buildImageContent(imagePath, isVisible, category),
            ),
          ),
        ),
      );
    } else {
      imageWidget = Container(
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
            if (isObtained && category != 'songs')
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20),
              ),
            if (category == 'songs')
              Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.favorite, color: Colors.red, size: 20),
              ),
          ],
        ),
      );
    }
    return imageWidget;
  }

  Widget _buildImageContent(String imagePath, bool isVisible, String category) {
    if (!isVisible || imagePath.isEmpty) {
      return Image.asset('assets/images/refmmp.png', fit: BoxFit.cover);
    }

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _searchController.clear();
      updateFilteredItems();
    });
  }

  void _navigateToCategoryPage(int index) {
    switch (index) {
      case 1: // Canciones
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MusicPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 2: // Objetos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ObjetsPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 3: // Avatares
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ObjetsDetailsPage(
              title: 'Avatares',
              instrumentName: widget.instrumentName,
            ),
          ),
        );
        break;
      case 4: // Fondos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ObjetsDetailsPage(
              title: 'Fondos',
              instrumentName: widget.instrumentName,
            ),
          ),
        );
        break;
      case 5: // Trompetas
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ObjetsDetailsPage(
              title: 'Trompetas',
              instrumentName: widget.instrumentName,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');
    final userId = supabase.auth.currentUser?.id;
    final box = Hive.box('offline_data');
    final obtainedCount = filteredItems.length;
    final totalCount = _selectedIndex == 0
        ? totalAvailableAchievements
        : _selectedIndex == 1
            ? totalAvailableSongs
            : _selectedIndex == 2
                ? totalAvailableObjects
                : _selectedIndex == 3
                    ? totalAvailableAvatars
                    : _selectedIndex == 4
                        ? totalAvailableWallpapers
                        : totalAvailableTrumpets;
    final progress = totalCount > 0 ? obtainedCount / totalCount : 0.0;

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: _initializeData,
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollUpdateNotification) {
              final offset = scrollNotification.metrics.pixels;
              final isNowCollapsed =
                  offset >= (expandedHeight ?? 200.0) - kToolbarHeight;
              if (isNowCollapsed != isCollapsed) {
                setState(() {
                  isCollapsed = isNowCollapsed;
                });
              }
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
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                          color: Colors.black,
                          offset: Offset(2, 1),
                          blurRadius: 8)
                    ],
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: isSearching
                    ? Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            if (!isCollapsed && profileImageUrl != null)
                              CircleAvatar(
                                radius: 15.0,
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
                            SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 4)
                                  ],
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Buscar...',
                                  hintStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black,
                                          offset: Offset(1, 1),
                                          blurRadius: 4)
                                    ],
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (isCollapsed && !isSearching && profileImageUrl != null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 15.0,
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
                                    categories[_selectedIndex]['label']
                                        .toUpperCase(),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null),
                actions: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(isSearching ? Icons.close : Icons.search,
                          color: Colors.white),
                      onPressed: () {
                        setState(() {
                          isSearching = !isSearching;
                          if (!isSearching) {
                            _searchController.clear();
                            updateFilteredItems();
                          }
                        });
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.filter_list, color: Colors.white),
                      onPressed: showFilterDialog,
                    ),
                  ),
                ],
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
                                return Image.asset('assets/images/refmmp.png',
                                    fit: BoxFit.cover);
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
                                          color: Colors.white)),
                                  errorWidget: (context, url, error) {
                                    debugPrint(
                                        'Error loading network wallpaper: $error, url: $url');
                                    return Image.asset(
                                        'assets/images/refmmp.png',
                                        fit: BoxFit.cover);
                                  },
                                )
                              : Image.asset('assets/images/refmmp.png',
                                  fit: BoxFit.cover),
                      if (!isCollapsed &&
                          !isSearching &&
                          profileImageUrl != null)
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: List.generate(categories.length, (index) {
                      final isSelected = _selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () => _onItemTapped(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.blue,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? categories[index]['selectedIcon']
                                      : categories[index]['icon'],
                                  color:
                                      isSelected ? Colors.white : Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  categories[index]['label'],
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.white : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        categories[_selectedIndex]['label'].toUpperCase(),
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Mis monedas',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Image.asset('assets/images/coin.png',
                              width: 24, height: 24, fit: BoxFit.contain),
                          const SizedBox(width: 4),
                          Text(
                            numberFormat.format(totalCoins),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tienes $obtainedCount/$totalCount elementos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: _selectedIndex == 0
                                ? null // No navigation for Logros
                                : () => _navigateToCategoryPage(_selectedIndex),
                            child: Text(
                              'MÁS ${categories[_selectedIndex]['label'].toUpperCase()}',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _selectedIndex == 0
                        ? 0.5
                        : _selectedIndex == 1
                            ? 0.6
                            : _selectedIndex == 3
                                ? 0.5
                                : _selectedIndex == 4
                                    ? 0.7
                                    : 0.6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      final category = _selectedIndex == 0
                          ? 'achievements'
                          : _selectedIndex == 1
                              ? 'songs'
                              : _selectedIndex == 2
                                  ? 'otros'
                                  : _selectedIndex == 3
                                      ? 'avatares'
                                      : _selectedIndex == 4
                                          ? 'fondos'
                                          : 'trompetas';
                      final visibilityKey =
                          category == 'achievements' || category == 'songs'
                              ? '${category}_${item['id']}'
                              : '${item['id']}';

                      return VisibilityDetector(
                        key: Key(visibilityKey),
                        onVisibilityChanged: (visibilityInfo) {
                          final visiblePercentage =
                              visibilityInfo.visibleFraction * 100;
                          if (mounted) {
                            setState(() {
                              _gifVisibility[visibilityKey] =
                                  visiblePercentage > 10;
                            });
                          }
                        },
                        child: GestureDetector(
                          onTap: () {
                            if (category == 'achievements') {
                              showAchievementDialog(context, item);
                            } else if (category == 'songs') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PlayPage(songName: item['name']),
                                ),
                              );
                            } else {
                              showObjectDialog(
                                  context,
                                  item,
                                  category,
                                  totalCoins,
                                  _useObject,
                                  (Map<String, dynamic> _) async {});
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: category == 'songs'
                                  ? Colors.transparent
                                  : (themeProvider.isDarkMode
                                      ? Colors.grey[900]
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: category == 'fondos' ? 60 : 100,
                                  width: category == 'fondos' ? 80 : 100,
                                  child: _buildImageWidget(
                                    category,
                                    item['local_image_path'] ??
                                        (category == 'achievements' ||
                                                category == 'songs'
                                            ? item['image']
                                            : item['image_url']) ??
                                        'assets/images/refmmp.png',
                                    true,
                                    visibilityKey,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: 30),
                                    child: Text(
                                      item['name'] ??
                                          (category == 'achievements'
                                              ? 'Logro'
                                              : category == 'songs'
                                                  ? 'Canción'
                                                  : 'Objeto'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.blue,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (category == 'songs') ...[
                                        Icon(Icons.favorite,
                                            color: Colors.red, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Me gusta',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(Icons.check_circle,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Obtenido',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
