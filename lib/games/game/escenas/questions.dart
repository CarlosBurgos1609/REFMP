import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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
  bool answered = false;
  bool showSummary = false;
  bool dialogShown =
      false; // Nueva variable para evitar mostrar múltiples diálogos
  String? selectedOption;
  YoutubePlayerController? _youtubeController;
  String? videoUrl;

  @override
  void initState() {
    super.initState();
    loadQuestions();
    if (widget.sublevelType == 'Video') {
      loadVideoUrl();
    } else if (widget.sublevelType == 'Game') {
      loadGameExperiencePoints();
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

    try {
      if (widget.sublevelType == 'Quiz') {
        final response = await supabase
            .from('quiz')
            .select()
            .eq('sublevel_id', widget.sublevelId);

        questions = List<Map<String, dynamic>>.from(response);
      } else if (widget.sublevelType == 'Evaluation') {
        final response = await supabase
            .from('evaluation')
            .select()
            .eq('sublevel_id', widget.sublevelId);

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
      // También puedes mostrar un snackbar si lo deseas
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar preguntas')),
        );
      }
    }
  }

  Future<void> loadVideoUrl() async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint('🎥 Cargando video para sublevel_id: ${widget.sublevelId}');

      // Primero intentar con experience_points, si falla, solo video_url
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
        // Solo asignar puntos si la columna existe en la respuesta
        videoExperiencePoints = response['experience_points'] ?? 0;

        debugPrint('🎬 Video URL encontrada: $videoUrl');
        debugPrint('⭐ Puntos de experiencia: $videoExperiencePoints');

        final videoId = YoutubePlayer.convertUrlToId(videoUrl!);
        debugPrint('🆔 Video ID extraído: $videoId');

        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
            ),
          );
          debugPrint('✅ Controlador de YouTube creado exitosamente');
        } else {
          debugPrint(
              '❌ No se pudo extraer el ID del video de la URL: $videoUrl');
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

  Future<void> loadGameExperiencePoints() async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint(
          '🎮 Cargando puntos del juego para sublevel_id: ${widget.sublevelId}');

      // Intentar cargar puntos, si la columna no existe, asignar 0
      dynamic response;
      try {
        response = await supabase
            .from('game')
            .select('experience_points')
            .eq('sublevel_id', widget.sublevelId)
            .maybeSingle();
      } catch (e) {
        debugPrint(
            '⚠️ Columna experience_points no existe en tabla game o no hay registro');
        gameExperiencePoints = 0;
        return;
      }

      if (response != null) {
        gameExperiencePoints = response['experience_points'] ?? 0;
        debugPrint('🎮 Puntos de experiencia del juego: $gameExperiencePoints');
      } else {
        debugPrint('⚠️ No se encontró juego para este subnivel');
        gameExperiencePoints = 0;
      }
    } catch (e) {
      debugPrint('❌ Error al cargar puntos del juego: $e');
      gameExperiencePoints = 0;
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

      debugPrint('✅ Guardado de puntos completado exitosamente');
    } catch (e) {
      debugPrint('❌ Error crítico al guardar puntos de experiencia: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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
      // Mostrar loading mientras se carga el video
      if (_youtubeController == null && videoUrl == null) {
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

      // Mostrar error si no se encontró video
      if (videoUrl != null && _youtubeController == null) {
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
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                SizedBox(height: 16),
                Text(
                  'Error al cargar el video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'URL del video: $videoUrl',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Reintentar cargar el video
                    loadVideoUrl();
                  },
                  child: Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }

      // Mostrar el video cuando esté listo
      if (_youtubeController != null) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.sublevelTitle,
              style: const TextStyle(color: Colors.blue),
            ),
            leading: IconButton(
              icon:
                  const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
              onPressed: () => Navigator.pop(
                  context, false), // No completado si sale sin marcar
            ),
            centerTitle: true,
          ),
          body: YoutubePlayerBuilder(
            player: YoutubePlayer(controller: _youtubeController!),
            builder: (context, player) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  player,
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 48,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '¡Observa el video completo!',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Aprende sobre este tema y cuando termines, marca como completado para continuar.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: () {
                        // Mostrar diálogo de confirmación
                        _showCompletionDialog();
                      },
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 24,
                      ),
                      label: const Text(
                        'Marcar como Completado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '💡 Tip: Asegúrate de haber visto todo el video antes de marcarlo como completado',
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
          ),
        );
      }
    }

// 👉 NUEVO: Para tipo "Game"
    if (widget.sublevelType == 'Juego') {
      return Scaffold(
        body: Transform.rotate(
          angle: 33, // Gira todo 180°
          child: SafeArea(
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Identifica las partes de la trompeta',
                  style: TextStyle(color: Colors.blue),
                ),
                centerTitle: true,
                backgroundColor: Colors.white,
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.blue),
                  onPressed: () => Navigator.pop(
                      context, false), // No completado si sale sin terminar
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/partitura1.png',
                      width: 400,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/piston.png',
                            width: 70, height: 70),
                        const SizedBox(width: 20),
                        Image.asset('assets/images/piston.png',
                            width: 70, height: 70),
                        const SizedBox(width: 20),
                        Image.asset('assets/images/piston.png',
                            width: 70, height: 70),
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (gameExperiencePoints > 0) ...[
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stars, color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '¡Completa y gana $gameExperiencePoints puntos XP!',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        // Guardar puntos de experiencia del juego si los tiene
                        if (gameExperiencePoints > 0) {
                          totalExperience = gameExperiencePoints;
                          await _saveExperiencePoints();
                        }

                        // Marcar juego como completado
                        Navigator.pop(context, true);
                      },
                      child: const Text(
                        'Completar Juego',
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
                        child: Image.network(
                          question['image_url'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Text('Error al cargar la imagen'),
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
