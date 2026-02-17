import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio centralizado para manejo de caché offline y sincronización
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String PENDING_XP_BOX = 'pending_xp';
  static const String PENDING_COINS_BOX = 'pending_coins';
  static const String PENDING_COMPLETIONS_BOX = 'pending_completions';
  static const String CACHE_BOX = 'offline_cache';

  late Box _pendingXpBox;
  late Box _pendingCoinsBox;
  late Box _pendingCompletionsBox;
  late Box _cacheBox;

  bool _isInitialized = false;

  /// Inicializar el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _pendingXpBox = await Hive.openBox(PENDING_XP_BOX);
      _pendingCoinsBox = await Hive.openBox(PENDING_COINS_BOX);
      _pendingCompletionsBox = await Hive.openBox(PENDING_COMPLETIONS_BOX);
      _cacheBox = await Hive.openBox(CACHE_BOX);
      _isInitialized = true;
      debugPrint('✅ OfflineSyncService inicializado');
    } catch (e) {
      debugPrint('❌ Error inicializando OfflineSyncService: $e');
    }
  }

  /// Verificar si hay conexión a internet
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Guardar datos en caché
  Future<void> saveToCache(String key, dynamic data) async {
    try {
      await _cacheBox.put(key, data);
      debugPrint('💾 Datos guardados en caché: $key');
    } catch (e) {
      debugPrint('❌ Error guardando en caché $key: $e');
    }
  }

  /// Obtener datos del caché
  T? getFromCache<T>(String key, {T? defaultValue}) {
    try {
      return _cacheBox.get(key, defaultValue: defaultValue) as T?;
    } catch (e) {
      debugPrint('❌ Error obteniendo caché $key: $e');
      return defaultValue;
    }
  }

  /// Guardar puntos XP pendientes
  Future<void> savePendingXP({
    required String userId,
    required int points,
    required String source,
    required String sourceId,
    required String sourceName,
    Map<String, dynamic>? sourceDetails,
  }) async {
    try {
      final pending = _pendingXpBox.get('pending_list', defaultValue: <Map>[]);
      final List<Map<String, dynamic>> pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      pendingList.add({
        'user_id': userId,
        'points': points,
        'source': source,
        'source_id': sourceId,
        'source_name': sourceName,
        'source_details': sourceDetails ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _pendingXpBox.put('pending_list', pendingList);
      debugPrint('💾 XP pendiente guardado: $points puntos');
    } catch (e) {
      debugPrint('❌ Error guardando XP pendiente: $e');
    }
  }

  /// Guardar monedas pendientes
  Future<void> savePendingCoins({
    required String userId,
    required int coins,
    required String source,
  }) async {
    try {
      final pending =
          _pendingCoinsBox.get('pending_list', defaultValue: <Map>[]);
      final List<Map<String, dynamic>> pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      pendingList.add({
        'user_id': userId,
        'coins': coins,
        'source': source,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _pendingCoinsBox.put('pending_list', pendingList);
      debugPrint('💾 Monedas pendientes guardadas: $coins');
    } catch (e) {
      debugPrint('❌ Error guardando monedas pendientes: $e');
    }
  }

  /// Guardar completación pendiente
  Future<void> savePendingCompletion({
    required String userId,
    required String levelId,
    required String sublevelId,
    required bool completed,
  }) async {
    try {
      final pending =
          _pendingCompletionsBox.get('pending_list', defaultValue: <Map>[]);
      final List<Map<String, dynamic>> pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      pendingList.add({
        'user_id': userId,
        'level_id': levelId,
        'sublevel_id': sublevelId,
        'completed': completed,
        'completion_date': DateTime.now().toIso8601String(),
      });

      await _pendingCompletionsBox.put('pending_list', pendingList);
      debugPrint('💾 Completación pendiente guardada: $sublevelId');
    } catch (e) {
      debugPrint('❌ Error guardando completación pendiente: $e');
    }
  }

  /// Sincronizar todos los datos pendientes
  Future<bool> syncAllPendingData() async {
    if (!await isOnline()) {
      debugPrint('📱 Sin conexión, no se puede sincronizar');
      return false;
    }

    debugPrint('🔄 Iniciando sincronización de datos pendientes...');
    bool allSuccess = true;

    // Sincronizar XP
    allSuccess = await _syncPendingXP() && allSuccess;

    // Sincronizar monedas
    allSuccess = await _syncPendingCoins() && allSuccess;

    // Sincronizar completaciones
    allSuccess = await _syncPendingCompletions() && allSuccess;

    if (allSuccess) {
      debugPrint('✅ Sincronización completada exitosamente');
    } else {
      debugPrint('⚠️ Sincronización completada con algunos errores');
    }

    return allSuccess;
  }

  /// Sincronizar XP pendiente
  Future<bool> _syncPendingXP() async {
    try {
      final pending = _pendingXpBox.get('pending_list', defaultValue: <Map>[]);
      final pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (pendingList.isEmpty) return true;

      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> remaining = [];

      for (var item in pendingList) {
        try {
          final userId = item['user_id'];
          final points = item['points'];

          // Actualizar en perfil de usuario
          bool updated = await _updateUserProfile(userId, points);

          // Actualizar en users_games
          if (updated) {
            await _updateUserGamesPoints(userId, points, points ~/ 10);
          }

          // Registrar en historial
          await supabase.from('xp_history').insert({
            'user_id': userId,
            'points_earned': points,
            'source': item['source'],
            'source_id': item['source_id'],
            'source_name': item['source_name'],
            'source_details': item['source_details'],
            'created_at': item['timestamp'],
          });

          debugPrint('✅ XP sincronizado: $points puntos');
        } catch (e) {
          debugPrint('❌ Error sincronizando XP: $e');
          remaining.add(item);
        }
      }

      await _pendingXpBox.put('pending_list', remaining);
      return remaining.isEmpty;
    } catch (e) {
      debugPrint('❌ Error en _syncPendingXP: $e');
      return false;
    }
  }

  /// Sincronizar monedas pendientes
  Future<bool> _syncPendingCoins() async {
    try {
      final pending =
          _pendingCoinsBox.get('pending_list', defaultValue: <Map>[]);
      final pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (pendingList.isEmpty) return true;

      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> remaining = [];

      for (var item in pendingList) {
        try {
          final userId = item['user_id'];
          final coins = item['coins'];

          final existingRecord = await supabase
              .from('users_games')
              .select('coins')
              .eq('user_id', userId)
              .maybeSingle();

          if (existingRecord != null) {
            final currentCoins = existingRecord['coins'] ?? 0;
            await supabase
                .from('users_games')
                .update({'coins': currentCoins + coins}).eq('user_id', userId);
          }

          debugPrint('✅ Monedas sincronizadas: $coins');
        } catch (e) {
          debugPrint('❌ Error sincronizando monedas: $e');
          remaining.add(item);
        }
      }

      await _pendingCoinsBox.put('pending_list', remaining);
      return remaining.isEmpty;
    } catch (e) {
      debugPrint('❌ Error en _syncPendingCoins: $e');
      return false;
    }
  }

  /// Sincronizar completaciones pendientes
  Future<bool> _syncPendingCompletions() async {
    try {
      final pending =
          _pendingCompletionsBox.get('pending_list', defaultValue: <Map>[]);
      final pendingList = (pending as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (pendingList.isEmpty) return true;

      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> remaining = [];

      for (var item in pendingList) {
        try {
          final existingRecord = await supabase
              .from('users_sublevels')
              .select('*')
              .eq('user_id', item['user_id'])
              .eq('level_id', item['level_id'])
              .eq('sublevel_id', item['sublevel_id'])
              .maybeSingle();

          if (existingRecord == null) {
            await supabase.from('users_sublevels').insert({
              'user_id': item['user_id'],
              'level_id': item['level_id'],
              'sublevel_id': item['sublevel_id'],
              'completed': item['completed'],
              'completion_date': item['completion_date'],
            });
          } else {
            await supabase
                .from('users_sublevels')
                .update({
                  'completed': item['completed'],
                  'completion_date': item['completion_date'],
                })
                .eq('user_id', item['user_id'])
                .eq('level_id', item['level_id'])
                .eq('sublevel_id', item['sublevel_id']);
          }

          debugPrint('✅ Completación sincronizada: ${item['sublevel_id']}');
        } catch (e) {
          debugPrint('❌ Error sincronizando completación: $e');
          remaining.add(item);
        }
      }

      await _pendingCompletionsBox.put('pending_list', remaining);
      return remaining.isEmpty;
    } catch (e) {
      debugPrint('❌ Error en _syncPendingCompletions: $e');
      return false;
    }
  }

  /// Actualizar perfil de usuario
  Future<bool> _updateUserProfile(String userId, int points) async {
    final supabase = Supabase.instance.client;
    List<String> tables = [
      'users',
      'students',
      'graduates',
      'teachers',
      'advisors',
      'parents'
    ];

    for (String table in tables) {
      try {
        final userRecord = await supabase
            .from(table)
            .select('points_xp')
            .eq('user_id', userId)
            .maybeSingle();

        if (userRecord != null) {
          final currentXP = userRecord['points_xp'] ?? 0;
          await supabase
              .from(table)
              .update({'points_xp': currentXP + points}).eq('user_id', userId);
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  /// Actualizar puntos en users_games
  Future<void> _updateUserGamesPoints(
      String userId, int xpPoints, int coins) async {
    try {
      final supabase = Supabase.instance.client;
      final existingRecord = await supabase
          .from('users_games')
          .select('points_xp_totally, points_xp_weekend, coins')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingRecord != null) {
        final currentTotal = existingRecord['points_xp_totally'] ?? 0;
        final currentWeekend = existingRecord['points_xp_weekend'] ?? 0;
        final currentCoins = existingRecord['coins'] ?? 0;

        await supabase.from('users_games').update({
          'points_xp_totally': currentTotal + xpPoints,
          'points_xp_weekend': currentWeekend + xpPoints,
          'coins': currentCoins + coins,
        }).eq('user_id', userId);
      } else {
        await supabase.from('users_games').insert({
          'user_id': userId,
          'nickname': 'Usuario',
          'points_xp_totally': xpPoints,
          'points_xp_weekend': xpPoints,
          'coins': coins,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('❌ Error en _updateUserGamesPoints: $e');
    }
  }

  /// Obtener conteo de datos pendientes
  Map<String, int> getPendingCounts() {
    final xpCount =
        (_pendingXpBox.get('pending_list', defaultValue: <Map>[]) as List)
            .length;
    final coinsCount =
        (_pendingCoinsBox.get('pending_list', defaultValue: <Map>[]) as List)
            .length;
    final completionsCount = (_pendingCompletionsBox
            .get('pending_list', defaultValue: <Map>[]) as List)
        .length;

    return {
      'xp': xpCount,
      'coins': coinsCount,
      'completions': completionsCount,
      'total': xpCount + coinsCount + completionsCount,
    };
  }

  /// Limpiar todos los datos pendientes (usar con precaución)
  Future<void> clearAllPending() async {
    await _pendingXpBox.clear();
    await _pendingCoinsBox.clear();
    await _pendingCompletionsBox.clear();
    debugPrint('🗑️ Todos los datos pendientes eliminados');
  }
}
