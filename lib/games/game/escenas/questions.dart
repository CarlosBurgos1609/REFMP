import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:refmp/games/scens_game/educational_game.dart';
import 'package:refmp/games/game/escenas/tips_page.dart';
import 'package:hive/hive.dart';
import 'package:refmp/services/offline_sync_service.dart';

class QuestionPage extends StatefulWidget {
  final String sublevelId;
  final String sublevelTitle;
  final String sublevelType;

  const QuestionPage({
    super.key,
    required this.sublevelId,
    required this.sublevelTitle,
    required this.sublevelType,
  });

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int incorrectAnswers = 0;
  int totalExperience = 0;
  int videoExperiencePoints = 0; // Puntos específicos para videos
  int gameExperiencePoints = 0; // Puntos específicos para juegos
  int gameCoins = 0; // Monedas configuradas para el juego
  String? gameSongId; // ID de la canción del juego
  String? gameSongName; // Nombre de la canción del juego
  String? gameSongImageUrl; // URL de la imagen de la canción
  String? gameProfileImageUrl; // URL de la imagen de perfil
  String? gameDifficulty; // Dificultad del juego
  String? gameTitle; // Título del juego educativo
  String? gameSheetMusicImageUrl; // URL de la imagen de la partitura
  String? gameBackgroundAudioUrl; // URL del audio de fondo
  bool answered = false;
  bool showSummary = false;
  bool dialogShown =
      false; // Nueva variable para evitar mostrar múltiples diálogos
  String? selectedOption;
  YoutubePlayerController? _youtubeController;
  String? videoUrl;
  bool hasVideoError = false;
  bool _experienceAlreadyProcessed = false;

