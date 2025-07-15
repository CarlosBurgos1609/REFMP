import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
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

class ObjetsPage extends StatefulWidget {
  final String instrumentName;
  const ObjetsPage({Key? key, required this.instrumentName}) : super(key: key);

  @override
  _ObjetsPageState createState() => _ObjetsPageState();
}

class _ObjetsPageState extends State<ObjetsPage> {
  final supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> groupedObjets = {};
  Map<String, int> categoryCounts = {};
  int totalCoins = 0;
  List<dynamic> userObjets = [];
  bool _isOnline = false;
  int _selectedIndex = 3;
  double? expandedHeight;

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _checkConnectivityStatus();
    _initializeUserData();
    fetchObjets();
    fetchUserObjets();
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
        await fetchUserProfileImage();
        await fetchWallpaper();
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
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final wallpaperUrl = profileImageProvider.wallpaperUrl;

    debugPrint('Loading image height for wallpaper: $wallpaperUrl');
    if (wallpaperUrl == null || wallpaperUrl.isEmpty) {
      debugPrint('No valid wallpaper URL, setting default height');
      setState(() {
        expandedHeight = 400.0;
      });
      return;
    }

    try {
      late ImageProvider imageProvider;
      if (wallpaperUrl.startsWith('assets/')) {
        debugPrint('Using asset wallpaper: $wallpaperUrl');
        imageProvider = AssetImage(wallpaperUrl);
      } else if (!wallpaperUrl.startsWith('http') &&
          File(wallpaperUrl).existsSync()) {
        debugPrint('Using local wallpaper: $wallpaperUrl');
        imageProvider = FileImage(File(wallpaperUrl));
      } else if (Uri.tryParse(wallpaperUrl)?.isAbsolute == true) {
        debugPrint('Using network wallpaper: $wallpaperUrl');
        imageProvider = NetworkImage(wallpaperUrl);
      } else {
        debugPrint('Invalid wallpaper URL, using default');
        imageProvider = const AssetImage('assets/images/refmmp.png');
      }

      final image = await _loadImage(imageProvider);
      final screenWidth = MediaQuery.of(context).size.width;
      final aspectRatio = image.width / image.height;
      setState(() {
        expandedHeight = screenWidth / aspectRatio;
        debugPrint('Set expandedHeight to $expandedHeight');
      });
    } catch (e) {
      debugPrint('Error loading image height: $e');
      setState(() {
        expandedHeight = 400.0;
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
        debugPrint('Error in _loadImage: $exception');
        completer.completeError(exception, stackTrace);
        imageStream.removeListener(listener!);
      },
    );
    imageStream.addListener(listener);
    return await completer.future;
  }

