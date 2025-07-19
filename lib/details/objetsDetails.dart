// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:ui' as ui;

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
    ),
  );
}

class ObjetsDetailsPage extends StatefulWidget {
  final String title;
  final String instrumentName;
  const ObjetsDetailsPage(
      {Key? key, required this.title, required this.instrumentName})
      : super(key: key);

  @override
  _ObjetsDetailsPageState createState() => _ObjetsDetailsPageState();
}

class _ObjetsDetailsPageState extends State<ObjetsDetailsPage> {
  final supabase = Supabase.instance.client;
  int totalCoins = 0;
  List<dynamic> userObjets = [];
  String? wallpaperUrl;
  String? profileImageUrl;
  bool isSearching = false;
  bool isCollapsed = false;
  bool _isOnline = false;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  String? selectedSortOption;
  double? expandedHeight;
  final Map<String, bool> _gifVisibility = {};

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus();
    fetchTotalCoins();
    fetchUserObjets();
    fetchWallpaper();
    fetchProfileImage();
    fetchObjets();
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
        await _syncPendingActions();
        await fetchObjets();
        await fetchUserObjets();
        await fetchTotalCoins();
        await fetchProfileImage();
        await fetchWallpaper();
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

  Future<void> fetchObjets() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'objets_${widget.title}';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    try {
      if (!_isOnline) {
        final cachedItems = box.get(cacheKey, defaultValue: []);
        if (cachedItems.isNotEmpty) {
          setState(() {
            allItems = List<Map<String, dynamic>>.from(
                cachedItems.map((item) => Map<String, dynamic>.from(item)));
            filteredItems = List.from(allItems);
          });
          final profileImageCacheKey = 'user_profile_image_$userId';
          final cachedProfileImage = box.get(profileImageCacheKey,
              defaultValue: profileImageProvider.profileImageUrl);
          if (cachedProfileImage != null &&
              cachedProfileImage.isNotEmpty &&
              !cachedProfileImage.startsWith('http') &&
              File(cachedProfileImage).existsSync()) {
            profileImageProvider.updateProfileImage(cachedProfileImage,
                notify: true, isOnline: false);
            setState(() {
              profileImageUrl = cachedProfileImage;
            });
          }
        }
        return;
      }

      final response = await supabase
          .from('objets')
          .select()
          .eq('category', widget.title)
          .order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(response);

      for (var item in data) {
        final imageUrl = item['image_url'] ?? '';
        if (imageUrl.isNotEmpty && imageUrl != 'assets/images/refmmp.png') {
          try {
            final localPath =
                await _downloadAndCacheImage(imageUrl, 'objet_${item['id']}');
            item['local_image_path'] = localPath;
            if (widget.title.toLowerCase() == 'avatares') {
              _gifVisibility['${item['id']}'] = true;
            }
          } catch (e) {
            debugPrint('Error caching object image for ${item['id']}: $e');
          }
        }
      }

      setState(() {
        allItems = data;
        filteredItems = List.from(allItems);
      });
      await box.put(cacheKey, data);
    } catch (e) {
      debugPrint('Error al obtener objetos: $e');
      final cachedItems = box.get(cacheKey, defaultValue: []);
      if (cachedItems.isNotEmpty) {
        setState(() {
          allItems = List<Map<String, dynamic>>.from(
              cachedItems.map((item) => Map<String, dynamic>.from(item)));
          filteredItems = List.from(allItems);
        });
      }
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

  Future<void> fetchUserObjets() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objets_$userId';

    try {
      if (!_isOnline) {
        final cachedObjets = box.get(cacheKey, defaultValue: userObjets);
        setState(() {
          userObjets = List<dynamic>.from(cachedObjets);
        });
        return;
      }

      final response = await supabase
          .from('users_objets')
          .select('objet_id')
          .eq('user_id', userId);
      final objets = response.map((item) => item['objet_id']).toList();
      setState(() {
        userObjets = objets;
      });
      await box.put(cacheKey, objets);
    } catch (e) {
      debugPrint('Error al obtener objetos del usuario: $e');
      final cachedObjets = box.get(cacheKey, defaultValue: userObjets);
      setState(() {
        userObjets = List<dynamic>.from(cachedObjets);
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
                });
                await supabase
                    .from('users_games')
                    .update({'coins': newCoins}).eq('user_id', userId);
              }
              final box = Hive.box('offline_data');
              await box.put('user_coins_$userId', newCoins);
              final cachedObjets =
                  box.get('user_objets_$userId', defaultValue: []);
              cachedObjets.add(action['objet_id']);
              await box.put('user_objets_$userId', cachedObjets);
              if (mounted) {
                setState(() {
                  totalCoins = newCoins;
                  userObjets.add(action['objet_id']);
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
              if (mounted) {
                final profileImageProvider =
                    Provider.of<ProfileImageProvider>(context, listen: false);
                profileImageProvider.updateWallpaper(localPath,
                    notify: true, isOnline: _isOnline);
                setState(() {
                  wallpaperUrl = localPath;
                });
                await _loadImageHeight();
              }
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
              if (mounted) {
                final profileImageProvider =
                    Provider.of<ProfileImageProvider>(context, listen: false);
                profileImageProvider.updateProfileImage(localPath,
                    notify: true, isOnline: _isOnline, userTable: table);
                setState(() {
                  profileImageUrl = localPath;
                });
              }
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
        final cachedObjets = box.get('user_objets_$userId', defaultValue: []);
        cachedObjets.add(item['id']);
        await box.put('user_objets_$userId', cachedObjets);
        setState(() {
          totalCoins = newCoins;
          userObjets.add(item['id']);
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
      });
      await supabase
          .from('users_games')
          .update({'coins': newCoins}).eq('user_id', userId);
      await box.put('user_coins_$userId', newCoins);
      final cachedObjets = box.get('user_objets_$userId', defaultValue: []);
      cachedObjets.add(item['id']);
      await box.put('user_objets_$userId', cachedObjets);
      setState(() {
        totalCoins = newCoins;
        userObjets.add(item['id']);
        allItems = List.from(allItems); // Ensure allItems is updated
        filteredItems = List.from(allItems); // Reset filteredItems
      });
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
      if (query.isEmpty) {
        filteredItems = List.from(allItems);
      } else {
        filteredItems = allItems.where((item) {
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
        case 'Más Costoso':
          filteredItems
              .sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
          break;
        case 'Menos Costoso':
          filteredItems
              .sort((a, b) => (a['price'] ?? 0).compareTo(a['price'] ?? 0));
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Ordenar por',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: Icon(Icons.sort, color: iconColor),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: textColor),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: textColor),
                    ),
                  ),
                  dropdownColor: backgroundColor,
                  value: tempSortOption,
                  iconEnabledColor: iconColor,
                  items: [
                    'Nombre Ascendente',
                    'Nombre Descendente',
                    'Más Reciente',
                    'Más Antiguo',
                    'Más Costoso',
                    'Menos Costoso'
                  ]
                      .map((option) => DropdownMenuItem(
                            value: option,
                            child: Text(option,
                                style: TextStyle(color: textColor)),
                          ))
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

  void _showObjectDialog(
      BuildContext context, Map<String, dynamic> item, String category) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final numberFormat = NumberFormat('#,##0', 'es_ES');
    final isObtained = userObjets.contains(item['id']);
    final price = (item['price'] ?? 0) as int;
    final imagePath = item['local_image_path'] ??
        item['image_url'] ??
        'assets/images/refmmp.png';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Mis monedas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/images/coin.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      numberFormat.format(totalCoins),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: category == 'avatares' ? 150 : double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(category == 'avatares' ? 75 : 8),
                    border: Border.all(
                      color: isObtained ? Colors.green : Colors.blue,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(category == 'avatares' ? 75 : 8),
                    child: imagePath.isNotEmpty &&
                            !imagePath.startsWith('http') &&
                            File(imagePath).existsSync()
                        ? Image.file(
                            File(imagePath),
                            fit: category == 'trompetas'
                                ? BoxFit.contain
                                : BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint(
                                  'Error loading local image: $error, path: $imagePath');
                              return Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : imagePath.isNotEmpty &&
                                Uri.tryParse(imagePath)?.isAbsolute == true
                            ? CachedNetworkImage(
                                imageUrl: imagePath,
                                cacheManager: CustomCacheManager.instance,
                                fit: category == 'trompetas'
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blue),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                      'Error loading network image: $error, url: $url');
                                  return Image.asset(
                                    'assets/images/refmmp.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                                memCacheWidth: 200,
                                memCacheHeight: 200,
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                              )
                            : Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                              ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  item['description'] ?? 'Sin descripción',
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[300]
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (isObtained) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await _useObject(item, category);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Usar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/coin.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        numberFormat.format(price),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          totalCoins >= price ? Colors.green : Colors.grey,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (totalCoins < price) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            contentPadding: EdgeInsets.all(16),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  color: Colors.red,
                                  size: MediaQuery.of(context).size.width * 0.3,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Monedas insuficientes',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No tienes suficientes monedas. Tus monedas son de: ($totalCoins) y son menores que el precio del objeto que es: ($price) monedas.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Center(
                              child: Text(
                                'Confirmar compra',
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            content: Text(
                              '¿Estás seguro de comprar ${item['name']} por ${numberFormat.format(price)} monedas?',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  'Sí',
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _purchaseObject(item);
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              contentPadding: EdgeInsets.all(16),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size:
                                        MediaQuery.of(context).size.width * 0.3,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '¡Objeto obtenido!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Se ha obtenido ${item['name']} con éxito.',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    minimumSize: Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showObjectDialog(context, item, category);
                                  },
                                  child: Text(
                                    'OK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      'Comprar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: Size(double.infinity, 48),
                    side: BorderSide(color: Colors.red, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cerrar',
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');
    final obtainedCount = userObjets
        .where((id) => filteredItems.any((item) => item['id'] == id))
        .length;
    final totalCount = filteredItems.length;
    final progress = totalCount > 0 ? obtainedCount / totalCount : 0.0;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ObjetsPage(instrumentName: widget.instrumentName),
          ),
        );
        return false;
      },
      child: Scaffold(
        body: RefreshIndicator(
          color: Colors.blue,
          onRefresh: () async {
            await _checkConnectivityStatus();
            if (_isOnline) {
              await fetchObjets();
              await fetchTotalCoins();
              await fetchUserObjets();
              await fetchWallpaper();
              await fetchProfileImage();
              await _syncPendingActions();
            } else {
              final box = Hive.box('offline_data');
              final userId = supabase.auth.currentUser?.id;
              if (userId != null) {
                final cachedItems =
                    box.get('objets_${widget.title}', defaultValue: []);
                if (cachedItems.isNotEmpty) {
                  setState(() {
                    allItems = List<Map<String, dynamic>>.from(cachedItems
                        .map((item) => Map<String, dynamic>.from(item)));
                    filteredItems = List.from(allItems);
                  });
                }
                setState(() {
                  totalCoins =
                      box.get('user_coins_$userId', defaultValue: totalCoins);
                  userObjets = List<dynamic>.from(
                      box.get('user_objets_$userId', defaultValue: userObjets));
                  wallpaperUrl = box.get('user_wallpaper_$userId',
                      defaultValue: wallpaperUrl ?? 'assets/images/refmmp.png');
                  profileImageUrl = box.get('user_profile_image_$userId',
                      defaultValue:
                          profileImageUrl ?? 'assets/images/refmmp.png');
                });
                await _loadImageHeight();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Estás offline, mostrando datos guardados')),
              );
            }
          },
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
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ObjetsPage(instrumentName: widget.instrumentName),
                        ),
                      );
                    },
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
                                              File(profileImageUrl!)
                                                  .existsSync()
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
                                          blurRadius: 4,
                                        ),
                                      ],
                                      fontWeight: FontWeight.bold),
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
                                          blurRadius: 4,
                                        ),
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
                                              File(profileImageUrl!)
                                                  .existsSync()
                                          ? FileImage(File(profileImageUrl!))
                                          : NetworkImage(profileImageUrl!)),
                                  backgroundColor: Colors.transparent,
                                  onBackgroundImageError: (_, __) =>
                                      AssetImage('assets/images/refmmp.png'),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      widget.title.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
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
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          isSearching ? Icons.close : Icons.search,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            isSearching = !isSearching;
                            if (!isSearching) {
                              _searchController.clear();
                              filteredItems = List.from(allItems);
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
                            offset: Offset(0, 2),
                          ),
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
                                              File(profileImageUrl!)
                                                  .existsSync()
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
                        Text(
                          widget.title.toUpperCase(),
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
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/images/coin.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
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
                          'Tienes $obtainedCount/$totalCount objetos',
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
                      childAspectRatio:
                          widget.title.toLowerCase() == 'avatares' ? 0.7 : 0.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredItems[index];
                        final category = widget.title.toLowerCase();
                        final isObtained = userObjets.contains(item['id']);
                        final imagePath = item['local_image_path'] ??
                            item['image_url'] ??
                            'assets/images/refmmp.png';
                        final visibilityKey = '${item['id']}';

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
                            onTap: () =>
                                _showObjectDialog(context, item, category),
                            child: Container(
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[900]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isObtained ? Colors.green : Colors.blue,
                                  width: 2,
                                ),
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
                                children: [
                                  Expanded(
                                    child: _buildImageWidget(category,
                                        imagePath, isObtained, visibilityKey),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(
                                      item['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.blue[800],
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (isObtained) ...[
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Obtenido',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ] else ...[
                                          Image.asset(
                                            'assets/images/coin.png',
                                            width: 16,
                                            height: 16,
                                            fit: BoxFit.contain,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            numberFormat
                                                .format(item['price'] ?? 0),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[800],
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
      ),
    );
  }

  Widget _buildImageWidget(String category, String imagePath, bool isObtained,
      String visibilityKey) {
    final isVisible = _gifVisibility[visibilityKey] ?? false;
    Widget imageWidget;

    if (category == 'avatares') {
      imageWidget = Container(
        margin: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          radius: 40, // Ajusta el tamaño del círculo
          backgroundColor: Colors.transparent,
          child: ClipOval(
            child: isVisible
                ? (imagePath.isNotEmpty &&
                        !imagePath.startsWith('http') &&
                        File(imagePath).existsSync()
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                              'Error loading local image: $error, path: $imagePath');
                          return Image.asset(
                            'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          );
                        },
                      )
                    : imagePath.isNotEmpty &&
                            Uri.tryParse(imagePath)?.isAbsolute == true
                        ? CachedNetworkImage(
                            imageUrl: imagePath,
                            cacheManager: CustomCacheManager.instance,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            placeholder: (context, url) => const Center(
                              child:
                                  CircularProgressIndicator(color: Colors.blue),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint(
                                  'Error loading network image: $error, url: $url');
                              return Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                              );
                            },
                          )
                        : Image.asset(
                            'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          ))
                : Image.asset(
                    'assets/images/refmmp.png',
                    fit: BoxFit.cover,
                    width: 80,
                    height: 80,
                  ),
          ),
          foregroundColor: isObtained ? Colors.green : Colors.blue,
          foregroundImage: null, // Usamos ClipOval para manejar la imagen
        ),
      );
    } else {
      imageWidget = Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVisible
                  ? (imagePath.isNotEmpty &&
                          !imagePath.startsWith('http') &&
                          File(imagePath).existsSync()
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                            'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : imagePath.isNotEmpty &&
                              Uri.tryParse(imagePath)?.isAbsolute == true
                          ? CachedNetworkImage(
                              imageUrl: imagePath,
                              cacheManager: CustomCacheManager.instance,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.blue),
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                            ))
                  : Image.asset(
                      'assets/images/refmmp.png',
                      fit: BoxFit.cover,
                    ),
            ),
            if (isObtained)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return imageWidget;
  }
}
