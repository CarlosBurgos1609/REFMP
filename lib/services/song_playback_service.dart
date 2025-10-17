import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/song_note.dart';
import 'database_service.dart';
import 'note_audio_service.dart';

class SongPlaybackService {
  static AudioPlayer? _currentPlayer;
  static Timer? _playbackTimer;
  static List<SongNote> _songNotes = [];
  static int _currentNoteIndex = 0;
  static bool _isPlaying = false;
  static bool _isPaused = false;
  static bool _isMuted = false; // NUEVO: Estado de mute
  static double _originalVolume = 1.0; // NUEVO: Volumen original
  static int _startTime = 0;
  static int _pausedTime = 0;

  // NUEVO: Variables para audio continuo
  static AudioPlayer? _continuousPlayer;
  static Timer? _continuousTimer;
  static bool _isContinuousPlaying = false;
  static bool _isContinuousMuted = false;
  static int _continuousStartTime = 0;
  static Timer? _noteStopTimer; // Timer para parar notas individuales

  // Callbacks para eventos de reproducción
  static Function(SongNote)? onNoteStart;
  static Function(SongNote)? onNoteEnd;
  static Function()? onSongComplete;
  static Function(int currentTime, int totalDuration)? onProgressUpdate;

  /// Inicializar el servicio
  static Future<void> initialize() async {
    await NoteAudioService.initialize();
    _currentPlayer = AudioPlayer();
    await _currentPlayer!.setReleaseMode(ReleaseMode.stop);

    // NUEVO: Inicializar player para audio continuo
    _continuousPlayer = AudioPlayer();
    await _continuousPlayer!.setReleaseMode(ReleaseMode.stop);

    print('✅ SongPlaybackService initialized with continuous audio support');
  }

  /// Cargar una canción desde la base de datos
  static Future<bool> loadSong(String songId) async {
    try {
      print('🎵 Cargando canción: $songId');

      // Obtener las notas de la canción ordenadas por tiempo
      _songNotes = await DatabaseService.getSongNotes(songId);

      if (_songNotes.isEmpty) {
        print('❌ No se encontraron notas para la canción');
        return false;
      }

      print('✅ Canción cargada con ${_songNotes.length} notas');

      // Precargar todos los audios de las notas
      await _precacheAllNoteAudios();

      _currentNoteIndex = 0;
      return true;
    } catch (e) {
      print('❌ Error cargando canción: $e');
      return false;
    }
  }

  /// Precargar todos los audios de las notas para reproducción fluida
  static Future<void> _precacheAllNoteAudios() async {
    print('🔄 Precargando audios de notas...');

    for (var note in _songNotes) {
      if (note.chromaticNote?.noteUrl != null) {
        try {
          // Precargar el audio en cache
          await NoteAudioService.playNoteFromUrl(
            note.chromaticNote!.noteUrl!,
            noteId: note.chromaticNote!.id.toString(),
            durationMs: 100, // Solo una reproducción muy corta para cache
          );
          await Future.delayed(Duration(milliseconds: 50));
        } catch (e) {
          print('⚠️ Error precargando audio para nota ${note.noteName}: $e');
        }
      }
    }

    print('✅ Audios precargados');
  }

  /// Reproducir la canción desde el inicio
  static Future<void> play() async {
    if (_songNotes.isEmpty) {
      print('❌ No hay notas cargadas para reproducir');
      return;
    }

    _isPlaying = true;
    _isPaused = false;
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _currentNoteIndex = 0;

    print('▶️ Iniciando reproducción de canción');
    await _scheduleNextNote();
  }

  /// Pausar la reproducción
  static Future<void> pause() async {
    if (!_isPlaying) return;

    _isPaused = true;
    _pausedTime = DateTime.now().millisecondsSinceEpoch - _startTime;

    // Detener timer y audio actual
    _playbackTimer?.cancel();
    await _stopCurrentNote();

    print('⏸️ Reproducción pausada en ${_pausedTime}ms');
  }

