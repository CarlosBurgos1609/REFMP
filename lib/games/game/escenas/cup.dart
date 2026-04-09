import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:refmp/dialogs/dialog_classification.dart';
import 'package:refmp/edit/edit_rewards.dart';
import 'package:refmp/forms/rewardsForm.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

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
  Timer? _weeklyResetTimer;
  Duration _timeUntilWeeklyReset = Duration.zero;
  bool _isProcessingWeeklyReset = false;
  bool _canManageRewards = false;

  String _rewardsCacheKeyForCurrentWeek() {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekStartStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    return 'cup_rewards_$weekStartStr';
  }

  Future<List<Map<String, dynamic>>> _loadRewardsFromCache() async {
    try {
      final box = Hive.box('offline_data');
      final cacheKey = _rewardsCacheKeyForCurrentWeek();
      final cachedJson = box.get(cacheKey);

      if (cachedJson == null) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(cachedJson.toString());
      if (decoded is! List) return <Map<String, dynamic>>[];

      final cachedRewards = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (cachedRewards.isNotEmpty) {
        debugPrint('✅ Rewards cargados desde caché: ${cachedRewards.length}');
      }
      return cachedRewards;
    } catch (e) {
      debugPrint('Error cargando rewards desde caché: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveRewardsToCache(List<Map<String, dynamic>> rewards) async {
    try {
      final box = Hive.box('offline_data');
      final cacheKey = _rewardsCacheKeyForCurrentWeek();
      await box.put(cacheKey, jsonEncode(rewards));
      debugPrint('✅ Rewards guardados en caché: ${rewards.length}');
    } catch (e) {
      debugPrint('Error guardando rewards en caché: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInitialize();
    fetchUserProfileImage();
    ensureCurrentUserInUsersGames();
    _loadRewardManagementPermission();
    // Agregar debug de la base de datos
    debugDatabaseData();
    // Inicializar timer para verificar reset semanal
    _initializeWeeklyResetTimer();
    // Verificar si hay recompensas pendientes al iniciar
    _checkPendingRewards();
  }

  @override
  void dispose() {
    _weeklyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRewardManagementPermission() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final users = await supabase
          .from('users')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      final advisors = await supabase
          .from('advisors')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      final directors = await supabase
          .from('directors')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _canManageRewards =
            users != null || advisors != null || directors != null;
      });
    } catch (e) {
      debugPrint('Error loading reward management permissions: $e');
      if (!mounted) return;
      setState(() {
        _canManageRewards = false;
      });
    }
  }

  DateTime _weeklyResetTargetFor(DateTime now) {
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = weekStart.add(const Duration(days: 6));
    return DateTime(sunday.year, sunday.month, sunday.day, 23, 0, 0);
  }

  Duration _computeTimeUntilNextReset(DateTime now) {
    final thisWeekTarget = _weeklyResetTargetFor(now);
    if (now.isBefore(thisWeekTarget)) {
      return thisWeekTarget.difference(now);
    }
    final nextWeekTarget = thisWeekTarget.add(const Duration(days: 7));
    return nextWeekTarget.difference(now);
  }

  String _formatCountdown(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final totalSeconds = safe.inSeconds;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${days.toString().padLeft(2, '0')}d '
        '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m '
        '${seconds.toString().padLeft(2, '0')}s';
  }

  void _initializeWeeklyResetTimer() {
    _weeklyResetTimer?.cancel();
    _updateCountdownAndMaybeReset();
    _weeklyResetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdownAndMaybeReset();
    });
  }

  Future<void> _updateCountdownAndMaybeReset() async {
    final now = DateTime.now();
    final thisWeekTarget = _weeklyResetTargetFor(now);

    if (now.isAfter(thisWeekTarget) || now.isAtSameMomentAs(thisWeekTarget)) {
      final box = await Hive.openBox('weekly_rewards');
      final resetKey = DateFormat('yyyy-MM-dd').format(thisWeekTarget);
      final lastGlobalResetKey = box.get('global_last_reset_key');

      if (lastGlobalResetKey != resetKey && !_isProcessingWeeklyReset) {
        _isProcessingWeeklyReset = true;
        await _processWeeklyReset(resetKey: resetKey);
        _isProcessingWeeklyReset = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _timeUntilWeeklyReset = _computeTimeUntilNextReset(now);
    });
  }

  Future<void> _openRewardsForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RewardsFormPage()),
    );

    if (result == true && mounted) {
      setState(() {
        _rewardsFuture = fetchRewardsData();
      });
    }
  }

  Future<void> _openEditReward(Map<String, dynamic> reward) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditRewardPage(reward: reward),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _rewardsFuture = fetchRewardsData();
      });
    }
  }

  Future<void> _checkPendingRewards() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || !_isOnline) return;

      final box = await Hive.openBox('weekly_rewards');
      final lastResetDate = box.get('last_reset_date_$userId');
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekStartStr =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

      // Si no hay fecha de último reset o es una semana diferente, verificar si hay recompensa pendiente
      if (lastResetDate == null || lastResetDate != weekStartStr) {
        final hasPendingReward =
            box.get('pending_reward_$userId', defaultValue: false);
        if (hasPendingReward) {
          debugPrint('Recompensa pendiente detectada para usuario $userId');
          _showPendingRewardNotification();
        }
      }
    } catch (e) {
      debugPrint('Error checking pending rewards: $e');
    }
  }

  void _showPendingRewardNotification() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Tienes una recompensa semanal disponible!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              // Scroll al inicio o mostrar diálogo
            },
          ),
        ),
      );
    }
  }

  Future<void> _processWeeklyReset({required String resetKey}) async {
    try {
      if (!_isOnline) {
        debugPrint('No se puede procesar reset semanal global sin conexión');
        return;
      }

      debugPrint('Procesando reset semanal global: $resetKey');

      final rankingData = await supabase
          .from('users_games')
          .select('user_id, points_xp_weekend')
          .gt('points_xp_weekend', 0)
          .order('points_xp_weekend', ascending: false)
          .limit(50);

      for (int i = 0; i < rankingData.length; i++) {
        final item = rankingData[i];
        final userId = item['user_id']?.toString();
        final points = (item['points_xp_weekend'] ?? 0) as int;
        final position = i + 1;

        if (userId == null || userId.isEmpty || points <= 0) continue;
        await _claimWeeklyRewardForUser(userId, position);
      }

      await supabase
          .from('users_games')
          .update({'points_xp_weekend': 0}).gte('points_xp_weekend', 0);

      final resetDate = DateTime.tryParse(resetKey);
      if (resetDate != null) {
        await _rotateWeeklyRewardsAfterClaim(resetDate);
      } else {
        debugPrint(
            'No se pudo parsear resetKey para rotar recompensas: $resetKey');
      }

      final box = await Hive.openBox('weekly_rewards');
      await box.put('global_last_reset_key', resetKey);

      if (mounted) {
        setState(() {
          _cupFuture = fetchCupData();
          _rewardsFuture = fetchRewardsData();
        });
      }

      debugPrint('Reset semanal global completado con éxito: $resetKey');
    } catch (e, stackTrace) {
      debugPrint(
          'Error en _processWeeklyReset global: $e\nStack trace: $stackTrace');
    }
  }

  Future<void> _rotateWeeklyRewardsAfterClaim(DateTime resetSunday) async {
    try {
      final currentWeekStart = DateTime(
        resetSunday.year,
        resetSunday.month,
        resetSunday.day,
      ).subtract(const Duration(days: 6));
      final currentWeekEnd = DateTime(
        resetSunday.year,
        resetSunday.month,
        resetSunday.day,
      );

      final nextWeekStart = currentWeekEnd.add(const Duration(days: 1));
      final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));

      final currentWeekStartStr =
          '${currentWeekStart.year}-${currentWeekStart.month.toString().padLeft(2, '0')}-${currentWeekStart.day.toString().padLeft(2, '0')}';
      final currentWeekEndStr =
          '${currentWeekEnd.year}-${currentWeekEnd.month.toString().padLeft(2, '0')}-${currentWeekEnd.day.toString().padLeft(2, '0')}';

      final nextWeekStartStr =
          '${nextWeekStart.year}-${nextWeekStart.month.toString().padLeft(2, '0')}-${nextWeekStart.day.toString().padLeft(2, '0')}';
      final nextWeekEndStr =
          '${nextWeekEnd.year}-${nextWeekEnd.month.toString().padLeft(2, '0')}-${nextWeekEnd.day.toString().padLeft(2, '0')}';

      // Eliminar recompensas de la semana ya reclamada.
      await supabase
          .from('rewards')
          .delete()
          .eq('week_start', currentWeekStartStr)
          .eq('week_end', currentWeekEndStr);

      // Limpiar cualquier configuración previa de la próxima semana
      // para volver al estado por defecto cada domingo.
      await supabase
          .from('rewards')
          .delete()
          .eq('week_start', nextWeekStartStr)
          .eq('week_end', nextWeekEndStr);

      final defaultRows = [
        {
          'position': 1,
          'object_id': null,
          'coins_reward': _getDefaultCoins(1),
          'claimed': false,
          'week_start': nextWeekStartStr,
          'week_end': nextWeekEndStr,
        },
        {
          'position': 2,
          'object_id': null,
          'coins_reward': _getDefaultCoins(2),
          'claimed': false,
          'week_start': nextWeekStartStr,
          'week_end': nextWeekEndStr,
        },
        {
          'position': 3,
          'object_id': null,
          'coins_reward': _getDefaultCoins(3),
          'claimed': false,
          'week_start': nextWeekStartStr,
          'week_end': nextWeekEndStr,
        },
      ];

      await supabase.from('rewards').insert(defaultRows);

      debugPrint(
          'Recompensas rotadas: eliminada semana $currentWeekStartStr-$currentWeekEndStr, sembrada semana $nextWeekStartStr-$nextWeekEndStr');
    } catch (e, stackTrace) {
      debugPrint(
          'Error al rotar recompensas semanales: $e\nStack trace: $stackTrace');
    }
  }

  Future<void> _claimWeeklyRewardForUser(String userId, int position) async {
    try {
      debugPrint(
          'Reclamando recompensa semanal para user=$userId, posición=$position');

      // Obtener la recompensa correspondiente a la posición
      final rewardsData = await fetchRewardsData();
      final reward = rewardsData.firstWhere(
        (r) => r['position'] == position,
        orElse: () => {
          'position': position,
          'object_id': null,
          'coins_reward': _getDefaultCoins(position),
          'has_object': false,
          'has_coins': true,
        },
      );

      final objectId = reward['object_id'];
      final coinsReward = reward['coins_reward'] ?? 0;
      final hasObject = reward['has_object'] ?? false;
      final hasCoins = reward['has_coins'] ?? false;

      debugPrint(
          'Recompensa: objectId=$objectId, coins=$coinsReward, hasObject=$hasObject, hasCoins=$hasCoins');

      int totalCoinsToGive = 0;
      bool objectGiven = false;
      String rewardMessage = '';

      // Caso 1: Si hay objeto en la recompensa
      if (hasObject && objectId != null) {
        // Verificar si el usuario ya tiene el objeto
        final userObjectsResponse = await supabase
            .from('users_objets')
            .select('objet_id')
            .eq('user_id', userId)
            .eq('objet_id', objectId)
            .maybeSingle();

        if (userObjectsResponse != null) {
          // Ya tiene el objeto - dar 500 monedas de compensación
          debugPrint(
              'Usuario ya tiene el objeto $objectId - Dando 500 monedas de compensación');
          totalCoinsToGive = 500;
          rewardMessage =
              '¡Ya tienes este objeto! Recibiste 500 monedas de compensación';
        } else {
          // No tiene el objeto - dárselo
          debugPrint('Agregando objeto $objectId al usuario');
          await supabase.from('users_objets').insert({
            'user_id': userId,
            'objet_id': objectId,
          });
          objectGiven = true;
          rewardMessage = '¡Felicidades! Has ganado un nuevo objeto';

          // Si también hay monedas adicionales, agregarlas
          if (hasCoins && coinsReward > 0) {
            totalCoinsToGive = coinsReward;
            rewardMessage += ' y $coinsReward monedas';
          }
        }
      } else if (hasCoins && coinsReward > 0) {
        // Caso 2: Solo hay monedas
        totalCoinsToGive = coinsReward;
        rewardMessage = '¡Felicidades! Has ganado $coinsReward monedas';
      }

      // Actualizar monedas si hay que dar
      if (totalCoinsToGive > 0) {
        final currentCoinsResponse = await supabase
            .from('users_games')
            .select('coins')
            .eq('user_id', userId)
            .maybeSingle();

        final currentCoins = currentCoinsResponse?['coins'] ?? 0;
        final newCoins = currentCoins + totalCoinsToGive;

        await supabase
            .from('users_games')
            .update({'coins': newCoins}).eq('user_id', userId);

        debugPrint('Monedas actualizadas: $currentCoins -> $newCoins');
      }

      // Guardar en historial (opcional pero recomendable)
      await supabase.from('weekly_rewards_history').insert({
        'user_id': userId,
        'position': position,
        'object_id': objectGiven ? objectId : null,
        'coins_received': totalCoinsToGive,
        'claimed_at': DateTime.now().toIso8601String(),
      });

      // Marcar como recompensa reclamada
      final currentUserId = supabase.auth.currentUser?.id;
      if (mounted && currentUserId == userId) {
        _showRewardClaimedDialog(
            rewardMessage, objectGiven, objectId, totalCoinsToGive);
      }

      debugPrint('Recompensa reclamada exitosamente: $rewardMessage');
    } catch (e, stackTrace) {
      debugPrint('Error en _claimWeeklyReward: $e\nStack trace: $stackTrace');
    }
  }

  void _showRewardClaimedDialog(
      String message, bool objectGiven, int? objectId, int coins) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            const SizedBox(width: 8),
            const Text('¡Recompensa Semanal!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (coins > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/coin.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.monetization_on,
                        size: 32,
                        color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$coins',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              Navigator.pop(context);
              // Refrescar datos
              setState(() {
                _cupFuture = fetchCupData();
              });
            },
            child: const Text(
              'Continuar',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
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
        'id': null,
        'user_game_id': null,
        'position': 1,
        'object_id': null,
        'coins_reward': 500,
        'claimed': false,
        'week_start': null,
        'week_end': null,
        'image_url': 'assets/images/coin.png',
        'object_category': 'coins',
        'object_name': '500 Monedas',
        'object_description': 'Premio por defecto para el primer puesto',
        'has_object': false,
        'has_coins': true,
      },
      {
        'id': null,
        'user_game_id': null,
        'position': 2,
        'object_id': null,
        'coins_reward': 300,
        'claimed': false,
        'week_start': null,
        'week_end': null,
        'image_url': 'assets/images/coin.png',
        'object_category': 'coins',
        'object_name': '300 Monedas',
        'object_description': 'Premio por defecto para el segundo puesto',
        'has_object': false,
        'has_coins': true,
      },
      {
        'id': null,
        'user_game_id': null,
        'position': 3,
        'object_id': null,
        'coins_reward': 200,
        'claimed': false,
        'week_start': null,
        'week_end': null,
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
        debugPrint('Offline: intentando cargar rewards desde caché');
        final cachedRewards = await _loadRewardsFromCache();
        if (cachedRewards.isNotEmpty) {
          return cachedRewards;
        }
        debugPrint('Offline: sin caché disponible, usando rewards por defecto');
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
          .select(
              'id, user_game_id, position, object_id, coins_reward, claimed, week_start, week_end')
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
            .select(
                'id, user_game_id, position, object_id, coins_reward, claimed, week_start, week_end')
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
          'id': item['id'],
          'user_game_id': item['user_game_id'],
          'position': item['position'],
          'object_id': objectId,
          'coins_reward': coinsReward ?? 0,
          'claimed': item['claimed'] == true,
          'week_start': item['week_start'],
          'week_end': item['week_end'],
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
              'id': null,
              'user_game_id': null,
              'position': pos,
              'object_id': null,
              'coins_reward': _getDefaultCoins(pos),
              'claimed': false,
              'week_start': weekStartStr,
              'week_end': weekEndStr,
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

      await _saveRewardsToCache(rewards);

      return rewards;
    } catch (e, stackTrace) {
      debugPrint(
          'Error al obtener datos de premios: $e\nStack trace: $stackTrace');
      final cachedRewards = await _loadRewardsFromCache();
      if (cachedRewards.isNotEmpty) {
        return cachedRewards;
      }
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
                  width: double
                      .infinity, // Asegurar que use todo el ancho disponible
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: Column(
                    // Cambiar de Row a Column
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Centrar el contenido
                    children: [
                      // Línea 1: Icono y texto "Bonus adicional"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/coin.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.monetization_on,
                              size: 24,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bonus adicional',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // Espacio entre líneas
                      // Línea 2: Símbolo + y cantidad de monedas
                      Text(
                        '+$coins monedas',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
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
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? Colors.black54
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 1.6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timer_outlined, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Reinicio semanal (domingo 23:00)',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCountdown(_timeUntilWeeklyReset),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_canManageRewards) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isOnline ? _openRewardsForm : null,
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Agregar recompensa',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

                        final sortedRewards =
                            List<Map<String, dynamic>>.from(rewardsList)
                              ..sort((a, b) {
                                final aPos =
                                    (a['position'] as num?)?.toInt() ?? 999;
                                final bPos =
                                    (b['position'] as num?)?.toInt() ?? 999;
                                return aPos.compareTo(bPos);
                              });

                        final Map<int, Map<String, dynamic>> byPosition = {};
                        for (final reward in sortedRewards) {
                          final pos = (reward['position'] as num?)?.toInt();
                          if (pos == null) continue;
                          byPosition[pos] = reward;
                        }

                        final podiumRewards = <Map<String, dynamic>>[];
                        for (final pos in [1, 2, 3]) {
                          if (byPosition[pos] != null) {
                            podiumRewards.add(byPosition[pos]!);
                          }
                        }

                        final remainingRewards = sortedRewards
                            .where((reward) =>
                                ((reward['position'] as num?)?.toInt() ?? 0) >
                                3)
                            .toList();

                        Widget buildRewardMedia(Map<String, dynamic> reward,
                            {double size = 72}) {
                          final imageUrl =
                              (reward['image_url'] ?? '').toString();
                          final objectCategory = reward['object_category'];
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1.2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  _buildRewardImage(imageUrl, objectCategory),
                            ),
                          );
                        }

                        Widget buildPodiumCard(Map<String, dynamic> reward,
                            {required int position}) {
                          final hasObject = reward['has_object'] == true;
                          final hasCoins = reward['has_coins'] == true;
                          final isCoinsOnly = !hasObject && hasCoins;
                          final hasObjectAndCoins = hasObject && hasCoins;
                          final coins =
                              (reward['coins_reward'] as num?)?.toInt() ?? 0;
                          final objectName =
                              (reward['object_name'] ?? 'Sin premio')
                                  .toString();
                          final objectDescription =
                              reward['object_description'];
                          final canTap =
                              (hasObject && objectDescription != null) ||
                                  hasCoins;

                          String title;
                          IconData trophyIcon;
                          Color accent;
                          Color bg;

                          if (position == 1) {
                            title = 'Primer\nPuesto';
                            trophyIcon = Icons.emoji_events;
                            accent = const Color(0xFFE0B100);
                            bg = const Color(0xFFFFF9E8);
                          } else if (position == 2) {
                            title = 'Segundo\nPuesto';
                            trophyIcon = Icons.emoji_events;
                            accent = const Color(0xFF9BA3AF);
                            bg = const Color(0xFFF2F4F7);
                          } else {
                            title = 'Tercer\nPuesto';
                            trophyIcon = Icons.emoji_events;
                            accent = const Color(0xFFB87333);
                            bg = const Color(0xFFFFF3EC);
                          }

                          return Expanded(
                            child: GestureDetector(
                              onTap: canTap
                                  ? () => _showRewardDialog(context, reward)
                                  : null,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                padding:
                                    const EdgeInsets.fromLTRB(10, 10, 10, 12),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: accent, width: 1.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(trophyIcon,
                                            color: accent, size: 30),
                                        if (_canManageRewards &&
                                            reward['id'] != null)
                                          InkWell(
                                            onTap: _isOnline
                                                ? () => _openEditReward(reward)
                                                : null,
                                            child: const Padding(
                                              padding: EdgeInsets.all(2),
                                              child: Icon(Icons.edit,
                                                  color: Colors.black87,
                                                  size: 18),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (hasObject || hasCoins)
                                      buildRewardMedia(reward, size: 70)
                                    else
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: const Icon(Icons.help_outline,
                                            color: Colors.grey),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isCoinsOnly
                                          ? '+$coins monedas'
                                          : objectName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isCoinsOnly
                                            ? Colors.orange.shade700
                                            : Colors.black87,
                                        height: 1.1,
                                      ),
                                    ),
                                    if (hasObjectAndCoins) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '+$coins monedas',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        Widget buildCompactRewardRow(
                            Map<String, dynamic> reward) {
                          final position =
                              (reward['position'] as num?)?.toInt() ?? 0;
                          final hasObject = reward['has_object'] == true;
                          final hasCoins = reward['has_coins'] == true;
                          final isCoinsOnly = !hasObject && hasCoins;
                          final hasObjectAndCoins = hasObject && hasCoins;
                          final coins =
                              (reward['coins_reward'] as num?)?.toInt() ?? 0;
                          final objectName =
                              (reward['object_name'] ?? 'Sin premio')
                                  .toString();
                          final objectDescription =
                              reward['object_description'];
                          final canTap =
                              (hasObject && objectDescription != null) ||
                                  hasCoins;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: canTap
                                  ? () => _showRewardDialog(context, reward)
                                  : null,
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$position',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  buildRewardMedia(reward, size: 44),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCoinsOnly
                                              ? '+$coins monedas'
                                              : objectName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isCoinsOnly
                                                ? Colors.orange.shade700
                                                : Colors.black87,
                                          ),
                                        ),
                                        if (hasObjectAndCoins) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '+$coins monedas',
                                            style: TextStyle(
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (_canManageRewards && reward['id'] != null)
                                    IconButton(
                                      tooltip: 'Editar recompensa',
                                      onPressed: _isOnline
                                          ? () => _openEditReward(reward)
                                          : null,
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? Colors.black54
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue, width: 1.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (podiumRewards.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final reward in podiumRewards)
                                      buildPodiumCard(
                                        reward,
                                        position: (reward['position'] as num?)
                                                ?.toInt() ??
                                            0,
                                      ),
                                  ],
                                ),
                              ],
                              if (remainingRewards.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Más premios',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...remainingRewards
                                    .map(buildCompactRewardRow)
                                    .toList(),
                              ],
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
