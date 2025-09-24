import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:refmp/dialogs/dialog_classification.dart';
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
    // Agregar debug de la base de datos
    debugDatabaseData();
  }

  Future<void> debugDatabaseData() async {
    try {
      debugPrint('=== DEBUG DATABASE DATA ===');

      // Debug users_games table
      final usersGamesResponse = await supabase
          .from('users_games')
          .select('user_id, nickname, points_xp_weekend')
          .order('points_xp_weekend', ascending: false)
          .limit(10);

      debugPrint('users_games table (top 10):');
      for (var user in usersGamesResponse) {
        debugPrint(
            '  user_id: ${user['user_id']}, nickname: ${user['nickname']}, points_xp_weekend: ${user['points_xp_weekend']}');
      }

      // Debug rewards table
      final rewardsResponse = await supabase
          .from('rewards')
          .select('position, object_id, coins_reward, week_start, week_end')
          .order('position', ascending: true);

      debugPrint('rewards table:');
      for (var reward in rewardsResponse) {
        debugPrint(
            '  position: ${reward['position']}, object_id: ${reward['object_id']}, coins_reward: ${reward['coins_reward']}, week_start: ${reward['week_start']}, week_end: ${reward['week_end']}');
      }

      // Debug objets table
      final objetsResponse = await supabase
          .from('objets')
          .select('id, name, category, image_url')
          .limit(5);

      debugPrint('objets table (first 5):');
      for (var object in objetsResponse) {
        debugPrint(
            '  id: ${object['id']}, name: ${object['name']}, category: ${object['category']}, image_url: ${object['image_url']}');
      }

      debugPrint('=== END DEBUG DATABASE DATA ===');
    } catch (e) {
      debugPrint('Error in debugDatabaseData: $e');
    }
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

  List<Map<String, dynamic>> _getDefaultRewards() {
    return [
      {
        'position': 1,
        'object_id': null,
        'coins_reward': 500,
        'image_url': 'assets/images/coin.png',
        'object_category': 'coins',
        'object_name': '500 Monedas',
        'object_description': 'Premio por defecto para el primer puesto',
        'has_object': false,
        'has_coins': true,
      },
      {
        'position': 2,
        'object_id': null,
        'coins_reward': 300,
        'image_url': 'assets/images/coin.png',
        'object_category': 'coins',
        'object_name': '300 Monedas',
        'object_description': 'Premio por defecto para el segundo puesto',
        'has_object': false,
        'has_coins': true,
      },
      {
        'position': 3,
        'object_id': null,
        'coins_reward': 200,
        'image_url': 'assets/images/coin.png',
        'object_category': 'coins',
        'object_name': '200 Monedas',
        'object_description': 'Premio por defecto para el tercer puesto',
        'has_object': false,
        'has_coins': true,
      },
    ];
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
        return _getDefaultRewards();
      }

      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(Duration(days: 6));

      // Formatear las fechas correctamente para Supabase
      final weekStartStr =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      final weekEndStr =
          '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

      debugPrint('Fetching rewards for week: $weekStartStr to $weekEndStr');

      // Primera consulta: obtener todos los rewards para esta semana
      final rewardsResponse = await supabase
          .from('rewards')
          .select('position, object_id, coins_reward, week_start, week_end')
          .eq('week_start', weekStartStr)
          .eq('week_end', weekEndStr)
          .order('position', ascending: true);

      debugPrint(
          'Supabase rewards response: ${rewardsResponse.length} rewards fetched');
      debugPrint('Raw rewards response: $rewardsResponse');

      // Si no hay rewards para esta semana específica, intentar obtener datos de cualquier semana activa
      List<dynamic> finalRewardsResponse = rewardsResponse;
      if (rewardsResponse.isEmpty) {
        debugPrint(
            'No rewards found for specific week, trying to get any active rewards');
        finalRewardsResponse = await supabase
            .from('rewards')
            .select('position, object_id, coins_reward, week_start, week_end')
            .order('position', ascending: true)
            .limit(10);
        debugPrint(
            'Fallback rewards response: ${finalRewardsResponse.length} rewards found');
      }

      List<Map<String, dynamic>> rewards = [];

      for (var item in finalRewardsResponse) {
        String? imageUrl;
        String objectName = 'Premio';
        String? objectCategory;
        String? objectDescription;
        bool hasObject = false;
        bool hasCoins = false;

        final objectId = item['object_id'];
        final coinsReward = item['coins_reward'];

        debugPrint(
            'Processing reward - Position: ${item['position']}, ObjectID: $objectId, Coins: $coinsReward');

        // Verificar si hay objeto y obtener sus datos
        if (objectId != null) {
          try {
            debugPrint('Fetching object data for object_id: $objectId');
            final objectResponse = await supabase
                .from('objets')
                .select('id, name, image_url, category, description')
                .eq('id', objectId)
                .maybeSingle();

            if (objectResponse != null) {
              hasObject = true;
              objectName = objectResponse['name'] ?? 'Objeto desconocido';
              objectCategory = objectResponse['category'];
              objectDescription = objectResponse['description'];
              imageUrl = objectResponse['image_url'];

              debugPrint(
                  'Object data fetched: name=$objectName, category=$objectCategory, imageUrl=$imageUrl');

              // Cachear imagen si es una URL
              if (imageUrl != null && imageUrl.startsWith('http')) {
                try {
                  final fileInfo =
                      await CustomCacheManager.instance.downloadFile(imageUrl);
                  imageUrl = fileInfo.file.path;
                  debugPrint('Cached image for ${objectName}: $imageUrl');
                } catch (e) {
                  debugPrint(
                      'Error caching image for object ${objectName}: $e');
                  imageUrl = 'assets/images/refmmp.png';
                }
              } else if (imageUrl == null || imageUrl.isEmpty) {
                imageUrl = 'assets/images/refmmp.png';
              }
            } else {
              debugPrint('No object found for object_id: $objectId');
            }
          } catch (e) {
            debugPrint(
                'Error fetching object data for object_id $objectId: $e');
          }
        }

        // Verificar si hay monedas
        if (coinsReward != null && coinsReward > 0) {
          hasCoins = true;
          debugPrint('Coins reward found: $coinsReward');
        }

        // Si no hay objeto pero sí monedas, usar imagen de moneda
        if (!hasObject && hasCoins) {
          imageUrl = 'assets/images/coin.png';
          objectName = '$coinsReward Monedas';
          objectCategory = 'coins';
          debugPrint('Setting coins-only reward: $objectName');
        }

        // Si no hay ni objeto ni monedas
        if (!hasObject && !hasCoins) {
          imageUrl = 'assets/images/refmmp.png';
          objectName = 'Sin premio asignado';
          objectCategory = 'empty';
          debugPrint('No reward assigned for position ${item['position']}');
        }

        rewards.add({
          'position': item['position'],
          'object_id': objectId,
          'coins_reward': coinsReward ?? 0,
          'image_url': imageUrl ?? 'assets/images/refmmp.png',
          'object_category': objectCategory,
          'object_name': objectName,
          'object_description': objectDescription,
          'has_object': hasObject,
          'has_coins': hasCoins,
        });

        debugPrint(
            'Added reward for position ${item['position']}: object=$hasObject, coins=$hasCoins, name=$objectName');
      }

      // Si no hay datos en la base de datos, agregar premios por defecto
      if (rewards.isEmpty) {
        debugPrint('No rewards found in database, using defaults');
        rewards = _getDefaultRewards();
      } else {
        // Asegurar que tenemos al menos los primeros 3 puestos
        for (int pos = 1; pos <= 3; pos++) {
          if (!rewards.any((r) => r['position'] == pos)) {
            rewards.add({
              'position': pos,
              'object_id': null,
              'coins_reward': _getDefaultCoins(pos),
              'image_url': 'assets/images/coin.png',
              'object_category': 'coins',
              'object_name': '${_getDefaultCoins(pos)} Monedas',
              'object_description': 'Premio por defecto para puesto $pos',
              'has_object': false,
              'has_coins': true,
            });
            debugPrint('Added default reward for position $pos');
          }
        }
      }

      rewards.sort((a, b) => a['position'].compareTo(b['position']));
      debugPrint('Final processed rewards: ${rewards.length} items');

      // Debug final rewards
      for (var reward in rewards) {
        debugPrint(
            'Final reward - Position: ${reward['position']}, Name: ${reward['object_name']}, HasObject: ${reward['has_object']}, HasCoins: ${reward['has_coins']}, Coins: ${reward['coins_reward']}');
      }

      return rewards;
    } catch (e, stackTrace) {
      debugPrint(
          'Error al obtener datos de premios: $e\nStack trace: $stackTrace');
      return _getDefaultRewards();
    }
  }

  int _getDefaultCoins(int position) {
    switch (position) {
      case 1:
        return 500;
      case 2:
        return 300;
      case 3:
        return 200;
      default:
        return 100;
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

  // Agregar esta función para mostrar el diálogo de recompensas
  void _showRewardDialog(BuildContext context, Map<String, dynamic> reward) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final objectName = reward['object_name'] ?? 'Premio';
    final objectDescription = reward['object_description'];
    final objectCategory = reward['object_category'];
    final imageUrl = reward['image_url'];
    final coins = reward['coins_reward'] ?? 0;
    final hasObject = reward['has_object'] ?? false;
    final hasCoins = reward['has_coins'] ?? false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Título del diálogo
              Text(
                objectName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Imagen del objeto
              if (hasObject) ...[
                Container(
                  width: objectCategory == 'fondos' ? double.infinity : 150,
                  height: objectCategory == 'fondos' ? 200 : 150,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(objectCategory == 'avatares'
                            ? 75
                            : objectCategory == 'fondos'
                                ? 12
                                : 8),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(objectCategory == 'avatares'
                            ? 75
                            : objectCategory == 'fondos'
                                ? 12
                                : 8),
                    child: _buildRewardImage(imageUrl, objectCategory),
                  ),
                ),
              ] else if (hasCoins) ...[
                // Solo monedas
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 2),
                    color: Colors.amber.shade50,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/coin.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.monetization_on,
                                  size: 50, color: Colors.amber),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Descripción
              if (objectDescription != null &&
                  objectDescription.isNotEmpty) ...[
                Text(
                  objectDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[300]
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Información de monedas adicionales
              if (hasObject && hasCoins) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/coin.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+$coins monedas adicionales',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botón cerrar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
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
  }

  // Función auxiliar para construir la imagen según el tipo
  Widget _buildRewardImage(String imageUrl, String? objectCategory) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: objectCategory == 'trompetas'
            ? BoxFit.contain
            : objectCategory == 'fondos'
                ? BoxFit.cover
                : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/refmmp.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    } else if (File(imageUrl).existsSync()) {
      return Image.file(
        File(imageUrl),
        fit: objectCategory == 'trompetas'
            ? BoxFit.contain
            : objectCategory == 'fondos'
                ? BoxFit.cover
                : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/refmmp.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: CustomCacheManager.instance,
        fit: objectCategory == 'trompetas'
            ? BoxFit.contain
            : objectCategory == 'fondos'
                ? BoxFit.cover
                : BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
        errorWidget: (context, url, error) {
          return Image.asset(
            'assets/images/refmmp.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      );
    } else {
      return Image.asset(
        'assets/images/refmmp.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
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
                            children: rewardsList.map((reward) {
                              final position = reward['position'];
                              final imageUrl = reward['image_url'];
                              final coins = reward['coins_reward'] ?? 0;
                              final objectCategory = reward['object_category'];
                              final objectName = reward['object_name'];

                              final hasObject = reward['has_object'] ?? false;
                              final hasCoins = reward['has_coins'] ?? false;
                              final objectDescription =
                                  reward['object_description'];

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
                                  positionText = position <= 50
                                      ? 'Puestos ${position} al 50'
                                      : 'Puesto $position';
                                  trophyColor = Colors.grey;
                              }

                              Widget imageWidget;
                              Widget rewardContent;

                              // Construir widget de imagen
                              if (imageUrl.startsWith('assets/')) {
                                imageWidget = Image.asset(
                                  imageUrl,
                                  fit: objectCategory == 'trompetas'
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                    );
                                  },
                                );
                              } else if (File(imageUrl).existsSync()) {
                                imageWidget = Image.file(
                                  File(imageUrl),
                                  fit: objectCategory == 'trompetas'
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                    );
                                  },
                                );
                              } else if (Uri.tryParse(imageUrl)?.isAbsolute ==
                                  true) {
                                imageWidget = CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  cacheManager: CustomCacheManager.instance,
                                  fit: objectCategory == 'trompetas'
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.blue),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                    );
                                  },
                                );
                              } else {
                                imageWidget = Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                );
                              }

                              // Construir contenido según el tipo de recompensa
                              if (hasObject && hasCoins) {
                                // Caso: Objeto + Monedas
                                rewardContent = Row(
                                  children: [
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
                                        child: imageWidget,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            objectName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              Image.asset(
                                                'assets/images/coin.png',
                                                width: 16,
                                                height: 16,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                        Icons.monetization_on,
                                                        size: 16,
                                                        color: Colors.amber),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+$coins monedas',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.amber.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else if (hasObject && !hasCoins) {
                                // Caso: Solo Objeto
                                rewardContent = Row(
                                  children: [
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
                                        child: imageWidget,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        objectName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              } else if (!hasObject && hasCoins) {
                                // Caso: Solo Monedas
                                rewardContent = Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.blue, width: 1.5),
                                        color: Colors.amber.shade50,
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          'assets/images/coin.png',
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.monetization_on,
                                                  size: 24,
                                                  color: Colors.amber),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$coins Monedas',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Caso: Sin recompensa
                                rewardContent = Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey, width: 1.5),
                                        color: Colors.grey.shade100,
                                      ),
                                      child: const Icon(Icons.help_outline,
                                          color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Sin premio asignado',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: GestureDetector(
                                  onTap: (hasObject &&
                                              objectDescription != null) ||
                                          hasCoins
                                      ? () => _showRewardDialog(context, reward)
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
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          positionText,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: rewardContent),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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
                                child: GestureDetector(
                                  onTap: _isOnline
                                      ? () => showUserProfileDialog(
                                          context, item, _isOnline)
                                      : null,
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
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    'XP',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Indicador visual cuando está offline
                                        if (!_isOnline)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.wifi_off,
                                              color: Colors.grey,
                                              size: 16,
                                            ),
                                          ),
                                      ],
                                    ),
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