  /// Reanudar la reproducción
  static Future<void> resume() async {
    if (!_isPaused) return;

    _isPaused = false;
    _startTime = DateTime.now().millisecondsSinceEpoch - _pausedTime;

    print('▶️ Reanudando reproducción desde ${_pausedTime}ms');
    await _scheduleNextNote();
  }

  /// Detener la reproducción completamente
  static Future<void> stop() async {
    _isPlaying = false;
    _isPaused = false;
    _currentNoteIndex = 0;
    _pausedTime = 0;

    _playbackTimer?.cancel();
    await _stopCurrentNote();

    print('⏹️ Reproducción detenida');
  }

  /// Programar la siguiente nota para reproducir
  static Future<void> _scheduleNextNote() async {
    if (!_isPlaying || _isPaused || _currentNoteIndex >= _songNotes.length) {
      if (_currentNoteIndex >= _songNotes.length) {
        print('🎉 Canción completada');
        _isPlaying = false;
        onSongComplete?.call();
      }
      return;
    }

    final currentNote = _songNotes[_currentNoteIndex];
    final currentTime = DateTime.now().millisecondsSinceEpoch - _startTime;
    final noteStartTime = currentNote.startTimeMs;

    // Calcular cuánto tiempo falta para que empiece esta nota
    final delayMs = noteStartTime - currentTime;

    if (delayMs <= 0) {
      // La nota debería haber empezado ya, reproducir inmediatamente
      await _playNote(currentNote);
    } else {
      // Programar la nota para el momento correcto
      _playbackTimer = Timer(Duration(milliseconds: delayMs), () {
        _playNote(currentNote);
      });
    }

    // Actualizar progreso
    final totalDuration = _songNotes.isNotEmpty
        ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
        : 0;
    onProgressUpdate?.call(currentTime, totalDuration);
  }

  /// Reproducir una nota específica
  static Future<void> _playNote(SongNote note) async {
    if (!_isPlaying || _isPaused) return;

    try {
      print(
          '🎵 Reproduciendo nota: ${note.noteName} en ${note.startTimeMs}ms (duración: ${note.durationMs}ms)');

      // Callback de inicio de nota
      onNoteStart?.call(note);

      // Reproducir el audio de la nota con duración específica
      if (note.chromaticNote?.noteUrl != null) {
        await _playNoteWithPreciseDuration(note);
      }

      // Programar el fin de la nota
      Timer(Duration(milliseconds: note.durationMs), () {
        _onNoteCompleted(note);
      });
    } catch (e) {
      print('❌ Error reproduciendo nota ${note.noteName}: $e');
      _onNoteCompleted(note); // Continuar con la siguiente nota
    }
  }

  /// Reproducir nota con duración precisa y control de volumen basado en velocidad
  static Future<void> _playNoteWithPreciseDuration(SongNote note) async {
    try {
      // Calcular volumen basado en velocidad (0-127 -> 0.0-1.0)
      final volume = (note.velocity / 127.0).clamp(0.0, 1.0);

      // Configurar volumen
      await _currentPlayer!.setVolume(volume);

      // Reproducir la nota
      if (note.chromaticNote!.noteUrl!.startsWith('http')) {
        await _currentPlayer!.play(UrlSource(note.chromaticNote!.noteUrl!));
      } else {
        await _currentPlayer!
            .play(DeviceFileSource(note.chromaticNote!.noteUrl!));
      }

      print(
          '🔊 Nota ${note.noteName} reproducida con volumen: ${(volume * 100).toInt()}%');
    } catch (e) {
      print('❌ Error en reproducción precisa: $e');
    }
  }

  /// Manejar la finalización de una nota
  static void _onNoteCompleted(SongNote note) {
    print('✅ Nota completada: ${note.noteName}');

    // Callback de fin de nota
    onNoteEnd?.call(note);

    // Detener audio actual
    _stopCurrentNote();

    // Avanzar a la siguiente nota
    _currentNoteIndex++;

    // Programar la siguiente nota
    _scheduleNextNote();
  }

  /// Detener la nota actual
  static Future<void> _stopCurrentNote() async {
    try {
      await _currentPlayer?.stop();
    } catch (e) {
      print('⚠️ Error deteniendo nota actual: $e');
    }
  }

