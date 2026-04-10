import 'dart:io';
import 'package:flutter/material.dart';
import 'package:refmp/games/game/escenas/questions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:refmp/services/offline_sync_service.dart'; // NUEVO

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
  bool _isOnline = false;
  late Box _hiveBox;
  final OfflineSyncService _syncService = OfflineSyncService(); // NUEVO
  Map<String, dynamic>? _levelData;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _syncService
        .initialize(); // NUEVO: Inicializar servicio de sincronización
    _hiveBox = await Hive.openBox('offline_data');

    // NUEVO: Intentar sincronizar datos pendientes al iniciar
    if (await isOnline()) {
      await _syncService.syncAllPendingData();
    }

    await _fetchLevelData();
    await fetchSubniveles();
  }

  Future<String?> _downloadAndCacheLevelImage(
      String imageUrl, String cacheKey) async {
    try {
      final cachedData = _hiveBox.get(cacheKey);
      if (cachedData is Map) {
        final cachedPath = cachedData['path']?.toString();
        final cachedUrl = cachedData['url']?.toString();
        if (cachedPath != null &&
            cachedUrl == imageUrl &&
            File(cachedPath).existsSync()) {
          return cachedPath;
        }
      }

      final fileInfo = await DefaultCacheManager().downloadFile(imageUrl);
      final localPath = fileInfo.file.path;
      await _hiveBox.put(cacheKey, {
        'url': imageUrl,
        'path': localPath,
      });
      return localPath;
    } catch (e) {
      debugPrint('Error al cachear imagen del nivel: $e');
      return null;
    }
  }

  Future<void> _fetchLevelData() async {
    final detailsCacheKey = 'level_details_${widget.levelId}';
    final imageCacheKey = 'level_image_${widget.levelId}';
    final isConnected = await isOnline();

    try {
      if (isConnected) {
        final response = await supabase
            .from('levels')
            .select('id, name, description, image, number')
            .eq('id', widget.levelId)
            .maybeSingle();

        if (response != null) {
          final levelMap = Map<String, dynamic>.from(response);
          final imageUrl = levelMap['image']?.toString();

          if (imageUrl != null && imageUrl.isNotEmpty) {
            final localPath =
                await _downloadAndCacheLevelImage(imageUrl, imageCacheKey);
            if (localPath != null) {
              levelMap['local_image_path'] = localPath;
            }
          }

          await _hiveBox.put(detailsCacheKey, levelMap);
          if (!mounted) return;
          setState(() {
            _levelData = levelMap;
          });
          return;
        }
      }

      final cachedLevel = _hiveBox.get(detailsCacheKey);
      if (cachedLevel != null) {
        if (!mounted) return;
        setState(() {
          _levelData = Map<String, dynamic>.from(cachedLevel);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del nivel: $e');
      final cachedLevel = _hiveBox.get(detailsCacheKey);
      if (cachedLevel != null && mounted) {
        setState(() {
          _levelData = Map<String, dynamic>.from(cachedLevel);
        });
      }
    }
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  Future<void> fetchSubniveles() async {
    final cacheKey = 'sublevels_${widget.levelId}';
    _isOnline = await isOnline();

    try {
      if (_isOnline) {
        // Cargar desde Supabase
        debugPrint('🌐 Cargando subniveles ONLINE');
        final response = await supabase
            .from('sublevels')
            .select()
            .eq('level_id', widget.levelId)
            .order('order_number', ascending: true)
            .limit(50);

        // Guardar en cache
        await _hiveBox.put(cacheKey, response);
        debugPrint('💾 Subniveles guardados en cache: ${response.length}');

        setState(() {
          subniveles = response;
        });
      } else {
        // Cargar desde cache
        debugPrint('📱 Sin conexión, cargando desde cache');
        final cachedData = _hiveBox.get(cacheKey, defaultValue: []);
        setState(() {
          subniveles = cachedData ?? [];
        });
        debugPrint('💾 Subniveles cargados desde cache: ${subniveles.length}');
      }

      // Fetch completion status after getting sublevels
      await _fetchCompletionStatus();
    } catch (e) {
      debugPrint('❌ Error al obtener subniveles: $e');
      // En caso de error, intentar cargar desde cache
      final cachedData = _hiveBox.get(cacheKey, defaultValue: []);
      setState(() {
        subniveles = cachedData ?? [];
      });
      debugPrint(
          '💾 Cargados ${subniveles.length} subniveles desde cache (error)');
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final cacheKey = 'completion_status_${userId}_${widget.levelId}';

    try {
      if (_isOnline) {
        // Get completed sublevels from Supabase
        debugPrint('🌐 Cargando estado de completación ONLINE');
        final response = await supabase
            .from('users_sublevels')
            .select('sublevel_id, completed')
            .eq('user_id', userId)
            .eq('level_id', widget.levelId);

        // Guardar en cache
        await _hiveBox.put(cacheKey, response);
        debugPrint('💾 Estado de completación guardado en cache');

        _processCompletionData(response);
      } else {
        // Cargar desde cache
        debugPrint('📱 Cargando estado de completación desde cache');
        final cachedData = _hiveBox.get(cacheKey, defaultValue: []);
        _processCompletionData(cachedData ?? []);
      }
    } catch (e) {
      debugPrint('❌ Error fetching completion status: $e');
      // En caso de error, intentar cargar desde cache
      final cachedData = _hiveBox.get(cacheKey, defaultValue: []);
      _processCompletionData(cachedData ?? []);
    }
  }

  void _processCompletionData(List<dynamic> response) {
    Map<String, bool> completionMap = {};
    int completedCount = 0;

    for (var sublevel in subniveles) {
      final sublevelId = sublevel['id'];
      final completion =
          response.where((item) => item['sublevel_id'] == sublevelId).isNotEmpty
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
  }

  Future<void> _markSublevelCompleted(dynamic sublevelIdParam) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final sublevelId = sublevelIdParam.toString();
    final cacheKey = 'completion_status_${userId}_${widget.levelId}';

    try {
      if (_isOnline) {
        // Online: guardar en Supabase
        debugPrint('🌐 Marcando subnivel como completado ONLINE');
        final existingRecord = await supabase
            .from('users_sublevels')
            .select('*')
            .eq('user_id', userId)
            .eq('level_id', widget.levelId)
            .eq('sublevel_id', sublevelId);

        if (existingRecord.isEmpty) {
          await supabase.from('users_sublevels').insert({
            'user_id': userId,
            'level_id': widget.levelId,
            'sublevel_id': sublevelId,
            'completed': true,
            'completion_date': DateTime.now().toIso8601String(),
          });
        } else {
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

        debugPrint('✅ Subnivel $sublevelId marcado como completado');
      } else {
        // Offline: usar servicio de sincronización
        debugPrint('📱 Sin conexión, guardando completación pendiente');
        await _syncService.savePendingCompletion(
          userId: userId,
          levelId: widget.levelId,
          sublevelId: sublevelId,
          completed: true,
        );
        debugPrint('💾 Completación guardada para sincronizar después');
      }

      // Actualizar cache local de completion status
      List<dynamic> cachedStatus = _hiveBox.get(cacheKey, defaultValue: []);
      final existingIndex =
          cachedStatus.indexWhere((item) => item['sublevel_id'] == sublevelId);

      if (existingIndex >= 0) {
        cachedStatus[existingIndex]['completed'] = true;
      } else {
        cachedStatus.add({
          'sublevel_id': sublevelId,
          'completed': true,
        });
      }
      await _hiveBox.put(cacheKey, cachedStatus);

      // Refresh completion status
      await _fetchCompletionStatus();
    } catch (e) {
      debugPrint('❌ Error marking sublevel as completed: $e');
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

  IconData _iconForType(String? type) {
    final normalized = (type ?? '').toLowerCase().trim();
    if (normalized.contains('quiz')) return Icons.quiz_rounded;
    if (normalized.contains('juego') || normalized.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (normalized.contains('video')) return Icons.play_circle_rounded;
    if (normalized.contains('audio')) return Icons.headset_rounded;
    if (normalized.contains('lectura') || normalized.contains('read')) {
      return Icons.menu_book_rounded;
    }
    return Icons.extension_rounded;
  }

  // ignore: unused_element
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
    final levelTitle = (_levelData?['name']?.toString().isNotEmpty == true)
        ? _levelData!['name'].toString()
        : widget.levelTitle;
    final levelDescription = _levelData?['description']?.toString() ?? '';
    final levelNumber = _levelData?['number'];
    final imageUrl = _levelData?['image']?.toString() ?? '';
    final localImagePath = _levelData?['local_image_path']?.toString();

    return Scaffold(
      // floatingActionButton: FutureBuilder<bool>(
      //   future: _canAddEvent(),
      //   builder: (context, snapshot) {
      //     return const SizedBox();
      //   },
      // ),
      body: RefreshIndicator(
        color: Colors.blue, // Indicador azul
        onRefresh: () async {
          await _fetchLevelData();
          await fetchSubniveles();
        },
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                color: Colors.blue,
              ))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 250,
                    pinned: true,
                    backgroundColor: Colors.blue,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        levelTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      background: (localImagePath != null &&
                              localImagePath.isNotEmpty &&
                              File(localImagePath).existsSync())
                          ? Image.file(
                              File(localImagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/images/refmmp.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : (imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
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
                                )),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.white,
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (levelNumber != null)
                              Text(
                                'Nivel $levelNumber',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            if (levelDescription.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                levelDescription,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: overallProgress,
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Progreso general',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(overallProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverList.builder(
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

                                if (result == true) {
                                  await _markSublevelCompleted(
                                      subnivel['id'].toString());
                                }
                              }
                            : () {
                                _showLockedDialog(index);
                              },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          color: !isUnlocked ? Colors.grey[200] : null,
                          child: Stack(
                            children: [
                              Opacity(
                                opacity: !isUnlocked ? 0.6 : 1.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (subnivel['image'] != null &&
                                        subnivel['image'].toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: ColorFiltered(
                                          colorFilter: !isUnlocked
                                              ? const ColorFilter.mode(
                                                  Colors.grey,
                                                  BlendMode.saturation,
                                                )
                                              : const ColorFilter.mode(
                                                  Colors.transparent,
                                                  BlendMode.multiply,
                                                ),
                                          child: CachedNetworkImage(
                                            imageUrl: subnivel['image'],
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              height: 180,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.blue),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              height: 180,
                                              color: Colors.grey[200],
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.image,
                                                      size: 50,
                                                      color: Colors.grey[400]),
                                                  const SizedBox(height: 8),
                                                  Text('Imagen no disponible',
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey[600])),
                                                ],
                                              ),
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
                                                    fontWeight: FontWeight.bold,
                                                    color: !isUnlocked
                                                        ? Colors.grey[600]
                                                        : (isCompleted
                                                            ? Colors.green
                                                            : Colors.blue),
                                                  ),
                                                ),
                                              ),
                                              if (isCompleted && isUnlocked)
                                                const Icon(
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
                                                : (subnivel['description'] ??
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
                                                label: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color: Colors.white24,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        _iconForType(
                                                            subnivel['type']
                                                                ?.toString()),
                                                        size: 13,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Tipo: ${subnivel['type'] ?? 'N/A'}',
                                                      style: const TextStyle(
                                                          color: Colors.white),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: !isUnlocked
                                                    ? Colors.grey[400]
                                                    : Colors.blue.shade200,
                                              ),
                                              const SizedBox(width: 8),
                                              if (isCompleted && isUnlocked)
                                                Chip(
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      CircleAvatar(
                                                        radius: 10,
                                                        backgroundColor:
                                                            Colors.white24,
                                                        child: Icon(
                                                          Icons.check_rounded,
                                                          size: 13,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Completado',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      Colors.green.shade400,
                                                )
                                              else if (!isUnlocked)
                                                Chip(
                                                  label: const Text(
                                                    'Bloqueado',
                                                    style: TextStyle(
                                                        color: Colors.white),
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
                              if (isCompleted && isUnlocked)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.green.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                              if (!isUnlocked)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
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
                                          const SizedBox(height: 8),
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
                    },
                  ),
                ],
              ),
      ),
    );
  }
}
