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

  // Variables para control de duración
  static Timer? _durationTimer;

  // Inicializar el servicio de audio
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
          throw TimeoutException('Download timeout', const Duration(seconds: 5));
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

      // SIEMPRE detener cualquier audio previo y cancelar timer anterior
      await stopAllSounds();

      // Reproducir desde archivo local
      await _audioPlayer.play(DeviceFileSource(audioPath));
      print('🎵 Playing audio from: $audioPath');

      // Si se especifica duración, programar corte automático
      if (durationMs != null && durationMs > 0) {
        _durationTimer = Timer(Duration(milliseconds: durationMs), () {
          // Solo detener si este timer aún es válido
          if (_durationTimer != null) {
            stopAllSounds();
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

  // Parar todos los sonidos que estén reproduciéndose
  static Future<void> stopAllSounds() async {
    try {
      // Cancelar timer de duración si existe
      _durationTimer?.cancel();
      _durationTimer = null;

      await _audioPlayer.stop();
      print('🔇 All sounds stopped');
    } catch (e) {
      print('❌ Error stopping all sounds: $e');
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
      final cacheFiles = dir.listSync().where((file) => 
        file.path.contains('note_') && file.path.endsWith('.mp3'));
      
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
      final cacheFiles = dir.listSync().where((file) => 
        file.path.contains('note_') && file.path.endsWith('.mp3'));
      
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