  /// Buscar a un tiempo específico en la canción
  static Future<void> seekTo(int timeMs) async {
    if (_songNotes.isEmpty) return;

    // Encontrar la nota que debería estar sonando en ese momento
    int noteIndex = 0;
    for (int i = 0; i < _songNotes.length; i++) {
      if (_songNotes[i].startTimeMs <= timeMs) {
        noteIndex = i;
      } else {
        break;
      }
    }

    _currentNoteIndex = noteIndex;
    _startTime = DateTime.now().millisecondsSinceEpoch - timeMs;

    if (_isPlaying && !_isPaused) {
      await _stopCurrentNote();
      await _scheduleNextNote();
    }

    print('⏩ Saltando a ${timeMs}ms (nota ${noteIndex + 1})');
  }

  /// Obtener información del estado actual
  static Map<String, dynamic> getPlaybackInfo() {
    final currentTime = _isPlaying && !_isPaused
        ? DateTime.now().millisecondsSinceEpoch - _startTime
        : _pausedTime;

    final totalDuration = _songNotes.isNotEmpty
        ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
        : 0;

    final currentNote = _currentNoteIndex < _songNotes.length
        ? _songNotes[_currentNoteIndex]
        : null;

    return {
      'isPlaying': _isPlaying,
      'isPaused': _isPaused,
      'currentTime': currentTime,
      'totalDuration': totalDuration,
      'currentNoteIndex': _currentNoteIndex,
      'totalNotes': _songNotes.length,
      'currentNote': currentNote?.noteName,
      'progress': totalDuration > 0 ? currentTime / totalDuration : 0.0,
    };
  }

  /// Mutear el audio (mantiene la reproducción pero sin sonido)
  static Future<void> mute() async {
    if (_isMuted) return;

    _isMuted = true;
    if (_currentPlayer != null) {
      await _currentPlayer!.setVolume(0.0);
      print('🔇 Audio muteado (volumen: $_originalVolume → 0.0)');
    }
  }

  /// Desmutear el audio (restaura el volumen original)
  static Future<void> unmute() async {
    if (!_isMuted) return;

    _isMuted = false;
    if (_currentPlayer != null) {
      await _currentPlayer!.setVolume(_originalVolume);
      print('🔊 Audio desmuteado (volumen: 0.0 → $_originalVolume)');
    }
  }

  /// Verificar si está muteado
  static bool get isMuted => _isMuted;

  // NUEVO: Métodos para audio continuo respetando duración exacta

  /// Reproducir canción como audio continuo (todas las notas unidas respetando duration_ms)
  static Future<void> playContinuous() async {
    if (_songNotes.isEmpty) {
      print('❌ No hay notas cargadas para reproducir');
      return;
    }

    _isContinuousPlaying = true;
    _continuousStartTime = DateTime.now().millisecondsSinceEpoch;
    _currentNoteIndex = 0;

    print('🎵 Iniciando reproducción continua de ${_songNotes.length} notas');
    await _scheduleNextContinuousNote();
  }

  /// Programar la siguiente nota en el audio continuo
  static Future<void> _scheduleNextContinuousNote() async {
    if (!_isContinuousPlaying || _currentNoteIndex >= _songNotes.length) {
      if (_currentNoteIndex >= _songNotes.length) {
        print('🎉 Audio continuo completado');
        onSongComplete?.call();
      }
      return;
    }

    final currentNote = _songNotes[_currentNoteIndex];
    final currentTime =
        DateTime.now().millisecondsSinceEpoch - _continuousStartTime;
    final noteStartTime = currentNote.startTimeMs;

    // Calcular cuánto tiempo falta para que empiece esta nota
    final delayMs = noteStartTime - currentTime;

    if (delayMs <= 0) {
      // La nota debería haber empezado ya, reproducir inmediatamente
      await _playContinuousNote(currentNote);
    } else {
      // Programar la nota para que empiece en el momento correcto
      _continuousTimer = Timer(Duration(milliseconds: delayMs), () {
        _playContinuousNote(currentNote);
      });
    }
  }

