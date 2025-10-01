import 'package:flutter/material.dart';
import 'package:refmp/games/game/escenas/questions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubnivelesPage extends StatefulWidget {
  final String levelId;
  final String levelTitle;

  const SubnivelesPage(
      {super.key, required this.levelId, required this.levelTitle});

  @override
  State<SubnivelesPage> createState() => _SubnivelesPageState();
}

class _SubnivelesPageState extends State<SubnivelesPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> subniveles = [];
  bool isLoading = true;
  Map<String, bool> sublevelCompletionStatus = {};
  double overallProgress = 0.0;

  @override
  void initState() {
    super.initState();
    fetchSubniveles();
  }

  Future<void> fetchSubniveles() async {
    try {
      final response = await supabase
          .from('sublevels')
          .select()
          .eq('level_id', widget.levelId)
          .order('order_number', ascending: true)
          .limit(50);

      setState(() {
        subniveles = response;
      });

      // Fetch completion status after getting sublevels
      await _fetchCompletionStatus();
    } catch (e) {
      debugPrint('Error al obtener subniveles: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Verificar si un subnivel está desbloqueado
  bool _isSublevelUnlocked(int index) {
    // El primer subnivel siempre está desbloqueado
    if (index == 0) return true;

    // Los demás subniveles requieren que el anterior esté completado
    if (index > 0 && index < subniveles.length) {
      final previousSublevel = subniveles[index - 1];
      final previousSublevelId = previousSublevel['id'];
      final isPreviousCompleted =
          sublevelCompletionStatus[previousSublevelId.toString()] ?? false;
      return isPreviousCompleted;
    }

    return false;
  }

  Future<void> _fetchCompletionStatus() async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      // Get completed sublevels for this user
      final response = await supabase
          .from('users_sublevels')
          .select('sublevel_id, completed')
          .eq('user_id', userId)
          .eq('level_id', widget.levelId);

      Map<String, bool> completionMap = {};
      int completedCount = 0;

      for (var sublevel in subniveles) {
        final sublevelId = sublevel['id'];
        final completion = response
                .where((item) => item['sublevel_id'] == sublevelId)
                .isNotEmpty
            ? response.firstWhere((item) => item['sublevel_id'] == sublevelId)
            : <String, dynamic>{};

        bool isCompleted =
            completion.isNotEmpty && completion['completed'] == true;
        completionMap[sublevelId.toString()] = isCompleted;
        if (isCompleted) completedCount++;
      }

      setState(() {
        sublevelCompletionStatus = completionMap;
        overallProgress =
            subniveles.isNotEmpty ? completedCount / subniveles.length : 0.0;
      });
    } catch (e) {
      print('Error fetching completion status: $e');
    }
  }

  Future<void> _markSublevelCompleted(dynamic sublevelIdParam) async {
    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      // Use sublevelId as String (UUID)
      final sublevelId = sublevelIdParam.toString();

      // Check if record already exists
      final existingRecord = await supabase
          .from('users_sublevels')
          .select('*')
          .eq('user_id', userId)
          .eq('level_id', widget.levelId)
          .eq('sublevel_id', sublevelId);

      if (existingRecord.isEmpty) {
        // Insert new record
        await supabase.from('users_sublevels').insert({
          'user_id': userId,
          'level_id': widget.levelId,
          'sublevel_id': sublevelId,
          'completed': true,
          'completion_date': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing record
        await supabase
            .from('users_sublevels')
            .update({
              'completed': true,
              'completion_date': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('level_id', widget.levelId)
            .eq('sublevel_id', sublevelId);
      }

      // Refresh completion status
      await _fetchCompletionStatus();

      print('Sublevel $sublevelId marked as completed');
    } catch (e) {
      print('Error marking sublevel as completed: $e');
    }
  }

  void _showLockedDialog(int index) {
    final previousIndex = index - 1;
    final previousTitle =
        previousIndex >= 0 && previousIndex < subniveles.length
            ? subniveles[previousIndex]['title'] ?? 'Sin título'
            : 'el anterior';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text(
                'Subnivel Bloqueado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              Text(
                'Para acceder a este subnivel, primero debes completar:',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '"$previousTitle"',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Entendido',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _canAddEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final user = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (user != null) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          widget.levelTitle,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canAddEvent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(); // o un indicador de carga pequeño
          }

          if (snapshot.hasData && snapshot.data == true) {
            return FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => SongsFormPage()),
                // );
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          } else {
            return const SizedBox(); // no mostrar nada si no tiene permiso
          }
        },
      ),
      body: RefreshIndicator(
        color: Colors.blue, // Indicador azul
        onRefresh: fetchSubniveles, // Método de recarga
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                color: Colors.blue,
              ))
            : Column(
                children: [
                  // Progress bar at the top
                  if (subniveles.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progreso del nivel: ${(overallProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: overallProgress,
                            backgroundColor: Colors.grey[300],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                  // Sublevels list
                  Expanded(
                    child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: subniveles.length,
                        itemBuilder: (context, index) {
                          final subnivel = subniveles[index];
                          final sublevelId = subnivel['id'];
                          final isCompleted =
                              sublevelCompletionStatus[sublevelId.toString()] ??
                                  false;
                          final isUnlocked = _isSublevelUnlocked(index);

                          return InkWell(
                            onTap: isUnlocked
                                ? () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuestionPage(
                                          sublevelId: subnivel['id'].toString(),
                                          sublevelTitle:
                                              subnivel['title'] ?? 'Sin título',
                                          sublevelType: subnivel['type'],
                                        ),
                                      ),
                                    );

                                    // If the user completed the sublevel, mark it as completed
                                    if (result == true) {
                                      await _markSublevelCompleted(
                                          subnivel['id'].toString());
                                    }
                                  }
                                : () {
                                    // Mostrar mensaje de subnivel bloqueado
                                    _showLockedDialog(index);
                                  },
                            child: Card(
                              margin: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                              color: !isUnlocked ? Colors.grey[200] : null,
                              child: Stack(
                                children: [
                                  // Contenido principal
                                  Opacity(
                                    opacity: !isUnlocked ? 0.6 : 1.0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (subnivel['image'] != null &&
                                            subnivel['image']
                                                .toString()
                                                .isNotEmpty)
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(12)),
                                            child: ColorFiltered(
                                              colorFilter: !isUnlocked
                                                  ? ColorFilter.mode(
                                                      Colors.grey,
                                                      BlendMode.saturation,
                                                    )
                                                  : ColorFilter.mode(
                                                      Colors.transparent,
                                                      BlendMode.multiply,
                                                    ),
                                              child: Image.network(
                                                subnivel['image'],
                                                width: double.infinity,
                                                height: 180,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox(
                                                  height: 180,
                                                  child: Center(
                                                      child: Icon(
                                                          Icons.broken_image)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      subnivel['title'] ??
                                                          'Sin título',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: !isUnlocked
                                                            ? Colors.grey[600]
                                                            : (isCompleted
                                                                ? Colors.green
                                                                : Colors.blue),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isCompleted && isUnlocked)
                                                    Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 24,
                                                    )
                                                  else if (!isUnlocked)
                                                    Icon(
                                                      Icons.lock,
                                                      color: Colors.grey[600],
                                                      size: 24,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                !isUnlocked
                                                    ? 'Completa el subnivel anterior para desbloquear'
                                                    : (subnivel[
                                                            'description'] ??
                                                        ''),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: !isUnlocked
                                                      ? Colors.grey[600]
                                                      : null,
                                                  fontStyle: !isUnlocked
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Chip(
                                                    label: Text(
                                                      'Tipo: ${subnivel['type'] ?? 'N/A'}',
                                                      style: TextStyle(
                                                          color: Colors.white),
                                                    ),
                                                    backgroundColor: !isUnlocked
                                                        ? Colors.grey[400]
                                                        : Colors.blue.shade200,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isCompleted && isUnlocked)
                                                    Chip(
                                                      label: Text(
                                                        'Completado',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      backgroundColor:
                                                          Colors.green.shade400,
                                                    )
                                                  else if (!isUnlocked)
                                                    Chip(
                                                      label: Text(
                                                        'Bloqueado',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      backgroundColor:
                                                          Colors.grey.shade500,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Overlay para elementos completados
                                  if (isCompleted && isUnlocked)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.green.withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  // Overlay para elementos bloqueados
                                  if (!isUnlocked)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.lock_outline,
                                                size: 48,
                                                color: Colors.grey[700],
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Bloqueado',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ),
      ),
    );
  }
}
