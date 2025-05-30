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
  bool answered = false;
  bool showSummary = false;
  String? selectedOption;
  YoutubePlayerController? _youtubeController;
  String? videoUrl;

  @override
  void initState() {
    super.initState();
    loadQuestions();
    if (widget.sublevelType == 'Video') {
      loadVideoUrl(); // Nueva función
    }
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
      } else

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
      final response = await supabase
          .from('video')
          .select('video_url')
          .eq('sublevel_id', widget.sublevelId)
          .maybeSingle();

      if (response != null && response['video_url'] != null) {
        videoUrl = response['video_url'];

        final videoId = YoutubePlayer.convertUrlToId(videoUrl!);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
            ),
          );
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error al cargar el video: $e');
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (widget.sublevelType == 'Video' && _youtubeController != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.sublevelTitle,
            style: TextStyle(
                color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
        ),
        body: YoutubePlayerBuilder(
          player: YoutubePlayer(controller: _youtubeController!),
          builder: (context, player) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                player,
                const SizedBox(height: 20),
                Text(
                  'Observa el video y aprende sobre este subnivel.',
                  style: const TextStyle(fontSize: 18, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (showSummary) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Resumen',
            style: TextStyle(
                color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('¡Has finalizado!',
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
              SizedBox(height: 16),
              Text(
                'Correctas: $correctAnswers',
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Incorrectas: $incorrectAnswers',
                style: TextStyle(
                  color: Colors.red.shade900.withOpacity(0.6),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Puntos de Experiencia ganados: $totalExperience',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Volver',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.sublevelType == 'Video' && _youtubeController != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.sublevelTitle,
            style: const TextStyle(color: Colors.blue),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
        ),
        body: YoutubePlayerBuilder(
          player: YoutubePlayer(controller: _youtubeController!),
          builder: (context, player) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                player,
                const SizedBox(height: 20),
                const Text(
                  'Observa el video y aprende sobre este Nivel.',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
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
                  onPressed: () => Navigator.pop(context),
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
            onPressed: () => Navigator.pop(context),
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
          onPressed: () => Navigator.pop(context),
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
