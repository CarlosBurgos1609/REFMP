import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:refmp/dialogs/dialog_achievements.dart';
import 'package:refmp/dialogs/dialog_objets.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/games/play.dart';

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
  bool _isOnline = true;
  List<Map<String, dynamic>> userAchievements = [];
  List<Map<String, dynamic>> userFavoriteSongs = [];
  List<Map<String, dynamic>> userObjects = [];
  List<Map<String, dynamic>> userAvatars = [];
  List<Map<String, dynamic>> userWallpapers = [];
  List<Map<String, dynamic>> userTrumpets = [];
  int totalAchievements = 0;
  int totalFavoriteSongs = 0;
  int totalObjects = 0;
  int totalAvatars = 0;
  int totalWallpapers = 0;
  int totalTrumpets = 0;
  final Map<String, bool> _gifVisibility = {};

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _initializeData();
  }

  Future<void> _initializeHive() async {
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
    }
  }

  Future<void> _initializeData() async {
    await Future.wait([
      fetchUserAchievements(),
      fetchUserFavoriteSongs(),
      fetchUserObjects('otros', userObjects, 'total_objects'),
      fetchUserObjects('avatares', userAvatars, 'total_avatars'),
      fetchUserObjects('fondos', userWallpapers, 'total_wallpapers'),
      fetchUserObjects('trompetas', userTrumpets, 'total_trumpets'),
    ]);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> fetchUserAchievements() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_achievements_$userId';
    final countCacheKey = 'total_achievements_$userId';

    try {
      if (!_isOnline) {
        final cachedAchievements = box.get(cacheKey, defaultValue: []);
        setState(() {
          userAchievements = List<Map<String, dynamic>>.from(
            cachedAchievements.map((item) => Map<String, dynamic>.from(item)),
          ).take(3).toList();
          totalAchievements =
              box.get(countCacheKey, defaultValue: cachedAchievements.length);
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
          .order('created_at', ascending: false)
          .limit(3);

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

      setState(() {
        userAchievements = fetchedAchievements;
        totalAchievements = countResponse.count;
      });
      await box.put(cacheKey, fetchedAchievements);
      await box.put(countCacheKey, countResponse.count);
    } catch (e) {
      debugPrint('Error fetching user achievements: $e');
      final cachedAchievements = box.get(cacheKey, defaultValue: []);
      setState(() {
        userAchievements = List<Map<String, dynamic>>.from(
          cachedAchievements.map((item) => Map<String, dynamic>.from(item)),
        ).take(3).toList();
        totalAchievements =
            box.get(countCacheKey, defaultValue: cachedAchievements.length);
      });
    }
  }

  Future<void> fetchUserFavoriteSongs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final box = Hive.box('offline_data');
    final cacheKey = 'user_favorite_songs_$userId';
    final countCacheKey = 'total_favorite_songs_$userId';

    try {
      if (!_isOnline) {
        final cachedSongs = box.get(cacheKey, defaultValue: []);
        setState(() {
          userFavoriteSongs = List<Map<String, dynamic>>.from(
            cachedSongs.map((item) => Map<String, dynamic>.from(item)),
          ).take(3).toList();
          totalFavoriteSongs =
              box.get(countCacheKey, defaultValue: cachedSongs.length);
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
          .order('created_at', ascending: false)
          .limit(3);

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

      setState(() {
        userFavoriteSongs = fetchedSongs;
        totalFavoriteSongs = countResponse.count;
      });
      await box.put(cacheKey, fetchedSongs);
      await box.put(countCacheKey, countResponse.count);
    } catch (e) {
      debugPrint('Error fetching favorite songs: $e');
      final cachedSongs = box.get(cacheKey, defaultValue: []);
      setState(() {
        userFavoriteSongs = List<Map<String, dynamic>>.from(
          cachedSongs.map((item) => Map<String, dynamic>.from(item)),
        ).take(3).toList();
        totalFavoriteSongs =
            box.get(countCacheKey, defaultValue: cachedSongs.length);
      });
    }
  }

  Future<void> fetchUserObjects(String category,
      List<Map<String, dynamic>> targetList, String countKey) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Error: userId is null in fetchUserObjects');
      return;
    }

    final box = Hive.box('offline_data');
    final cacheKey = 'user_${category}_$userId';
    final countCacheKey =
        '${countKey}_$userId'; // Corregido para asegurar que countKey se usa correctamente

    try {
      if (!_isOnline) {
        final cachedObjects = box.get(cacheKey, defaultValue: []);
        setState(() {
          targetList.clear();
          targetList.addAll(List<Map<String, dynamic>>.from(
            cachedObjects.map((item) => Map<String, dynamic>.from(item)),
          ).take(3).toList());
          if (category == 'otros')
            totalObjects =
                box.get(countCacheKey, defaultValue: cachedObjects.length);
          else if (category == 'avatares')
            totalAvatars =
                box.get(countCacheKey, defaultValue: cachedObjects.length);
          else if (category == 'fondos')
            totalWallpapers =
                box.get(countCacheKey, defaultValue: cachedObjects.length);
          else if (category == 'trompetas')
            totalTrumpets =
                box.get(countCacheKey, defaultValue: cachedObjects.length);
        });
        for (var item in targetList) {
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
          .eq('objets.category', category)
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

      final countResponse = await supabase
          .from('users_objets')
          .select('objet_id')
          .eq('user_id', userId)
          .eq('objets.category', category)
          .count(CountOption.exact);

      setState(() {
        targetList.clear();
        targetList.addAll(fetchedObjects);
        if (category == 'otros')
          totalObjects = countResponse.count;
        else if (category == 'avatares')
          totalAvatars = countResponse.count;
        else if (category == 'fondos')
          totalWallpapers = countResponse.count;
        else if (category == 'trompetas') totalTrumpets = countResponse.count;
      });
      await box.put(cacheKey, fetchedObjects);
      await box.put(countCacheKey, countResponse.count);
    } catch (e) {
      debugPrint('Error fetching $category objects: $e');
      final cachedObjects = box.get(cacheKey, defaultValue: []);
      setState(() {
        targetList.clear();
        targetList.addAll(List<Map<String, dynamic>>.from(
          cachedObjects.map((item) => Map<String, dynamic>.from(item)),
        ).take(3).toList());
        if (category == 'otros')
          totalObjects =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
        else if (category == 'avatares')
          totalAvatars =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
        else if (category == 'fondos')
          totalWallpapers =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
        else if (category == 'trompetas')
          totalTrumpets =
              box.get(countCacheKey, defaultValue: cachedObjects.length);
      });
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

  Widget _buildImageWidget(String category, String imagePath, bool isObtained,
      String visibilityKey) {
    final isVisible = _gifVisibility[visibilityKey] ?? false;

    Widget imageWidget;

    if (category == 'avatares') {
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

  Widget _buildSectionTitle(String title) {
    return Row(
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
    );
  }

  Widget _buildGridSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required int totalItems,
    required String category,
    required Function(Map<String, dynamic>, String) onTap,
    required String buttonText,
    VoidCallback? buttonOnPressed,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
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
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No tienes elementos en esta categoría.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: category == 'achievements' ? 0.6 : 0.9,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final visibilityKey =
                        category == 'achievements' || category == 'songs'
                            ? '${category}_${item['id']}'
                            : '${item['id']}';
                    return VisibilityDetector(
                      key: Key(visibilityKey),
                      onVisibilityChanged: (visibilityInfo) {
                        final visiblePercentage =
                            visibilityInfo.visibleFraction * 100;
                        setState(() {
                          _gifVisibility[visibilityKey] =
                              visiblePercentage > 10;
                        });
                      },
                      child: GestureDetector(
                        onTap: () => onTap(item, category),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: _buildImageWidget(
                                  category,
                                  item['local_image_path'] ??
                                      item[category == 'achievements' ||
                                              category == 'songs'
                                          ? 'image'
                                          : 'image_url'] ??
                                      'assets/images/refmmp.png',
                                  true,
                                  visibilityKey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['name'] ?? category == 'achievements'
                                    ? 'Logro'
                                    : category == 'songs'
                                        ? 'Canción'
                                        : 'Objeto',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (category != 'achievements' &&
                                  category != 'songs')
                                const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              if (category == 'songs')
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
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (totalItems > 3)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: buttonOnPressed,
                child: Text(
                  '$buttonText ($totalItems)',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Mis Objetos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),
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
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: _initializeData,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGridSection(
                  title: 'Logros Obtenidos',
                  items: userAchievements,
                  totalItems: totalAchievements,
                  category: 'achievements',
                  onTap: (item, _) => showAchievementDialog(context, item),
                  buttonText: 'TODOS MIS LOGROS',
                  buttonOnPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllAchievementsPage(
                            instrumentName: widget.instrumentName),
                      ),
                    );
                  },
                ),
                if (totalAchievements > 0)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          // No action for now
                        },
                        child: const Text(
                          'MÁS LOGROS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildGridSection(
                  title: 'Mis Canciones Favoritas',
                  items: userFavoriteSongs,
                  totalItems: totalFavoriteSongs,
                  category: 'songs',
                  onTap: (item, _) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayPage(songName: item['name']),
                      ),
                    );
                  },
                  buttonText: 'TODAS MIS CANCIONES FAVORITAS',
                  buttonOnPressed: () {
                    // Navegar a una página de todas las canciones favoritas
                  },
                ),
                _buildGridSection(
                  title: 'Objetos Obtenidos',
                  items: userObjects,
                  totalItems: totalObjects,
                  category: 'otros',
                  onTap: (item, category) => showObjectDialog(
                      context, item, category, 0, _useObject, _purchaseObject),
                  buttonText: 'TODOS MIS OBJETOS',
                  buttonOnPressed: () {
                    // Navegar a una página de todos los objetos
                  },
                ),
                _buildGridSection(
                  title: 'Mis Avatares',
                  items: userAvatars,
                  totalItems: totalAvatars,
                  category: 'avatares',
                  onTap: (item, category) => showObjectDialog(
                      context, item, category, 0, _useObject, _purchaseObject),
                  buttonText: 'TODOS MIS AVATARES',
                  buttonOnPressed: () {
                    // Navegar a una página de todos los avatares
                  },
                ),
                _buildGridSection(
                  title: 'Mis Fondos',
                  items: userWallpapers,
                  totalItems: totalWallpapers,
                  category: 'fondos',
                  onTap: (item, category) => showObjectDialog(
                      context, item, category, 0, _useObject, _purchaseObject),
                  buttonText: 'TODOS MIS FONDOS',
                  buttonOnPressed: () {
                    // Navegar a una página de todos los fondos
                  },
                ),
                _buildGridSection(
                  title: 'Mis Trompetas',
                  items: userTrumpets,
                  totalItems: totalTrumpets,
                  category: 'trompetas',
                  onTap: (item, category) => showObjectDialog(
                      context, item, category, 0, _useObject, _purchaseObject),
                  buttonText: 'TODAS MIS TROMPETAS',
                  buttonOnPressed: () {
                    // Navegar a una página de todas las trompetas
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: 3, // Ajustar según la navegación
        onItemTapped: (index) {
          // Implementar navegación según el índice
        },
      ),
    );
  }

  Future<void> _useObject(Map<String, dynamic> item, String category) async {
    // Implementar lógica para usar objetos (similar a ProfilePageGame)
  }

  Future<void> _purchaseObject(Map<String, dynamic> item) async {
    // Implementar lógica para comprar objetos (similar a ProfilePageGame)
  }
}

class AllAchievementsPage extends StatelessWidget {
  final String instrumentName;
  const AllAchievementsPage({Key? key, required this.instrumentName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Todos Mis Logros',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('users_achievements')
            .select(
                'id, created_at, achievements!inner(name, image, description)')
            .eq('user_id', userId!)
            .order('created_at', ascending: false)
            .then((response) => response.map((item) {
                  final achievement =
                      item['achievements'] as Map<String, dynamic>;
                  return {
                    'id': item['id'],
                    'image': achievement['image'] ?? 'assets/images/refmmp.png',
                    'name': achievement['name'] ?? 'Logro',
                    'description':
                        achievement['description'] ?? 'Sin descripción',
                    'created_at':
                        item['created_at'] ?? DateTime.now().toIso8601String(),
                  };
                }).toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los logros'));
          }
          final achievements = snapshot.data ?? [];
          if (achievements.isEmpty) {
            return const Center(child: Text('No tienes logros obtenidos.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.6,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return GestureDetector(
                onTap: () => showAchievementDialog(context, achievement),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: CachedNetworkImage(
                          imageUrl: achievement['image'],
                          cacheManager: CustomCacheManager.instance,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue)),
                          errorWidget: (context, url, error) => Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        achievement['name'],
                        style: TextStyle(
                          fontSize: 9,
                          color: Provider.of<ThemeProvider>(context).isDarkMode
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 11),
                          const SizedBox(width: 4),
                          const Text(
                            'Obtenido',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