  // NUEVO: Cache y sincronización offline
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData(); // NUEVO: Método combinado
    if (widget.sublevelType == 'Video') {
      loadVideoUrl();
    } else if (widget.sublevelType == 'Game' ||
        widget.sublevelType == 'Juego') {
      // Ejecutar después de que el widget esté construido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadGameDataAndNavigate();
      });
    } else if (widget.sublevelType == 'Tips' || widget.sublevelType == 'Tip') {
      // Ejecutar después de que el widget esté construido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadTipsAndNavigate();
      });
    }
  }

  // NUEVO: Inicializar servicio y cargar datos
  Future<void> _initializeAndLoadData() async {
    await _syncService.initialize();
    await loadQuestions(); // Carga desde caché primero, luego actualiza

    // Intentar sincronizar datos pendientes en segundo plano
    final isOnline = await _checkConnectivity();
    if (isOnline) {
      _syncService.syncAllPendingData();
    }
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
    // Limpiar el controlador de YouTube cuando el widget se destruye
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> loadQuestions() async {
    final supabase = Supabase.instance.client;
    final box = Hive.box('offline_data');
    final cacheKey = 'questions_${widget.sublevelId}_${widget.sublevelType}';

    try {
      // PRIMERO: Cargar desde caché (inmediato)
      final cachedQuestions = box.get(cacheKey);
      if (cachedQuestions != null) {
        questions = (cachedQuestions as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        debugPrint('💾 Preguntas cargadas desde caché: ${questions.length}');
      }

      // SEGUNDO: Verificar si hay internet y actualizar
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        // Sin internet, quedarse con el caché
        if (questions.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Sin conexión. No hay preguntas disponibles offline.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (mounted) {
          debugPrint(
              '✅ Usando ${questions.length} preguntas desde caché offline');
        }
        return;
      }

      // TERCERO: Hay internet, cargar desde Supabase
      debugPrint('🌐 Actualizando preguntas desde Supabase...');
      List<dynamic> response = [];
      if (widget.sublevelType == 'Quiz') {
        response = await supabase
            .from('quiz')
            .select()
            .eq('sublevel_id', widget.sublevelId);
      } else if (widget.sublevelType == 'Evaluation') {
        response = await supabase
            .from('evaluation')
            .select()
            .eq('sublevel_id', widget.sublevelId);
      }

      if (response.isNotEmpty) {
        // Guardar en caché
        await box.put(cacheKey, response);
        debugPrint('💾 Preguntas actualizadas en caché: ${response.length}');
        questions = List<Map<String, dynamic>>.from(response);
      }

      // Detiene la ejecución si el widget ya no está montado
      if (!mounted) return;

      // Actualiza la interfaz si aún está montado
      setState(() {
        // Aquí puedes actualizar otros valores si es necesario
      });
    } catch (e) {
      print('Error al cargar preguntas: $e');

      // En caso de error, intentar cargar desde caché
      final box = Hive.box('offline_data');
      final cachedQuestions = box.get(cacheKey, defaultValue: []);
      questions = (cachedQuestions as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      // También puedes mostrar un snackbar si lo deseas
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cargadas preguntas desde caché')),
        );
      }
    }
  }

  Future<void> loadVideoUrl() async {
    final supabase = Supabase.instance.client;
    final box = Hive.box('offline_data');
    final cacheKey = 'video_${widget.sublevelId}';

    try {
      debugPrint('🎥 Cargando video para sublevel_id: ${widget.sublevelId}');

      // PRIMERO: Intentar cargar desde caché
      final cachedVideo = box.get(cacheKey);
      if (cachedVideo != null) {
        videoUrl = cachedVideo['video_url'];
        videoExperiencePoints = cachedVideo['experience_points'] ?? 0;
        debugPrint('💾 Video cargado desde caché: $videoUrl');

        // Intentar crear controlador con datos del caché
        String? videoId = _extractYoutubeVideoId(videoUrl!);
        if (videoId != null && videoId.isNotEmpty) {
          _createYoutubeController(videoId);
        }

        if (mounted) setState(() {});
      }

      // SEGUNDO: Verificar conectividad y actualizar si hay internet
      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        debugPrint('📱 Sin conexión para actualizar video');
        if (cachedVideo == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sin conexión. No se puede cargar el video.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // TERCERO: Actualizar desde Supabase si hay conexión
      debugPrint('🌐 Actualizando video desde Supabase...');
      dynamic response;
      try {
        response = await supabase
            .from('video')
            .select('video_url, experience_points')
            .eq('sublevel_id', widget.sublevelId)
            .maybeSingle();
      } catch (e) {
        debugPrint(
            '⚠️ Columna experience_points no existe, cargando solo video_url');
        response = await supabase
            .from('video')
            .select('video_url')
            .eq('sublevel_id', widget.sublevelId)
            .maybeSingle();
      }

      debugPrint('📋 Respuesta de la base de datos: $response');

      if (response != null && response['video_url'] != null) {
        videoUrl = response['video_url'];
        videoExperiencePoints = response['experience_points'] ?? 0;

        // Guardar en caché
        await box.put(cacheKey, {
          'video_url': videoUrl,
          'experience_points': videoExperiencePoints,
        });
        debugPrint('💾 Video guardado en caché');

        debugPrint('🎬 Video URL encontrada: $videoUrl');
        debugPrint('⭐ Puntos de experiencia: $videoExperiencePoints');

        // Extraer video ID y crear controlador
        String? videoId = _extractYoutubeVideoId(videoUrl!);
        debugPrint('🆔 Video ID extraído: $videoId');

        if (videoId != null && videoId.isNotEmpty) {
          _createYoutubeController(videoId);

          // Listener para detectar errores
          _youtubeController!.addListener(() {
            if (_youtubeController!.value.hasError) {
              debugPrint(
                  '❌ Error en video: ${_youtubeController!.value.errorCode}');
              // Dar un tiempo antes de marcar como error para que intente cargar
              Future.delayed(Duration(seconds: 3), () {
                if (mounted &&
                    _youtubeController!.value.hasError &&
                    !hasVideoError) {
                  setState(() {
                    hasVideoError = true;
                  });
                }
              });
            } else if (_youtubeController!.value.isReady &&
                !_youtubeController!.value.hasError) {
              debugPrint('✅ Video listo para reproducir');
              if (hasVideoError && mounted) {
                // Si estaba marcado como error pero ahora funciona, quitamos el error
                setState(() {
                  hasVideoError = false;
                });
              }
            }
          });
        }
      } else {
        debugPrint('⚠️ No se encontró video para este subnivel');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error al cargar el video: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  void _createYoutubeController(String videoId) {
    try {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: false,
          hideControls: false,
          controlsVisibleAtStart: true,
          loop: false,
          isLive: false,
          forceHD: false,
          useHybridComposition: false,
        ),
      );

      // Listener para detectar errores
      _youtubeController!.addListener(() {
        if (_youtubeController!.value.hasError) {
          debugPrint(
              '❌ Error en video: ${_youtubeController!.value.errorCode}');
          Future.delayed(Duration(seconds: 3), () {
            if (mounted &&
                _youtubeController!.value.hasError &&
                !hasVideoError) {
              setState(() {
                hasVideoError = true;
              });
            }
          });
        } else if (_youtubeController!.value.isReady &&
            !_youtubeController!.value.hasError) {
          debugPrint('✅ Video listo para reproducir');
          if (hasVideoError && mounted) {
            setState(() {
              hasVideoError = false;
            });
          }
        }
      });

      debugPrint('✅ Controlador de YouTube creado con ID: $videoId');
    } catch (e) {
      debugPrint('❌ Error al crear controlador: $e');
      hasVideoError = true;
    }
  }

  Future<void> loadTipsAndNavigate() async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('💡 INICIANDO CARGA DE TIPS');
      debugPrint('📋 Sublevel ID: ${widget.sublevelId}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TipsPage(
              sublevelId: widget.sublevelId,
              sublevelTitle: widget.sublevelTitle,
            ),
          ),
        );

        debugPrint('🔙 Regresó de TipsPage con resultado: $result');
        if (mounted) {
          Navigator.pop(context, result ?? false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ ERROR CRÍTICO AL CARGAR TIPS');
      debugPrint('🔴 Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error crítico: $e'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> loadGameDataAndNavigate() async {
    final supabase = Supabase.instance.client;
    final box = Hive.box('offline_data');
    final cacheKey = 'game_${widget.sublevelId}';

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎮 INICIANDO CARGA DE JUEGO EDUCATIVO');
      debugPrint('📋 Sublevel ID: ${widget.sublevelId}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // PRIMERO: Intentar cargar desde caché
      final cachedGame = box.get(cacheKey);
      bool hasCache = cachedGame != null;

      if (hasCache) {
        debugPrint('💾 Juego encontrado en caché');
        gameExperiencePoints = cachedGame['experience_points'] ?? 0;
        gameCoins = cachedGame['coins'] ?? 0;
        gameTitle = cachedGame['title'];
        gameSheetMusicImageUrl = cachedGame['sheet_music_image_url'];
        gameBackgroundAudioUrl = cachedGame['background_audio_url'];

        debugPrint('📊 Datos del caché:');
        debugPrint('   ⭐ XP: $gameExperiencePoints');
        debugPrint('   💰 Monedas: $gameCoins');
        debugPrint('   📜 Título: $gameTitle');
      }

      // SEGUNDO: Verificar conectividad
      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        debugPrint('📱 Sin conexión a internet');
        if (!hasCache) {
          // No hay caché NI conexión
          debugPrint('❌ No hay datos en caché ni conexión');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sin conexión. No se puede cargar el juego.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.pop(context, false);
          }
          return;
        }
        // Si hay caché, continuar con esos datos
        debugPrint('✅ Usando datos del caché offline');
      } else {
        // TERCERO: Actualizar desde Supabase si hay conexión
        debugPrint('🌐 Actualizando desde Supabase...');
        dynamic response;
        try {
          debugPrint('🔍 Consultando tabla "game"...');
          response = await supabase
              .from('game')
              .select(
                  'experience_points, coins, title, sheet_music_image_url, background_audio_url')
              .eq('sublevel_id', widget.sublevelId)
              .maybeSingle();

          debugPrint('📦 Respuesta recibida: $response');
        } catch (e, stackTrace) {
          debugPrint('❌ ERROR AL CONSULTAR BASE DE DATOS');
          debugPrint('🔴 Error: $e');
          debugPrint('📍 Stack trace: $stackTrace');

          // Si hay caché, usar esos datos
          if (hasCache) {
            debugPrint('⚠️ Usando datos del caché por error en Supabase');
          } else {
            // No hay caché ni se pudo obtener de Supabase
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al cargar el juego: $e'),
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.pop(context, false);
            }
            return;
          }
        }

        if (response != null) {
          debugPrint('✅ Datos actualizados desde Supabase');
          gameExperiencePoints = response['experience_points'] ?? 0;
          gameCoins = response['coins'] ?? 0;
          gameTitle = response['title'];
          gameSheetMusicImageUrl = response['sheet_music_image_url'];
          gameBackgroundAudioUrl = response['background_audio_url'];

          // Guardar en caché
          await box.put(cacheKey, {
            'experience_points': gameExperiencePoints,
            'coins': gameCoins,
            'title': gameTitle,
            'sheet_music_image_url': gameSheetMusicImageUrl,
            'background_audio_url': gameBackgroundAudioUrl,
          });
          debugPrint('💾 Juego guardado en caché');
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 DATOS FINALES DEL JUEGO:');
      debugPrint('⭐ Puntos XP: $gameExperiencePoints');
      debugPrint('💰 Monedas: $gameCoins');
      debugPrint('📜 Título: $gameTitle');
      debugPrint('🎼 Partitura URL: $gameSheetMusicImageUrl');
      debugPrint('🔊 Audio URL: $gameBackgroundAudioUrl');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Decidir qué tipo de juego mostrar
      // Si tiene partitura y audio, es un juego educativo
      if (gameSheetMusicImageUrl != null &&
          gameSheetMusicImageUrl!.isNotEmpty) {
        // Juego educativo con partitura
        debugPrint('🎓 TIPO DE JUEGO: Educativo (con partitura)');
        debugPrint('🚀 Navegando a EducationalGamePage...');

        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EducationalGamePage(
                sublevelId: widget.sublevelId,
                title: gameTitle ?? widget.sublevelTitle,
                sheetMusicImageUrl: gameSheetMusicImageUrl,
                backgroundAudioUrl: gameBackgroundAudioUrl,
                experiencePoints: gameExperiencePoints,
                coins: gameCoins,
              ),
            ),
          );

          debugPrint(
              '🔙 Regresó de EducationalGamePage con resultado: $result');
          if (mounted) {
            Navigator.pop(context, result ?? false);
          }
        }
      } else {
        debugPrint('❌ CONFIGURACIÓN INVÁLIDA');
        debugPrint('🔴 No se encontró partitura para el juego educativo');
        debugPrint('📊 Datos recibidos:');
        debugPrint('   - sheet_music_image_url: $gameSheetMusicImageUrl');
        debugPrint('   - background_audio_url: $gameBackgroundAudioUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Configuración del juego incompleta. Verifica los datos.'),
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.pop(context, false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ ERROR CRÍTICO AL CARGAR JUEGO');
      debugPrint('🔴 Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error crítico: $e'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, false);
      }
    }
  }

  // Método para extraer el ID del video de YouTube de diferentes formatos de URL
  String? _extractYoutubeVideoId(String url) {
    try {
      // Intentar con el método estándar de youtube_player_flutter
      String? id = YoutubePlayer.convertUrlToId(url);
      if (id != null && id.isNotEmpty) {
        return id;
      }

      // Patrones adicionales para URLs de YouTube
      final patterns = [
        RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})'),
        RegExp(r'youtube\.com\/embed\/([a-zA-Z0-9_-]{11})'),
        RegExp(r'youtube\.com\/v\/([a-zA-Z0-9_-]{11})'),
        RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})'),
      ];

      for (var pattern in patterns) {
        final match = pattern.firstMatch(url);
        if (match != null && match.groupCount >= 1) {
          return match.group(1);
        }
      }

      // Si la URL es solo el ID (11 caracteres alfanuméricos)
      if (url.length == 11 && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(url)) {
        return url;
      }

      return null;
    } catch (e) {
      debugPrint('Error al extraer video ID: $e');
      return null;
    }
  }

  // Método para abrir el video en YouTube
  Future<void> _openVideoInYouTube() async {
    if (videoUrl == null) return;

    try {
      final uri = Uri.parse(videoUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint('✅ Video abierto en YouTube');
      } else {
        debugPrint('❌ No se puede abrir la URL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se puede abrir YouTube')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error al abrir YouTube: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir el video')),
        );
      }
    }
  }

  void handleAnswer(String option, String correctAnswer, int experience) {
    if (answered) return;

    setState(() {
      answered = true;
      selectedOption = option;
      if (option == correctAnswer) {
        correctAnswers++;
        totalExperience += experience;
      } else {
        incorrectAnswers++;
      }
    });
  }

  void nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        answered = false;
        selectedOption = null;
      });
    } else {
      setState(() {
        showSummary = true;
      });
    }
  }

  Future<void> _saveExperiencePoints() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint('Error: Usuario no autenticado');
        return;
      }

      if (totalExperience <= 0) {
        debugPrint('No hay puntos de experiencia para guardar');
        return;
      }

      debugPrint('Iniciando guardado de puntos de experiencia...');
      debugPrint('Usuario ID: ${user.id}');
      debugPrint('Puntos a guardar: $totalExperience');

      // Verificar si hay conexión a internet
      final isOnline = await _checkConnectivity();
      final source = 'questions_${widget.sublevelType.toLowerCase()}';

      final shouldAward =
          await _shouldAwardExperience(user.id, source, isOnline);
      if (!shouldAward) {
        debugPrint(
            '⏭️ XP omitido: este subnivel ya otorgó experiencia previamente');
        return;
      }

      if (!isOnline) {
        // Modo OFFLINE: Guardar en cola de pendientes
        debugPrint(
            '📱 Sin conexión, guardando puntos para sincronizar después...');

        final coinsEarned = totalExperience ~/ 10; // 1 moneda cada 10 XP

        // Guardar XP pendiente
        await _syncService.savePendingXP(
          userId: user.id,
          points: totalExperience,
          source: source,
          sourceId: widget.sublevelId,
          sourceName: 'Preguntas ${widget.sublevelType}',
          sourceDetails: {
            'total_questions': questions.length,
            'correct_answers': correctAnswers,
            'total_experience': totalExperience,
            'coins_earned': coinsEarned,
          },
        );

        // Guardar monedas pendientes
        await _syncService.savePendingCoins(
          userId: user.id,
          coins: coinsEarned,
          source: source,
        );

        await _markExperienceAsAwarded(user.id, source);

        debugPrint('💾 Puntos guardados para sincronizar cuando haya conexión');
        debugPrint('   XP pendientes: +$totalExperience');
        debugPrint('   Monedas pendientes: +$coinsEarned');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Puntos guardados. Se sincronizarán al conectarse'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Modo ONLINE: Guardar directamente en Supabase
      debugPrint('🌐 Conexión disponible, guardando puntos online...');

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

            // Actualizar puntos de experiencia en tabla de perfil
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

      // 3. Registrar en historial para que la gráfica semanal sea exacta
      await _recordXpHistory(
        user.id,
        totalExperience,
        source,
        widget.sublevelId,
        widget.sublevelTitle,
        {
          'total_questions': questions.length,
          'correct_answers': correctAnswers,
          'incorrect_answers': incorrectAnswers,
          'total_experience': totalExperience,
          'coins_earned': totalExperience ~/ 10,
          'sublevel_type': widget.sublevelType,
        },
      );

      await _markExperienceAsAwarded(user.id, source);

      debugPrint('✅ Guardado de puntos completado exitosamente');
    } catch (e) {
      debugPrint('❌ Error crítico al guardar puntos de experiencia: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  String _xpAwardCacheKey(String userId, String source) {
    return 'xp_awarded_${source}_${widget.sublevelId}_$userId';
  }

  Future<bool> _shouldAwardExperience(
      String userId, String source, bool isOnline) async {
    if (_experienceAlreadyProcessed) return false;
    final supabase = Supabase.instance.client;

    final box = Hive.box('offline_data');
    final cacheKey = _xpAwardCacheKey(userId, source);
    final alreadyAwardedInCache =
        box.get(cacheKey, defaultValue: false) == true;
    if (alreadyAwardedInCache) {
      _experienceAlreadyProcessed = true;
      return false;
    }

    if (isOnline) {
      final completedRecord = await supabase
          .from('users_sublevels')
          .select('completed')
          .eq('user_id', userId)
          .eq('sublevel_id', widget.sublevelId)
          .eq('completed', true)
          .maybeSingle();

      if (completedRecord != null) {
        await box.put(cacheKey, true);
        _experienceAlreadyProcessed = true;
        return false;
      }

      final historyRecord = await supabase
          .from('xp_history')
          .select('id')
          .eq('user_id', userId)
          .eq('source', source)
          .eq('source_id', widget.sublevelId)
          .limit(1)
          .maybeSingle();

      if (historyRecord != null) {
        await box.put(cacheKey, true);
        _experienceAlreadyProcessed = true;
        return false;
      }
    }

    return true;
  }

  Future<void> _markExperienceAsAwarded(String userId, String source) async {
    final box = Hive.box('offline_data');
    await box.put(_xpAwardCacheKey(userId, source), true);
    _experienceAlreadyProcessed = true;
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
    } catch (e) {
      debugPrint('❌ Error al registrar historial de XP (questions): $e');
    }
  }

  Future<void> _updateUserGamePoints() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null || totalExperience <= 0) return;

      debugPrint('Actualizando puntos para usuario: ${user.id}');
      debugPrint('Puntos a agregar: $totalExperience');

      // Verificar si el usuario ya tiene registro en users_games
      final existingRecord = await supabase
          .from('users_games')
          .select('points_xp_totally, points_xp_weekend, coins')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingRecord != null) {
        // Actualizar registro existente
        final currentTotal = existingRecord['points_xp_totally'] ?? 0;
        final currentWeekend = existingRecord['points_xp_weekend'] ?? 0;
        final currentCoins = existingRecord['coins'] ?? 0;

        final newTotal = currentTotal + totalExperience;
        final newWeekend = currentWeekend + totalExperience;
        final newCoins =
            currentCoins + (totalExperience ~/ 10); // 1 moneda cada 10 XP

        final updateResult = await supabase.from('users_games').update({
          'points_xp_totally': newTotal,
          'points_xp_weekend': newWeekend,
          'coins': newCoins,
        }).eq('user_id', user.id);

        debugPrint('Resultado de actualización: $updateResult');
        debugPrint('Puntos actualizados en users_games:');
        debugPrint('  - XP agregados: +$totalExperience');
        debugPrint('  - Total XP: $newTotal');
        debugPrint('  - XP semanal: $newWeekend');
        debugPrint('  - Monedas: $newCoins (+${totalExperience ~/ 10})');
      } else {
        // Crear nuevo registro si no existe
        final newCoins = totalExperience ~/ 10;

        final insertResult = await supabase.from('users_games').insert({
          'user_id': user.id,
          'nickname': 'Usuario', // Valor por defecto
          'points_xp_totally': totalExperience,
          'points_xp_weekend': totalExperience,
          'coins': newCoins,
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('Resultado de inserción: $insertResult');
        debugPrint('Nuevo registro creado en users_games:');
        debugPrint('  - XP total: $totalExperience');
        debugPrint('  - XP semanal: $totalExperience');
        debugPrint('  - Monedas: $newCoins');
      }
    } catch (e) {
      debugPrint('Error al actualizar users_games: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text(
                '¿Completaste el video?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antes de marcar como completado, asegúrate de que:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              _buildCheckItem('✅ Viste todo el video completo'),
              _buildCheckItem('✅ Entendiste el contenido'),
              _buildCheckItem('✅ Estás listo para continuar'),
              if (videoExperiencePoints > 0) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '¡Ganarás $videoExperiencePoints puntos XP!',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Guardar puntos de experiencia del video si los tiene
                if (videoExperiencePoints > 0) {
                  totalExperience = videoExperiencePoints;
                  await _saveExperiencePoints();
                }

                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.pop(
                    context, true); // Marcar como completado y regresar
              },
              child: Text(
                'Sí, completado',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCongratulationsDialog() {
    // Verificar que el widget aún esté montado antes de mostrar el diálogo
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
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

                // Título de felicitaciones
                Text(
                  '¡Felicitaciones!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtítulo
                Text(
                  'Has completado el quiz exitosamente',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Resultados
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Respuestas correctas:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$correctAnswers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Respuestas incorrectas:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '$incorrectAnswers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[600],
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

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        onPressed: () async {
                          // Guardar puntos y regresar
                          if (correctAnswers > 0) {
                            await _saveExperiencePoints();
                          }
                          if (mounted) {
                            Navigator.of(context).pop(); // Cerrar diálogo
                            Navigator.pop(context, correctAnswers > 0);
                          }
                        },
                        child: Text(
                          'Atrás',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          // Guardar puntos y continuar
                          if (correctAnswers > 0) {
                            await _saveExperiencePoints();
                          }
                          if (mounted) {
                            Navigator.of(context).pop(); // Cerrar diálogo
                            Navigator.pop(context, correctAnswers > 0);
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (showSummary) {
      // Mostrar diálogo de felicitaciones solo una vez
      if (!dialogShown) {
        dialogShown = true;
        // Usar Future.microtask en lugar de addPostFrameCallback para evitar problemas de contexto
        Future.microtask(() {
          if (mounted) {
            _showCongratulationsDialog();
          }
        });
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Resumen',
            style: TextStyle(
                color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () async {
              // Guardar puntos de experiencia si completó exitosamente
              if (correctAnswers > 0) {
                await _saveExperiencePoints();
              }
              // Retornar true si completó al menos una pregunta correctamente
              Navigator.pop(context,
                  correctAnswers > 0 || widget.sublevelType == 'Video');
            },
          ),
          centerTitle: true,
        ),
        body: Container(), // Pantalla vacía porque se mostrará el diálogo
      );
    }
    if (widget.sublevelType == 'Video') {
      // Mostrar loading mientras se carga la información del video
      if (videoUrl == null) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.sublevelTitle,
              style: const TextStyle(color: Colors.blue),
            ),
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
              onPressed: () => Navigator.pop(context, false),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  'Cargando video...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Mostrar reproductor o pantalla alternativa
      if (videoUrl != null) {
        // Si hay error o no hay controlador, mostrar opción de YouTube
        if (hasVideoError || _youtubeController == null) {
          final videoId = _extractYoutubeVideoId(videoUrl!);
          final thumbnailUrl = videoId != null
              ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
              : null;

          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.sublevelTitle,
                style: const TextStyle(color: Colors.blue),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.blue),
                onPressed: () => Navigator.pop(context, false),
              ),
              centerTitle: true,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Alerta de video restringido
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange[700], size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este video no puede reproducirse aquí. Ábrelo en YouTube.',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Miniatura del video
                    if (thumbnailUrl != null)
                      GestureDetector(
                        onTap: _openVideoInYouTube,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  thumbnailUrl,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: 220,
                                      color: Colors.grey[300],
                                      child: Icon(
                                        Icons.video_library,
                                        size: 80,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: double.infinity,
                                      height: 220,
                                      color: Colors.grey[200],
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Botón de play grande sobre la miniatura
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(20),
                              child: Icon(
                                Icons.play_arrow,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),

                    // Botón principal para abrir YouTube
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _openVideoInYouTube,
                        icon: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 32,
                        ),
                        label: Text(
                          'Ver Video en YouTube',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tarjeta informativa
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '¡Aprende con este video!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              '1. Toca el botón rojo para abrir el video en YouTube\n'
                              '2. Mira el video completo y aprende el contenido\n'
                              '3. Regresa aquí y marca como completado',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                            if (videoExperiencePoints > 0) ...[
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.amber[300]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.stars,
                                        color: Colors.amber[700], size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      '¡Gana $videoExperiencePoints XP!',
                                      style: TextStyle(
                                        color: Colors.amber[900],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón de completado
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _showCompletionDialog,
                        icon: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 26,
                        ),
                        label: Text(
                          'Marcar como Completado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Recuerda ver el video completo antes de marcar como completado',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mostrar reproductor de YouTube embebido
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.sublevelTitle,
              style: const TextStyle(color: Colors.blue),
            ),
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
              onPressed: () => Navigator.pop(context, false),
            ),
            centerTitle: true,
          ),
          body: YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
                bufferedColor: Colors.grey[300]!,
                backgroundColor: Colors.grey[600]!,
              ),
              onReady: () {
                debugPrint('🎬 Video listo - presiona play para reproducir');
              },
              onEnded: (metaData) {
                debugPrint('✅ Video completado');
              },
            ),
            builder: (context, player) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Reproductor de video
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: player,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mensaje de ayuda si el video no se reproduce
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue[700], size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '¿No se reproduce? Usa el botón "Abrir en YouTube"',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón para abrir en YouTube (por si hay problemas)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          side: BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _openVideoInYouTube,
                        icon: Icon(Icons.open_in_new, color: Colors.red),
                        label: Text(
                          'Abrir en YouTube',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tarjeta informativa
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_filled,
                                    color: Colors.blue,
                                    size: 32,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '¡Mira el video completo!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Presiona el botón ▶️ en el video para comenzar. '
                                'Si no se reproduce, usa el botón "Abrir en YouTube".',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                              if (videoExperiencePoints > 0) ...[
                                SizedBox(height: 14),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.amber[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.stars,
                                          color: Colors.amber[700], size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        '¡Gana $videoExperiencePoints XP!',
                                        style: TextStyle(
                                          color: Colors.amber[900],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón de completado
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          onPressed: _showCompletionDialog,
                          icon: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          label: Text(
                            'Marcar como Completado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '💡 Asegúrate de ver el video completo antes de marcar como completado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }

// Si es tipo Game, Juego o Tips, la navegación se maneja en initState
    // No debería llegar aquí, pero por si acaso mostramos loading
    if (widget.sublevelType == 'Game' ||
        widget.sublevelType == 'Juego' ||
        widget.sublevelType == 'Tips' ||
        widget.sublevelType == 'Tip') {
      String loadingMessage = 'Cargando';
      if (widget.sublevelType == 'Tips' || widget.sublevelType == 'Tip') {
        loadingMessage = 'Cargando tips...';
      } else {
        loadingMessage = 'Cargando juego...';
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.sublevelTitle,
            style: const TextStyle(color: Colors.blue),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () => Navigator.pop(context, false),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 16),
              Text(
                loadingMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.sublevelTitle,
            style: TextStyle(
                color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () => Navigator.pop(
                context, false), // No completado si sale durante carga
          ),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.blue,
          ),
        ),
      );
    }

    final question = questions[currentQuestionIndex];
    final options = [
      question['option_a'],
      question['option_b'],
      question['option_c'],
      question['option_d'],
    ];
    final correctAnswer = question['correct_answer'];
    final experience = question['experience_points'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sublevelTitle,
          style: TextStyle(
              color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
          onPressed: () => Navigator.pop(
              context, false), // No completado si sale durante quiz
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              // Reemplaza este fragmento dentro del método build
              Card(
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question['image_url'] != null &&
                        question['image_url'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: question['image_url'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[300],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported,
                                    size: 50, color: Colors.grey[600]),
                                SizedBox(height: 8),
                                Text('Imagen no disponible',
                                    style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        question['question_text'],
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.sublevelType == 'Evaluation'
                                ? Colors.white
                                : Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              Column(
                children: List.generate(options.length, (index) {
                  final optionText = options[index];
                  final isCorrect = optionText == correctAnswer;
                  final isSelected = optionText == selectedOption;

                  Color backgroundColor = themeProvider.isDarkMode
                      ? const Color.fromARGB(255, 34, 34, 34)
                      : Colors.white;
                  if (answered) {
                    if (isCorrect) {
                      backgroundColor = themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 27, 226, 20)
                          : const Color.fromARGB(255, 69, 236, 74)
                              .withOpacity(0.3);
                    } else if (isSelected) {
                      backgroundColor = themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 236, 6, 6)
                          : const Color.fromARGB(255, 245, 34, 19)
                              .withOpacity(0.3);
                    }
                  }

                  return GestureDetector(
                    onTap: !answered && optionText != null
                        ? () =>
                            handleAnswer(optionText!, correctAnswer, experience)
                        : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      width: double.infinity,
                      child: Text(
                        optionText ?? '',
                        style: TextStyle(
                          fontSize: 17,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              ),

              if (answered)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: nextQuestion,
                      child: Text(
                        currentQuestionIndex < questions.length - 1
                            ? 'Siguiente'
                            : 'Finalizar',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
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
