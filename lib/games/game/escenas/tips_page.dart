import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:refmp/services/offline_sync_service.dart';

class TipsPage extends StatefulWidget {
  final String sublevelId;
  final String sublevelTitle;

  const TipsPage({
    super.key,
    required this.sublevelId,
    required this.sublevelTitle,
  });

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  List<Map<String, dynamic>> tips = [];
  int currentTipIndex = 0;
  int totalExperience = 0;
  bool isLoading = true;
  bool showCompletionButton = false;

  // NUEVO: Cache y sincronización offline
  final OfflineSyncService _syncService = OfflineSyncService();

  // Para el control del scroll de la descripción
  late ScrollController _scrollController;
  bool _showTopArrow = false;
  bool _showBottomArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initializeAndLoadTips(); // NUEVO: Método combinado
  }

  // NUEVO: Inicializar servicio y cargar tips
  Future<void> _initializeAndLoadTips() async {
    await _syncService.initialize();
    await loadTips(); // Carga desde caché primero, luego actualiza si hay internet
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    setState(() {
      // Mostrar flecha superior si no está en el tope (con margen de 10px)
      _showTopArrow = currentScroll > 10;
      // Mostrar flecha inferior si no está en el fondo (con margen de 10px)
      _showBottomArrow = currentScroll < (maxScroll - 10);
    });
  }

  void _checkScrollable() {
    // Verificar después de que se construya el widget si el contenido es scrolleable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        setState(() {
          _showBottomArrow = _scrollController.position.maxScrollExtent > 0;
        });
      }
    });
  }

  // NUEVO: Cargar tips con soporte offline (patrón home.dart)
  Future<void> loadTips() async {
    final supabase = Supabase.instance.client;
    final box = Hive.box('offline_data');
    final cacheKey = 'tips_${widget.sublevelId}';

    try {
      // PRIMERO: Cargar desde caché (inmediato)
      final cachedTips = box.get(cacheKey);
      if (cachedTips != null && mounted) {
        setState(() {
          tips = (cachedTips as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          isLoading = false;
        });
        debugPrint('💾 Tips cargados desde caché: ${tips.length}');
        
        // Cargar puntos XP del caché
        if (tips.isNotEmpty) {
          totalExperience = tips.first['experience_points'] ?? 0;
          debugPrint('⭐ Puntos XP desde caché: $totalExperience');
          debugPrint('💰 Monedas desde caché: ${totalExperience ~/ 10}');
        }
      }

      // SEGUNDO: Verificar si hay internet y actualizar
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        // Sin internet, quedarse con el caché
        if (!mounted) return;
        if (tips.isEmpty) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No hay tips disponibles offline'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // TERCERO: Hay internet, cargar desde Supabase
      debugPrint('🌐 Actualizando tips desde Supabase...');
      final response = await supabase
          .from('tips')
          .select()
          .eq('sublevel_id', widget.sublevelId)
          .order('tip_order', ascending: true);

      if (!mounted) return;

      if (response.isNotEmpty) {
        // Guardar en caché
        await box.put(cacheKey, response);
        debugPrint('💾 Tips actualizados en caché: ${response.length}');

        setState(() {
          tips = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }

      // Verificar si el contenido es scrolleable
      _checkScrollable();

      debugPrint('✅ Tips cargados: ${tips.length}');
      if (tips.isNotEmpty) {
        // Los puntos XP están en el primer tip (se otorgan al completar TODAS las viñetas)
        totalExperience = tips.first['experience_points'] ?? 0;
        debugPrint('⭐ Puntos XP totales por completar todos los tips: $totalExperience');
        debugPrint('💰 Monedas a ganar: ${totalExperience ~/ 10}');
      } else {
        debugPrint('⚠️ No hay tips cargados, no se otorgarán puntos');
      }
    } catch (e) {
      debugPrint('❌ Error al cargar tips: $e');

      // En caso de error, intentar cargar desde caché
      final box = Hive.box('offline_data');
      final cachedTips = box.get(cacheKey, defaultValue: []);

      if (mounted) {
        setState(() {
          tips = (cachedTips as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          isLoading = false;
        });

        // Cargar puntos XP del caché
        if (tips.isNotEmpty) {
          totalExperience = tips.first['experience_points'] ?? 0;
          debugPrint('📦 Tips cargados desde caché de emergencia: ${tips.length}');
          debugPrint('⭐ Puntos XP desde caché: $totalExperience');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cargados tips desde caché'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void nextTip() {
    if (currentTipIndex < tips.length - 1) {
      setState(() {
        currentTipIndex++;
        // Reset scroll al cambiar de tip
        _scrollController.jumpTo(0);
      });
      _checkScrollable();
    } else {
      // Última viñeta alcanzada, mostrar botón de completado
      setState(() {
        showCompletionButton = true;
      });
    }
  }

  void previousTip() {
    if (currentTipIndex > 0) {
      setState(() {
        currentTipIndex--;
        showCompletionButton = false; // Ocultar botón si regresa
        // Reset scroll al cambiar de tip
        _scrollController.jumpTo(0);
      });
      _checkScrollable();
    }
  }

  Future<bool> _saveExperiencePoints() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint('Error: Usuario no autenticado');
        return false;
      }

      if (totalExperience <= 0) {
        debugPrint('No hay puntos de experiencia para guardar');
        return false;
      }

      debugPrint('Iniciando guardado de puntos de experiencia...');
      debugPrint('Usuario ID: ${user.id}');
      debugPrint('Puntos a guardar: $totalExperience');

      // NUEVO: Verificar si estamos online
      final isOnline = await _checkConnectivity();

      if (isOnline) {
        // Guardar directamente en Supabase
        debugPrint('🌐 Guardando puntos ONLINE');

        // 1. Actualizar puntos en tabla de perfil del usuario
        bool profileUpdated = false;
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
                .eq('user_id', user.id)
                .maybeSingle();

            if (userRecord != null) {
              final currentXP = userRecord['points_xp'] ?? 0;
              final newXP = currentXP + totalExperience;

              await supabase
                  .from(table)
                  .update({'points_xp': newXP}).eq('user_id', user.id);

              debugPrint('✅ Perfil actualizado en tabla: $table');
              debugPrint('   XP anterior: $currentXP → XP nuevo: $newXP');
              profileUpdated = true;
              break;
            }
          } catch (e) {
            debugPrint('Error verificando tabla $table: $e');
            continue;
          }
        }

        if (!profileUpdated) {
          debugPrint('⚠️ No se encontró perfil de usuario en ninguna tabla');
        }

        // 2. Actualizar puntos en users_games (total y semanal)
        await _updateUserGamePoints();

        debugPrint('✅ Guardado de puntos completado exitosamente');
        return true;
      } else {
        // Guardar offline usando el servicio de sincronización
        debugPrint('📱 Sin conexión, guardando puntos OFFLINE');

        await _syncService.savePendingXP(
          userId: user.id,
          points: totalExperience,
          source: 'tips_completion',
          sourceId: widget.sublevelId,
          sourceName: widget.sublevelTitle,
          sourceDetails: {
            'total_tips': tips.length,
            'coins_earned': totalExperience ~/ 10,
          },
        );

        await _syncService.savePendingCoins(
          userId: user.id,
          coins: totalExperience ~/ 10,
          source: 'tips_completion',
        );

        debugPrint('💾 Puntos guardados para sincronizar cuando haya conexión');
        debugPrint('   ⭐ XP: $totalExperience');
        debugPrint('   💰 Monedas: ${totalExperience ~/ 10}');
        return true; // Éxito offline
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error crítico al guardar puntos de experiencia: $e');
      debugPrint('🔍 Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _updateUserGamePoints() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null || totalExperience <= 0) return;

      debugPrint('Actualizando puntos para usuario: ${user.id}');
      debugPrint('Puntos a agregar: $totalExperience');

      final existingRecord = await supabase
          .from('users_games')
          .select('points_xp_totally, points_xp_weekend, coins')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingRecord != null) {
        final currentTotal = existingRecord['points_xp_totally'] ?? 0;
        final currentWeekend = existingRecord['points_xp_weekend'] ?? 0;
        final currentCoins = existingRecord['coins'] ?? 0;

        final newTotal = currentTotal + totalExperience;
        final newWeekend = currentWeekend + totalExperience;
        final newCoins = currentCoins + (totalExperience ~/ 10);

        await supabase.from('users_games').update({
          'points_xp_totally': newTotal,
          'points_xp_weekend': newWeekend,
          'coins': newCoins,
        }).eq('user_id', user.id);

        debugPrint('✅ Puntos actualizados en users_games');
      } else {
        final newCoins = totalExperience ~/ 10;

        await supabase.from('users_games').insert({
          'user_id': user.id,
          'nickname': 'Usuario',
          'points_xp_totally': totalExperience,
          'points_xp_weekend': totalExperience,
          'coins': newCoins,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Nuevo registro creado en users_games');
      }

      // Registrar en historial de XP
      await _recordXpHistory(
        user.id,
        totalExperience,
        'tips_completion',
        widget.sublevelId,
        widget.sublevelTitle,
        {
          'total_tips': tips.length,
          'coins_earned': totalExperience ~/ 10,
        },
      );
    } catch (e) {
      debugPrint('❌ Error al actualizar users_games: $e');
    }
  }

  Future<void> _recordXpHistory(
    String userId,
    int pointsEarned,
    String source,
    String sourceId,
    String sourceName,
    Map<String, dynamic> sourceDetails,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('xp_history').insert({
        'user_id': userId,
        'points_earned': pointsEarned,
        'source': source,
        'source_id': sourceId,
        'source_name': sourceName,
        'source_details': sourceDetails,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
          '✅ Historial de XP registrado: +$pointsEarned XP desde $source');
    } catch (e) {
      debugPrint('❌ Error al registrar historial de XP: $e');
      // No fallar el proceso principal si falla el historial
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono de éxito
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                Text(
                  '¡Excelente!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Mensaje
                Text(
                  'Has completado todas las viñetas de tips',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Info de viñetas completadas
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '${tips.length} ${tips.length == 1 ? "viñeta completada" : "viñetas completadas"}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      if (totalExperience > 0) ...[
                        SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stars, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '¡Ganaste $totalExperience puntos XP!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botón de continuar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      // Guardar puntos de experiencia
                      if (totalExperience > 0) {
                        // Mostrar indicador de carga
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        // Guardar puntos
                        final success = await _saveExperiencePoints();

                        // Cerrar indicador de carga
                        if (mounted) Navigator.of(context).pop();

                        // Verificar conectividad para mensaje apropiado
                        final isOnline = await _checkConnectivity();

                        // Mostrar resultado
                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isOnline
                                      ? '✅ ¡$totalExperience XP guardados!'
                                      : '💾 Puntos guardados. Se sincronizarán al conectarse',
                                ),
                                backgroundColor:
                                    isOnline ? Colors.green : Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Error al guardar puntos'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }

                        // Esperar un momento para que se vea el SnackBar
                        await Future.delayed(Duration(milliseconds: 300));
                      }

                      if (mounted) {
                        Navigator.of(context).pop(); // Cerrar diálogo
                        Navigator.pop(
                            context, true); // Regresar como completado
                      }
                    },
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  // Widget para construir los indicadores de página (dots)
  Widget _buildPageIndicators() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tips.length, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: currentTipIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: currentTipIndex == index
                ? Colors.blue
                : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Cargando tips...',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (tips.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 80, color: Colors.grey[600]),
              SizedBox(height: 16),
              Text(
                'No hay tips disponibles',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final currentTip = tips[currentTipIndex];

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF121212) : Colors.grey[100],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          // Imagen de fondo - con altura limitada y bordes redondeados
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.75,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              child: currentTip['img_url'] != null &&
                      currentTip['img_url'].toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: currentTip['img_url'],
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: Colors.grey[600],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Imagen no disponible',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(
                          Icons.lightbulb,
                          size: 100,
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),

          // Gradiente oscuro sobre la imagen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.95,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),

          // Contenido superpuesto
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta con título y descripción
                    Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[900]!.withOpacity(0.95)
                            : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título con ícono
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentTip['title'] ?? 'Tip',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lightbulb,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          // Descripción con scroll e indicadores dinámicos
                          Stack(
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.15,
                                ),
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  physics: BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 32,
                                      bottom: 32,
                                    ),
                                    child: Text(
                                      currentTip['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDarkMode
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Indicador de scroll superior
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  ignoring: !_showTopArrow,
                                  child: AnimatedOpacity(
                                    opacity: _showTopArrow ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 200),
                                    child: Container(
                                      height: 35,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.transparent,
                                            isDarkMode
                                                ? Colors.grey[900]!
                                                    .withOpacity(0.85)
                                                : Colors.white
                                                    .withOpacity(0.85),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.keyboard_arrow_up,
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black54,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Indicador de scroll inferior
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  ignoring: !_showBottomArrow,
                                  child: AnimatedOpacity(
                                    opacity: _showBottomArrow ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 200),
                                    child: Container(
                                      height: 35,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            isDarkMode
                                                ? Colors.grey[900]!
                                                    .withOpacity(0.85)
                                                : Colors.white
                                                    .withOpacity(0.85),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.black54,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Indicadores de página (dots)
                    Center(child: _buildPageIndicators()),

                    SizedBox(height: 20),

                    // Botón de navegación
                    if (!showCompletionButton) ...[
                      Row(
                        children: [
                          // Botón Anterior (pequeño)
                          if (currentTipIndex > 0)
                            Container(
                              margin: EdgeInsets.only(right: 12),
                              child: Material(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: previousTip,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Botón principal
                          Expanded(
                            child: Material(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: nextTip,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 50,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        currentTipIndex < tips.length - 1
                                            ? 'Siguiente'
                                            : 'Ver resumen',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Botón de Completado
                      Material(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _showCompletionDialog,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Marcar como Completado',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          '✅ Has visto todas las viñetas',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