  Future<String> _downloadAndCacheImage(String url, String cacheKey) async {
    final box = Hive.box('offline_data');
    final cachedData = box.get(cacheKey);

    if (cachedData != null && cachedData is Map) {
      final cachedUrl = cachedData['url'] as String?;
      final cachedPath = cachedData['path'] as String?;
      if (cachedUrl == url &&
          cachedPath != null &&
          File(cachedPath).existsSync()) {
        debugPrint('Using cached image for $cacheKey: $cachedPath');
        return cachedPath;
      }
    }

    if (url.isEmpty || Uri.tryParse(url)?.isAbsolute != true) {
      debugPrint('Invalid URL: $url, returning default image');
      return 'assets/images/refmmp.png';
    }

    try {
      final fileInfo = await CustomCacheManager.instance.downloadFile(url);
      final filePath = fileInfo.file.path;
      await box.put(cacheKey, {'path': filePath, 'url': url});
      debugPrint('Image downloaded and cached for $cacheKey: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image for $cacheKey: $e');
      return 'assets/images/refmmp.png';
    }
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
          debugPrint('User initialized in users_games: $userId');
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
          totalCoins = box.get(cacheKey, defaultValue: 0);
        });
        debugPrint('Loaded coins offline: $totalCoins');
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
        debugPrint('Fetched coins online: $totalCoins');
      } else {
        setState(() {
          totalCoins = 0;
        });
        await box.put(cacheKey, 0);
        debugPrint('No coins found, set to 0');
      }
    } catch (e) {
      debugPrint('Error al obtener las monedas: $e');
      setState(() {
        totalCoins = box.get(cacheKey, defaultValue: 0);
      });
      debugPrint('Loaded cached coins due to error: $totalCoins');
    }
  }

  Future<void> fetchUserObjets() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_objets_$userId';

    try {
      if (!_isOnline) {
        final cachedObjets = box.get(cacheKey, defaultValue: []);
        setState(() {
          userObjets = List<dynamic>.from(cachedObjets);
        });
        debugPrint('Loaded user objets offline: $userObjets');
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
      debugPrint('Fetched user objets online: $objets');
    } catch (e) {
      debugPrint('Error al obtener objetos del usuario: $e');
      final cachedObjets = box.get(cacheKey, defaultValue: []);
      setState(() {
        userObjets = List<dynamic>.from(cachedObjets);
      });
      debugPrint('Loaded cached user objets due to error: $userObjets');
    }
  }

  Future<void> fetchUserProfileImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_profile_image_${user.id}';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    debugPrint('Fetching profile image for user: ${user.id}');
    try {
      if (!_isOnline) {
        final cachedProfileImage = box.get(cacheKey, defaultValue: null);
        final profileImagePath = (cachedProfileImage != null &&
                cachedProfileImage.isNotEmpty &&
                !cachedProfileImage.startsWith('http') &&
                File(cachedProfileImage).existsSync())
            ? cachedProfileImage
            : 'assets/images/refmmp.png';
        profileImageProvider.updateProfileImage(profileImagePath,
            notify: true, isOnline: false);
        debugPrint('Loaded cached profile image offline: $profileImagePath');
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
            final localPath = await _downloadAndCacheImage(
                imageUrl, 'profile_image_${user.id}');
            imageUrl = localPath;
          }
          break;
        }
      }
      imageUrl ??= 'assets/images/refmmp.png';
      profileImageProvider.updateProfileImage(imageUrl,
          notify: true, isOnline: true, userTable: userTable);
      await box.put(cacheKey, imageUrl);
      await box.put('user_table_${user.id}', userTable);
      debugPrint('Fetched profile image online: $imageUrl, table: $userTable');
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
      final cachedProfileImage =
          box.get(cacheKey, defaultValue: 'assets/images/refmmp.png');
      profileImageProvider.updateProfileImage(cachedProfileImage,
          notify: true, isOnline: false);
      debugPrint(
          'Loaded cached profile image due to error: $cachedProfileImage');
    }
  }

  Future<void> fetchWallpaper() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_wallpaper_$userId';
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);

    debugPrint('Fetching wallpaper for user: $userId');
    try {
      if (!_isOnline) {
        final cachedWallpaper = box.get(cacheKey, defaultValue: null);
        final wallpaperPath = (cachedWallpaper != null &&
                cachedWallpaper.isNotEmpty &&
                !cachedWallpaper.startsWith('http') &&
                File(cachedWallpaper).existsSync())
            ? cachedWallpaper
            : 'assets/images/refmmp.png';
        profileImageProvider.updateWallpaper(wallpaperPath,
            notify: true, isOnline: false);
        debugPrint('Loaded cached wallpaper offline: $wallpaperPath');
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
        final localPath =
            await _downloadAndCacheImage(imageUrl, 'wallpaper_$userId');
        imageUrl = localPath;
      }
      profileImageProvider.updateWallpaper(imageUrl!,
          notify: true, isOnline: true);
      await box.put(cacheKey, imageUrl);
      debugPrint('Fetched wallpaper online: $imageUrl');
      await _loadImageHeight();
    } catch (e) {
      debugPrint('Error al obtener el fondo de pantalla: $e');
      final cachedWallpaper =
          box.get(cacheKey, defaultValue: 'assets/images/refmmp.png');
      profileImageProvider.updateWallpaper(cachedWallpaper,
          notify: true, isOnline: false);
      debugPrint('Loaded cached wallpaper due to error: $cachedWallpaper');
      await _loadImageHeight();
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
              if (mounted) {
                setState(() {
                  totalCoins = newCoins;
                  userObjets.add(action['objet_id']);
                });
                debugPrint(
                    'Synced purchase: coins=$newCoins, objet_id=${action['objet_id']}');
              }
            } else {
              debugPrint('Insufficient coins for purchase: $newCoins');
              continue;
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
                await _loadImageHeight();
                debugPrint('Synced wallpaper: $localPath');
              }
            }
          } else if (actionType == 'use_avatar') {
            final table = action['table'] as String?;
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
              if (mounted) {
                final profileImageProvider =
                    Provider.of<ProfileImageProvider>(context, listen: false);
                profileImageProvider.updateProfileImage(localPath,
                    notify: true, isOnline: _isOnline, userTable: table);
                debugPrint('Synced avatar: $localPath, table: $table');
              }
            } else {
              debugPrint(
                  'Error: Missing table or image_url for use_avatar action');
              continue;
            }
          }
          final index = pendingBox.values.toList().indexOf(action);
          if (index != -1) {
            await pendingBox.deleteAt(index);
            debugPrint(
                'Deleted synced action: $actionType for object ${action['objet_id']}');
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

  Future<void> _useObject(Map<String, dynamic> item, String category) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user ID found, cannot use object');
      return;
    }

    // Ensure Hive boxes are open
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Opened offline_data box in _useObject');
    }
    if (!Hive.isBoxOpen('pending_actions')) {
      await Hive.openBox('pending_actions');
      debugPrint('Opened pending_actions box in _useObject');
    }

    final box = Hive.box('offline_data');
    final pendingBox = Hive.box('pending_actions');
    final profileImageProvider =
        Provider.of<ProfileImageProvider>(context, listen: false);
    final imageUrl = item['image_url'] ?? 'assets/images/refmmp.png';
    final cacheKey =
        category == 'fondos' ? 'wallpaper_$userId' : 'profile_image_$userId';
    String localPath = imageUrl;

    debugPrint(
        'Using object: ${item['name']}, category: $category, imageUrl: $imageUrl');
    if (imageUrl != 'assets/images/refmmp.png' &&
        Uri.tryParse(imageUrl)?.isAbsolute == true) {
      localPath = await _downloadAndCacheImage(imageUrl, cacheKey);
    }

    try {
      if (category == 'fondos') {
        if (!_isOnline) {
          await pendingBox.add({
            'user_id': userId,
            'action': 'use_wallpaper',
            'image_url': imageUrl,
            'objet_id': item['id'],
            'timestamp': DateTime.now().toIso8601String(),
          });
          await box.put('user_wallpaper_$userId', localPath);
          profileImageProvider.updateWallpaper(localPath,
              notify: true, isOnline: false);
          await _loadImageHeight();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Fondo de pantalla actualizado offline, se sincronizará cuando estés en línea')),
            );
          });
          debugPrint('Updated wallpaper offline: $localPath');
        } else {
          await supabase
              .from('users_games')
              .update({'wallpapers': imageUrl}).eq('user_id', userId);
          await box.put('user_wallpaper_$userId', localPath);
          profileImageProvider.updateWallpaper(localPath,
              notify: true, isOnline: true);
          await _loadImageHeight();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Fondo de pantalla actualizado con éxito')),
            );
          });
          debugPrint('Updated wallpaper online: $localPath');
        }
      } else if (category == 'avatares') {
        String? table;
        if (_isOnline) {
          // Buscar la tabla del usuario en Supabase
          List<String> tables = [
            'users',
            'students',
            'graduates',
            'teachers',
            'advisors',
            'parents',
            'directors'
          ];
          for (String t in tables) {
            final response = await supabase
                .from(t)
                .select('user_id')
                .eq('user_id', userId)
                .maybeSingle();
            if (response != null) {
              table = t;
              await box.put('user_table_$userId', table);
              debugPrint('Found user table online: $table');
              break;
            }
          }
        } else {
          // Usar la tabla almacenada en caché
          table = box.get('user_table_$userId', defaultValue: null);
          debugPrint('Loaded user table offline: $table');
        }

        if (table == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error: No se encontró la tabla del usuario')),
            );
          });
          debugPrint('Error: No user table found for avatar update');
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
          await box.put('user_profile_image_$userId', localPath);
          profileImageProvider.updateProfileImage(localPath,
              notify: true, isOnline: false, userTable: table);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Foto de perfil actualizada offline, se sincronizará cuando estés en línea')),
            );
            debugPrint(
                'Updated profile image offline: $localPath, notifying listeners');
          });
        } else {
          try {
            await supabase
                .from(table)
                .update({'profile_image': imageUrl}).eq('user_id', userId);
            await box.put('user_profile_image_$userId', localPath);
            await box.put(
                'user_table_$userId', table); // Guardar tabla en caché
            profileImageProvider.updateProfileImage(localPath,
                notify: true, isOnline: true, userTable: table);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Foto de perfil actualizada con éxito')),
              );
              debugPrint(
                  'Updated profile image online: $localPath, table: $table');
            });
          } catch (e) {
            debugPrint('Error updating profile image in Supabase: $e');
            await box.put('user_profile_image_$userId', localPath);
            await box.put(
                'user_table_$userId', table); // Guardar tabla en caché
            profileImageProvider.updateProfileImage(localPath,
                notify: true, isOnline: false, userTable: table);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Error al actualizar la foto de perfil en línea')),
              );
            });
          }
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Objeto ${item['name']} usado${_isOnline ? '' : ' offline'}')),
          );
        });
        debugPrint(
            'Used object: ${item['name']} ${_isOnline ? 'online' : 'offline'}');
      }
    } catch (e) {
      debugPrint('Error al usar objeto: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al usar el objeto: $e')),
        );
      });
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: No tienes suficientes monedas')),
        );
      });
      debugPrint('Insufficient coins: $totalCoins < $price');
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Compra guardada para sincronizar cuando estés en línea')),
          );
        });
        debugPrint(
            'Purchase saved offline: objet_id=${item['id']}, newCoins=$newCoins');
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
      });
      debugPrint(
          'Purchase completed online: objet_id=${item['id']}, newCoins=$newCoins');
    } catch (e) {
      debugPrint('Error al comprar objeto: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al comprar el objeto: $e')),
        );
      });
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

  Future<bool> _canAddEvent() async {
    if (!_isOnline) {
      debugPrint('Sin conexión, no se muestra el botón.');
      return false;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No hay usuario autenticado.');
      return false;
    }

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final userExists = response != null;
      debugPrint('Usuario existe en tabla users: $userExists');
      return userExists;
    } catch (e) {
      debugPrint('Error al verificar usuario en users: $e');
      return false;
    }
  }

  Future<void> fetchObjets() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'objets_${widget.instrumentName}';
    final countCacheKey = 'category_counts_${widget.instrumentName}';

    try {
      if (!_isOnline) {
        final cachedObjets = box.get(cacheKey, defaultValue: {});
        final cachedCounts = box.get(countCacheKey, defaultValue: {});
        setState(() {
          groupedObjets = Map<String, List<Map<String, dynamic>>>.from(
              cachedObjets.map((key, value) => MapEntry(
                  key,
                  List<Map<String, dynamic>>.from(
                      value.map((item) => Map<String, dynamic>.from(item))))));
          categoryCounts = Map<String, int>.from(cachedCounts);
        });
        debugPrint('Loaded objets offline: $groupedObjets');
        return;
      }

      final allObjetsResponse = await supabase.from('objets').select();
      final allObjets = List<Map<String, dynamic>>.from(allObjetsResponse);
      final categories =
          allObjets.map((item) => item['category'] as String).toSet().toList();
      Map<String, List<Map<String, dynamic>>> grouped = {};
      Map<String, int> counts = {};

      for (var category in categories) {
        final countResponse =
            await supabase.from('objets').select().eq('category', category);
        counts[category] = countResponse.length;

        final response = await supabase
            .from('objets')
            .select()
            .eq('category', category)
            .order('created_at', ascending: false)
            .limit(6);
        final data = List<Map<String, dynamic>>.from(response);

        for (var item in data) {
          final imageUrl = item['image_url'] ?? '';
          if (imageUrl.isNotEmpty && imageUrl != 'assets/images/refmmp.png') {
            try {
              final localPath =
                  await _downloadAndCacheImage(imageUrl, 'objet_${item['id']}');
              item['local_image_path'] = localPath;
            } catch (e) {
              debugPrint('Error caching object image for ${item['id']}: $e');
            }
          }
        }
        grouped[category] = data;
      }

      setState(() {
        groupedObjets = grouped;
        categoryCounts = counts;
      });
      await box.put(cacheKey, grouped);
      await box.put(countCacheKey, counts);
      debugPrint('Fetched objets online: $groupedObjets');
    } catch (e) {
      debugPrint('Error al obtener objetos: $e');
      final cachedObjets = box.get(cacheKey, defaultValue: {});
      final cachedCounts = box.get(countCacheKey, defaultValue: {});
      setState(() {
        groupedObjets = Map<String, List<Map<String, dynamic>>>.from(
            cachedObjets.map((key, value) => MapEntry(
                key,
                List<Map<String, dynamic>>.from(
                    value.map((item) => Map<String, dynamic>.from(item))))));
        categoryCounts = Map<String, int>.from(cachedCounts);
      });
      debugPrint('Loaded cached objets due to error: $groupedObjets');
    }
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

    debugPrint(
        'Showing dialog for object: ${item['name']}, imagePath: $imagePath');
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
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            frameBuilder: (context, child, frame,
                                wasSynchronouslyLoaded) {
                              return child;
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint(
                                  'Error loading local image in dialog: $error, path: $imagePath');
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
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blue),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                      'Error loading network image in dialog: $error, url: $url');
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

  Widget _buildCategorySection(
      String title, List<Map<String, dynamic>> items, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
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
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 100, 100, 100),
              width: 2,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: title.toLowerCase() == 'avatares' ? 1.0 : 0.9,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final category = title.toLowerCase();
              final isObtained = userObjets.contains(item['id']);
              final imagePath = item['local_image_path'] ??
                  item['image_url'] ??
                  'assets/images/refmmp.png';
              Widget imageWidget;

              debugPrint(
                  'Building grid item: ${item['name']}, imagePath: $imagePath');
              if (category == 'trompetas') {
                imageWidget = Padding(
                  padding: const EdgeInsets.all(4.0),
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
                            child: imagePath.isNotEmpty &&
                                    !imagePath.startsWith('http') &&
                                    File(imagePath).existsSync()
                                ? Image.file(
                                    File(imagePath),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    frameBuilder: (context, child, frame,
                                        wasSynchronouslyLoaded) {
                                      return child;
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : imagePath.isNotEmpty &&
                                        Uri.tryParse(imagePath)?.isAbsolute ==
                                            true
                                    ? CachedNetworkImage(
                                        imageUrl: imagePath,
                                        cacheManager:
                                            CustomCacheManager.instance,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        height: double.infinity,
                                        placeholder: (context, url) =>
                                            const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.blue),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                          'assets/images/refmmp.png',
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/images/refmmp.png',
                                        fit: BoxFit.contain,
                                      ),
                          ),
                        ),
                        if (isObtained)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
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
                          color: isObtained ? Colors.green : Colors.blue,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: imagePath.isNotEmpty &&
                                !imagePath.startsWith('http') &&
                                File(imagePath).existsSync()
                            ? Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                frameBuilder: (context, child, frame,
                                    wasSynchronouslyLoaded) {
                                  return child;
                                },
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
                                    errorWidget: (context, url, error) =>
                                        Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/refmmp.png',
                                    fit: BoxFit.cover,
                                  ),
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
                          child: imagePath.isNotEmpty &&
                                  !imagePath.startsWith('http') &&
                                  File(imagePath).existsSync()
                              ? Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  frameBuilder: (context, child, frame,
                                      wasSynchronouslyLoaded) {
                                    return child;
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset(
                                    'assets/images/refmmp.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : imagePath.isNotEmpty &&
                                      Uri.tryParse(imagePath)?.isAbsolute ==
                                          true
                                  ? CachedNetworkImage(
                                      imageUrl: imagePath,
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      placeholder: (context, url) =>
                                          const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.blue),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/refmmp.png',
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                    ),
                        ),
                      ),
                      if (isObtained)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                );
              }

              return GestureDetector(
                onTap: () => _showObjectDialog(context, item, category),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: imageWidget,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['name'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: themeProvider.isDarkMode
                              ? Color.fromARGB(255, 255, 255, 255)
                              : Color.fromARGB(255, 33, 150, 243),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isObtained) ...[
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
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ] else ...[
                            Image.asset(
                              'assets/images/coin.png',
                              width: 14,
                              height: 14,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              numberFormat.format(item['price'] ?? 0),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (categoryCounts[title] != null && categoryCounts[title]! > 6)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => ObjetsDetailsPage(
                  //       title: title,
                  //       category: title,
                  //     ),
                  //   ),
                  // );
                },
                child: Text(
                  'TODOS L@S ${title.toUpperCase()} (${categoryCounts[title] ?? items.length})',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileImageProvider = Provider.of<ProfileImageProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');

    debugPrint(
        'Building ObjetsPage with wallpaperUrl: ${profileImageProvider.wallpaperUrl}, profileImageUrl: ${profileImageProvider.profileImageUrl}');

    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          await _checkConnectivityStatus();
          await fetchObjets();
          await fetchUserObjets();
          await fetchTotalCoins();
          await fetchUserProfileImage();
          await fetchWallpaper();
          if (_isOnline) {
            await _syncPendingActions();
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: expandedHeight ?? 400.0,
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
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: Colors.blue,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/images/coin.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    numberFormat.format(totalCoins),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16.0),
                title: Text(
                  'Objetos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    profileImageProvider.wallpaperUrl != null &&
                            profileImageProvider.wallpaperUrl!.isNotEmpty &&
                            !profileImageProvider.wallpaperUrl!
                                .startsWith('http') &&
                            File(profileImageProvider.wallpaperUrl!)
                                .existsSync()
                        ? Image.file(
                            File(profileImageProvider.wallpaperUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint(
                                  'Error loading local wallpaper in SliverAppBar: $error, path: ${profileImageProvider.wallpaperUrl}');
                              return Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : profileImageProvider.wallpaperUrl != null &&
                                profileImageProvider.wallpaperUrl!.isNotEmpty &&
                                Uri.tryParse(profileImageProvider.wallpaperUrl!)
                                        ?.isAbsolute ==
                                    true
                            ? CachedNetworkImage(
                                imageUrl: profileImageProvider.wallpaperUrl!,
                                cacheManager: CustomCacheManager.instance,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                                errorWidget: (context, url, error) {
                                  debugPrint(
                                      'Error loading network wallpaper in SliverAppBar: $error, url: $url');
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
                    Center(
                      child: Image.asset(
                        'assets/images/coin.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '| Descripción',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Las monedas se utilizan para desbloquear objetos y mejoras. Puedes adquirirlas comprando paquetes en la tienda o ganándolas al completar desafíos y niveles.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 40,
                      thickness: 2,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 34, 34, 34)
                          : const Color.fromARGB(255, 236, 234, 234),
                    ),
                    for (var entry
                        in groupedObjets.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key)))
                      _buildCategorySection(entry.key, entry.value, context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canAddEvent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('FutureBuilder esperando...');
            return const SizedBox.shrink();
          }

          if (snapshot.hasError) {
            debugPrint('Error en FutureBuilder: ${snapshot.error}');
            return const SizedBox.shrink();
          }

          debugPrint('Resultado de _canAddEvent: ${snapshot.data}');
          return snapshot.data == true
              ? FloatingActionButton(
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => const AddEventForm()),
                    // );
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