  /// Reproducir una nota específica en el audio continuo con duración exacta
  static Future<void> _playContinuousNote(SongNote note) async {
    if (!_isContinuousPlaying) return;

    try {
      // Solo reproducir si no está muteado
      if (!_isContinuousMuted && note.noteUrl != null) {
        print(
            '🎵 Reproduciendo nota continua: ${note.noteName} (${note.durationMs}ms)');

        // Callback de inicio de nota
        onNoteStart?.call(note);

        // Reproducir la nota
        await _continuousPlayer!.play(UrlSource(note.noteUrl!));

        // Programar parada de la nota según duration_ms
        _noteStopTimer = Timer(Duration(milliseconds: note.durationMs), () {
          _stopContinuousNote(note);
        });
      } else {
        print('🔇 Nota muteada o sin URL: ${note.noteName}');
        // Aunque esté muteada, seguir con el timing
        _scheduleNoteSilentEnd(note);
      }

      // Avanzar al siguiente índice
      _currentNoteIndex++;

      // Programar la siguiente nota inmediatamente (en paralelo)
      await _scheduleNextContinuousNote();
    } catch (e) {
      print('❌ Error reproduciendo nota continua: $e');
      _currentNoteIndex++;
      await _scheduleNextContinuousNote();
    }
  }

  /// Parar una nota específica y llamar callback de finalización
  static void _stopContinuousNote(SongNote note) {
    try {
      _continuousPlayer?.stop();
      print('✅ Nota continua finalizada: ${note.noteName}');
      onNoteEnd?.call(note);
    } catch (e) {
      print('❌ Error parando nota continua: $e');
    }
  }

  /// Programar finalización silenciosa de una nota (cuando está muteada)
  static void _scheduleNoteSilentEnd(SongNote note) {
    _noteStopTimer = Timer(Duration(milliseconds: note.durationMs), () {
      print('🔇 Nota silenciosa finalizada: ${note.noteName}');
      onNoteEnd?.call(note);
    });
  }

  /// Pausar audio continuo
  static Future<void> pauseContinuous() async {
    if (!_isContinuousPlaying) return;

    _isContinuousPlaying = false;
    _continuousTimer?.cancel();
    _noteStopTimer?.cancel();
    await _continuousPlayer?.pause();

    print('⏸️ Audio continuo pausado');
  }

  /// Reanudar audio continuo
  static Future<void> resumeContinuous() async {
    if (_isContinuousPlaying) return;

    _isContinuousPlaying = true;
    await _continuousPlayer?.resume();

    // Reanudar programación de notas
    await _scheduleNextContinuousNote();

    print('▶️ Audio continuo reanudado');
  }

  /// Parar audio continuo completamente
  static Future<void> stopContinuous() async {
    _isContinuousPlaying = false;
    _currentNoteIndex = 0;

    _continuousTimer?.cancel();
    _noteStopTimer?.cancel();
    await _continuousPlayer?.stop();

    print('⏹️ Audio continuo detenido');
  }

  /// Mutear audio continuo (para cuando se pierde una nota)
  static Future<void> muteContinuous() async {
    if (_isContinuousMuted) return;

    _isContinuousMuted = true;
    await _continuousPlayer?.setVolume(0.0);

    print('🔇 Audio continuo muteado');
  }

  /// Desmutear audio continuo (para cuando se toca una nota correctamente)
  static Future<void> unmuteContinuous() async {
    if (!_isContinuousMuted) return;

    _isContinuousMuted = false;
    await _continuousPlayer?.setVolume(1.0);

    print('🔊 Audio continuo desmuteado');
  }

  /// Verificar si el audio continuo está muteado
  static bool get isContinuousMuted => _isContinuousMuted;

  /// Verificar si el audio continuo está reproduciéndose
  static bool get isContinuousPlaying => _isContinuousPlaying;

  /// Liberar recursos
  static Future<void> dispose() async {
    await stop();
    _playbackTimer?.cancel();
    await _currentPlayer?.dispose();
    _currentPlayer = null;

    // Limpiar callbacks
    onNoteStart = null;
    onNoteEnd = null;
    onSongComplete = null;
    onProgressUpdate = null;

    print('✅ SongPlaybackService disposed');
  }
}
