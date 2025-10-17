import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:async'; // Agregado para Timer
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class NoteAudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;
  static final Map<String, String> _audioCache =
      {}; // Cache de URLs a archivos locales

  // Variables para control de duración y flujo continuo
  static Timer? _durationTimer;
  static bool _isPlayingContinuous = false;
  static String? _currentContinuousNote;
  static Set<int> _currentPistonCombination = {};
  static bool _isAudioOperationInProgress =
      false; // NUEVO: Semáforo para operaciones concurrentes

  // Base de datos de combinaciones de pistones a notas (backup local) - ACTUALIZADO
  static final Map<Set<int>, Map<String, dynamic>> _pistonToNoteMap = {
    <int>{}: {
      'name': 'G4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/G4.mp3'
    }, // Nota abierta
    <int>{1}: {
      'name': 'F4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/F4.mp3'
    },
    <int>{2}: {
      'name': 'B4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/B4.mp3'
    },
    <int>{3}: {
      'name': 'D4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/D4.mp3'
    },
    <int>{1, 2}: {
      'name': 'E4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/E4.mp3'
    },
    <int>{2, 3}: {
      'name': 'A4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/A4.mp3'
    },
    <int>{1, 3}: {
      'name': 'Eb4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/Eb4.mp3'
    },
    <int>{1, 2, 3}: {
      'name': 'Bb4',
      'url':
          'https://dmhyuogexgghinvfgoup.supabase.co/storage/v1/object/public/notes/notes_trumpet/Bb4.mp3'
    },
  }; // NUEVO: Precargar TODAS las notas disponibles desde la base de datos
  static Future<void> precacheAllNotesFromDatabase(
      List<dynamic> availableNotes) async {
    if (!_isInitialized) await initialize();

    print('🔄 Starting precache of ALL database notes...');
    int successCount = 0;
    int failCount = 0;

    for (var note in availableNotes) {
      final noteUrl = note.noteUrl;
      final noteName = note.noteName;

      if (noteUrl != null && noteUrl.isNotEmpty) {
        try {
          // Verificar si ya está en caché
          final cachedFile = await _getCachedFile(noteUrl);
          if (cachedFile == null || !await cachedFile.exists()) {
            print('📥 Downloading $noteName...');
            await _cacheAudioFile(noteUrl);
            successCount++;
            print('✅ Downloaded $noteName successfully');
          } else {
            print('✅ $noteName already cached');
            successCount++;
          }

          // Agregar al mapa de caché en memoria
          _audioCache[noteUrl] = cachedFile?.path ?? noteUrl;
        } catch (e) {
          print('❌ Failed to cache $noteName: $e');
          failCount++;
        }
      }
    }

    print(
        '✅ Database precache complete: $successCount success, $failCount failed');
  }

  // NUEVO: Obtener archivo desde caché
  static Future<File?> _getCachedFile(String noteUrl) async {
    try {
      if (_audioCache.containsKey(noteUrl)) {
        final cachedPath = _audioCache[noteUrl]!;
        final file = File(cachedPath);
        if (await file.exists()) {
          return file;
        } else {
          // Archivo no existe, remover del caché
          _audioCache.remove(noteUrl);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting cached file: $e');
      return null;
    }
  }

  // NUEVO: Cachear archivo de audio en background
  static Future<void> _cacheAudioFile(String noteUrl) async {
    try {
      final response = await http.get(Uri.parse(noteUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'cached_${noteUrl.hashCode}.mp3';
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        _audioCache[noteUrl] = filePath;
        print('✅ Audio cached: $fileName');
      }
    } catch (e) {
      print('❌ Error caching audio: $e');
    }
  }

  // NUEVO: Reproducir sonido continuo basado en pistones presionados
  static Future<void> playFromPistonCombination(Set<int> pressedPistons,
      {List<dynamic>? availableNotes,
      bool shouldPlay = true,
      bool loop = true}) async {
    try {
      await initialize();

      // Evitar operaciones concurrentes
      if (_isAudioOperationInProgress) {
        print('🔄 Audio operation in progress, skipping...');
        return;
      }

      _isAudioOperationInProgress = true;

      _currentPistonCombination = Set.from(pressedPistons);

      if (!shouldPlay) {
        // Pausar audio pero mantener la combinación
        await _audioPlayer.pause();
        print('⏸️ Audio paused for piston combination: $pressedPistons');
        return;
      }

      // Si no hay pistones presionados, detener audio
      if (pressedPistons.isEmpty) {
        await stopContinuousPlay();
        return;
      }

      // Buscar nota en las notas disponibles primero
      String? noteUrl;
      String noteName = 'Unknown';
      int?
          noteDuration; // NUEVO: Para almacenar la duración de la base de datos

      if (availableNotes != null) {
        for (var note in availableNotes) {
          final notePistons = note.pistonCombination?.toSet() ?? <int>{};
          // ARREGLADO: Mejorar la lógica de coincidencia de pistones
          final pressedSet = Set<int>.from(pressedPistons);

          if (notePistons.difference(pressedSet).isEmpty &&
              pressedSet.difference(notePistons).isEmpty) {
            noteUrl = note.noteUrl;
            noteName = note.noteName;
            noteDuration = note.durationMs;
            print(
                '🎯 Found exact match: $noteName for pistons $pressedPistons (URL: $noteUrl)');
            break;
          }
        }

        // Si no hay coincidencia exacta, buscar la primera nota que contenga los pistones presionados
        if (noteUrl == null) {
          for (var note in availableNotes) {
            final notePistons = note.pistonCombination?.toSet() ?? <int>{};
            final pressedSet = Set<int>.from(pressedPistons);

            if (notePistons.isNotEmpty && pressedSet.containsAll(notePistons)) {
              noteUrl = note.noteUrl;
              noteName = note.noteName;
              noteDuration = note.durationMs;
              print(
                  '🎯 Using partial match from database: $noteName for pistons $pressedPistons');
              break;
            }
          }
        }
      }

      // Si no hay nota disponible, usar mapeo local
      if (noteUrl == null || noteUrl.isEmpty) {
        final noteData = _pistonToNoteMap[pressedPistons];
        if (noteData != null && noteData['url'] != null) {
          noteName = noteData['name'];
          noteUrl = noteData['url'];
          print(
              '🔄 Using fallback mapping for pistons $pressedPistons: $noteName');
        } else {
          // Fallback adicional: buscar la primera nota que tenga un pistón en común
          if (availableNotes != null) {
            for (var note in availableNotes) {
              final notePistons = note.pistonCombination?.toSet() ?? <int>{};
              if (notePistons.isNotEmpty &&
                  pressedPistons.any((p) => notePistons.contains(p))) {
                noteUrl = note.noteUrl;
                noteName = note.noteName;
                print(
                    '🎯 Using partial match from database: $noteName for pistons $pressedPistons');
                break;
              }
            }
          }
        }
      }

      // Si es la misma nota que ya está sonando, no interrumpir
      if (_currentContinuousNote == noteName && _isPlayingContinuous) {
        // Reanudar si estaba pausado
        final state = _audioPlayer.state;
        if (state == PlayerState.paused) {
          await _audioPlayer.resume();
          print('▶️ Resumed continuous note: $noteName');
        } else if (state == PlayerState.playing) {
          print('🎵 Already playing $noteName, not restarting');
        }
        return;
      }

      print(
          '🎵 Playing continuous note: $noteName for pistons: $pressedPistons (duration: ${noteDuration ?? "loop"}ms)');

      // ARREGLADO: Detener audio anterior suavemente solo si es diferente
      if (_currentContinuousNote != noteName) {
        final state = _audioPlayer.state;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          await _audioPlayer.stop();
          // Pequeña pausa para evitar conflictos de audio
          await Future.delayed(Duration(milliseconds: 50));
        }
        print('🔇 Stopped previous audio: $_currentContinuousNote');
      }

      _currentContinuousNote = noteName;
      _isPlayingContinuous = true;

      if (noteUrl != null && noteUrl.isNotEmpty) {
        // Verificar si está en caché primero
        final cachedFile = await _getCachedFile(noteUrl);

        print('🎵 Attempting to play $noteName from: $noteUrl');

        // Verificar si ya está reproduciendo el mismo archivo
        if (_audioPlayer.state == PlayerState.playing &&
            _currentContinuousNote == noteName) {
          print('🎵 Same note already playing, not restarting');
          return;
        }

        // Si hay duración específica y no es loop, usar duración limitada
        if (noteDuration != null && !loop) {
          await _audioPlayer.setReleaseMode(ReleaseMode.release);

          if (cachedFile != null && await cachedFile.exists()) {
            await _audioPlayer.play(DeviceFileSource(cachedFile.path));
          } else {
            await _audioPlayer.play(UrlSource(noteUrl));
            _cacheAudioFile(noteUrl).catchError((e) {
              print('⚠️ Failed to cache $noteName: $e');
            });
          }

          // Programar parada automática después de la duración especificada
          _durationTimer?.cancel();
          _durationTimer =
              Timer(Duration(milliseconds: noteDuration), () async {
            // Solo parar si no hay otra nota reproduciéndose
            if (_currentContinuousNote == noteName) {
              await _stopCurrentAudio();
              print('⏰ Audio stopped automatically after ${noteDuration}ms');
            }
          });

          print(
              '🎵 ✅ Playing audio with duration limit (${noteDuration}ms): $noteName');
        } else {
          // Para loop o sin duración específica
          if (loop) {
            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          } else {
            await _audioPlayer.setReleaseMode(ReleaseMode.release);
          }

          if (cachedFile != null && await cachedFile.exists()) {
            await _audioPlayer.play(DeviceFileSource(cachedFile.path));
            print('🎵 ✅ Playing cached audio (loop: $loop): $noteName');
          } else {
            try {
              await _audioPlayer.play(UrlSource(noteUrl));
              print('🎵 ✅ Playing online audio (loop: $loop): $noteName');

              // Cachear en background para uso futuro
              _cacheAudioFile(noteUrl).catchError((e) {
                print('⚠️ Failed to cache $noteName: $e');
              });
            } catch (e) {
              print('❌ Failed to play audio for $noteName: $e');
            }
          }
        }
      } else {
        print(
            '⚠️ No audio URL available for note: $noteName (pistons: $pressedPistons)');
      }
    } catch (e) {
      print('❌ Error playing from piston combination: $e');
    } finally {
      _isAudioOperationInProgress = false; // Liberar semáforo
    }
  }

  // NUEVO: Pausar audio cuando se falla una nota
  static Future<void> pauseOnMiss() async {
    try {
      if (_isPlayingContinuous) {
        await _audioPlayer.pause();
        print('⏸️ Audio paused due to miss');
      }
    } catch (e) {
      print('❌ Error pausing audio on miss: $e');
    }
  }

  // NUEVO: Reanudar audio después de una pausa
  static Future<void> resumeOnHit() async {
    try {
      final state = _audioPlayer.state;
      if (state == PlayerState.paused && _isPlayingContinuous) {
        await _audioPlayer.resume();
        print('▶️ Audio resumed after hit');
      }
    } catch (e) {
      print('❌ Error resuming audio on hit: $e');
    }
  }

  // NUEVO: Detener reproducción continua
  static Future<void> stopContinuousPlay() async {
    try {
      if (_isPlayingContinuous) {
        // Solo detener si realmente está reproduciendo
        final state = _audioPlayer.state;
        if (state == PlayerState.playing || state == PlayerState.paused) {
          await _audioPlayer.stop();
        }
        _isPlayingContinuous = false;
        _currentContinuousNote = null;
        _currentPistonCombination.clear();
        print('🔇 Continuous play stopped');
      }
    } catch (e) {
      print('❌ Error stopping continuous play: $e');
    }
  }

  static Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
        _isInitialized = true;
        print('✅ NoteAudioService initialized successfully');
      } catch (e) {
        print('❌ Error initializing NoteAudioService: $e');
      }
    }
  }

  // Descargar y cachear un archivo de audio
  static Future<String?> _downloadAndCacheAudio(
      String noteUrl, String noteId) async {
    try {
      // Verificar si ya está en caché
      if (_audioCache.containsKey(noteUrl)) {
        final cachedPath = _audioCache[noteUrl]!;
        if (await File(cachedPath).exists()) {
          print('🎵 Using cached audio: $cachedPath');
          return cachedPath;
        } else {
          // Archivo en caché ya no existe, remover de caché
          _audioCache.remove(noteUrl);
        }
      }

      // Verificar conectividad antes de intentar descargar
      final hasNetwork = await checkNetworkConnectivity();
      if (!hasNetwork) {
        print('🌐 No network connectivity, skipping audio download');
        return null;
      }

      print('📥 Downloading audio from: $noteUrl');

      // Timeout más corto y manejo de errores mejorado
      final response = await http.get(Uri.parse(noteUrl)).timeout(
        const Duration(seconds: 5), // Reducido de 10 a 5 segundos
        onTimeout: () {
          print('⏰ Download timeout for: $noteUrl');
          throw TimeoutException(
              'Download timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName =
            'note_${noteId}_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final filePath = '${dir.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        _audioCache[noteUrl] = filePath;

        print('✅ Audio downloaded and cached: $filePath');
        return filePath;
      } else {
        print('❌ Failed to download audio: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading audio: $e');
      return null;
    }
  }

  // Reproducir una nota desde su URL (con caché automático y control de duración)
  static Future<void> playNoteFromUrl(String? noteUrl,
      {String? noteId, int? durationMs}) async {
    if (noteUrl == null || noteUrl.isEmpty) {
      print('⚠️ No note URL provided');
      return;
    }

    try {
      // Asegurar que el servicio esté inicializado
      if (!_isInitialized) {
        await initialize();
      }

      // No interrumpir si hay audio continuo reproduciéndose
      if (_isPlayingContinuous && _audioPlayer.state == PlayerState.playing) {
        print(
            '🎵 Continuous audio playing, not interrupting with URL playback');
        return;
      }

      print(
          '🎵 Playing note from URL: $noteUrl${durationMs != null ? ' (duration: ${durationMs}ms)' : ''}');

      String? audioPath;

      // Si es una URL de internet, descargar y cachear
      if (noteUrl.startsWith('http')) {
        audioPath = await _downloadAndCacheAudio(noteUrl, noteId ?? 'unknown');
        if (audioPath == null) {
          print('❌ Failed to download audio, skipping note playback');
          // No lanzar error, simplemente salir silenciosamente
          return;
        }
      } else {
        // Si es una ruta local, usar directamente
        audioPath = noteUrl;
      }

      // ARREGLADO: Solo detener si no hay audio continuo o si la duración está especificada
      if (durationMs != null || !_isPlayingContinuous) {
        await _audioPlayer.stop();
        print('🔇 Stopped previous audio for timed playback');
      }

      // Reproducir desde archivo local
      await _audioPlayer.play(DeviceFileSource(audioPath));
      print('🎵 Playing audio from: $audioPath');

      // Si se especifica duración, programar corte automático
      if (durationMs != null && durationMs > 0) {
        _durationTimer = Timer(Duration(milliseconds: durationMs), () async {
          // Solo detener si este timer aún es válido y no hay otro audio
          if (_durationTimer != null && !_isPlayingContinuous) {
            await _stopCurrentAudio();
            print('⏰ Audio stopped automatically after ${durationMs}ms');
          }
        });
      }
    } catch (e) {
      print('❌ Error playing note from URL: $e');
      // No relanzar el error para evitar crasheos
    }
  }

  // Reproducir una nota desde un SongNote (usando su ChromaticNote)
  static Future<void> playNoteFromSongNote(dynamic songNote) async {
    try {
      // Verificar que el songNote tenga el método noteUrl
      if (songNote.noteUrl != null) {
        print('🎵 Playing note: ${songNote.noteName} (${songNote.noteUrl})');
        await playNoteFromUrl(
          songNote.noteUrl,
          noteId: songNote.chromaticId?.toString(),
          durationMs: songNote.durationMs, // Usar la duración de la nota
        );
      } else {
        print('⚠️ No note URL available for note: ${songNote.noteName}');
      }
    } catch (e) {
      print('❌ Error playing note from SongNote: $e');
    }
  }

  // Reproducir sonido de éxito cuando el jugador acierta (SIN DELAY)
  static Future<void> playHitSuccess(dynamic songNote) async {
    try {
      print('🎯 Hit success! Playing note immediately: ${songNote.noteName}');

      // Reproducir inmediatamente sin esperar descarga completa
      if (songNote.noteUrl != null) {
        // Usar fire-and-forget para reproducción instantánea con duración
        playNoteFromUrl(
          songNote.noteUrl,
          noteId: songNote.chromaticId?.toString(),
          durationMs: songNote.durationMs, // Usar la duración de la nota
        );
      }
    } catch (e) {
      print('❌ Error playing hit success sound: $e');
    }
  }

  // NUEVO: Método privado para parar solo el audio actual sin interferir con otros
  static Future<void> _stopCurrentAudio() async {
    try {
      final state = _audioPlayer.state;
      if (state == PlayerState.playing || state == PlayerState.paused) {
        await _audioPlayer.stop();
      }

      // Cancelar timer de duración
      _durationTimer?.cancel();
      _durationTimer = null;

      // Reset estado continuo
      _isPlayingContinuous = false;
      _currentContinuousNote = null;
    } catch (e) {
      print('❌ Error stopping current audio: $e');
    }
  }

  // ARREGLADO: Parar sonidos de forma más inteligente
  static Future<void> stopAllSounds() async {
    try {
      print('🔇 Stopping all sounds...');

      // Solo detener si realmente hay algo reproduciéndose
      final state = _audioPlayer.state;
      if (state == PlayerState.playing || state == PlayerState.paused) {
        await _audioPlayer.stop();
        print('🔇 Audio player stopped');
      }

      // Cancelar timer de duración si existe
      _durationTimer?.cancel();
      _durationTimer = null;

      // Reset continuous play state only if explicitly stopping
      if (_isPlayingContinuous) {
        _isPlayingContinuous = false;
        _currentContinuousNote = null;
        print('🔇 Continuous play state reset');
      }

      print('🔇 All sounds stopped successfully');
    } catch (e) {
      print('❌ Error stopping all sounds: $e');
    }
  }

  // NUEVO: Parar sonidos suavemente (con fade out virtual)
  static Future<void> stopSoundsGently() async {
    try {
      print('🔇 Gently stopping sounds...');

      // Permitir que el audio continúe si tiene duración específica
      if (_durationTimer != null) {
        print('🔇 Letting timed audio finish naturally...');
        return; // No interrumpir audio con duración específica
      }

      // Solo detener audio continuo sin duración específica
      if (_isPlayingContinuous && _currentContinuousNote != null) {
        await _audioPlayer.stop();
        _isPlayingContinuous = false;
        _currentContinuousNote = null;
        print('🔇 Continuous audio stopped gently');
      }
    } catch (e) {
      print('❌ Error gently stopping sounds: $e');
    }
  }

  // Liberar recursos
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      print('✅ NoteAudioService disposed');
    } catch (e) {
      print('❌ Error disposing NoteAudioService: $e');
    }
  }

  // Configurar volumen (0.0 a 1.0)
  static Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
    } catch (e) {
      print('❌ Error setting volume: $e');
    }
  }

  // Verificar conectividad de red
  static Future<bool> checkNetworkConnectivity() async {
    try {
      final response = await http.head(
        Uri.parse('https://www.google.com'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      print('🌐 Network check failed: $e');
      return false;
    }
  }

  // Limpiar caché de audio antiguo
  static Future<void> clearOldCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFiles = dir.listSync().where(
          (file) => file.path.contains('note_') && file.path.endsWith('.mp3'));

      int deletedCount = 0;
      for (var file in cacheFiles) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          print('⚠️ Could not delete cache file: ${file.path}');
        }
      }

      // Limpiar el mapa de caché en memoria
      _audioCache.clear();
      print('🧹 Cleared $deletedCount audio cache files');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  // Obtener tamaño del caché en MB
  static Future<double> getCacheSizeMB() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheFiles = dir.listSync().where(
          (file) => file.path.contains('note_') && file.path.endsWith('.mp3'));

      int totalBytes = 0;
      for (var file in cacheFiles) {
        try {
          final stat = await file.stat();
          totalBytes += stat.size;
        } catch (e) {
          // Ignorar archivos que no se pueden leer
        }
      }

      return totalBytes / (1024 * 1024); // Convertir a MB
    } catch (e) {
      print('❌ Error calculating cache size: $e');
      return 0.0;
    }
  }
}
