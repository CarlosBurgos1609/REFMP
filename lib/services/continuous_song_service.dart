import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/song_note.dart';
import '../models/chromatic_note.dart';
import 'database_service.dart';
import 'note_audio_service.dart';

/// Servicio para reproducir canciones como audio continuo y fluido
/// con mute/unmute basado en la precisión del jugador
class ContinuousSongService {
  static final ContinuousSongService _instance =
      ContinuousSongService._internal();
  factory ContinuousSongService() => _instance;
  ContinuousSongService._internal();

  // Audio player principal para la canción continua
  AudioPlayer? _continuousPlayer;
  bool _isPlayerDisposed = false;

  // Lista de notas de la canción ordenadas por tiempo
  List<SongNote> _songNotes = [];
  Map<int, ChromaticNote> _chromaticNotesCache = {};

  // Control de reproducción
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;

  // Timing y sincronización
  int _songStartTime = 0;
  int _currentNoteIndex = 0;
  Timer? _playbackTimer;
  Timer? _noteScheduler;

  // Callbacks para eventos del juego
  Function(SongNote)? onNoteStart;
  Function(SongNote)? onNoteEnd;
  Function()? onSongComplete;
  Function(int currentTime, int totalDuration)? onProgressUpdate;

  // Estado del juego
  bool _gameAudioEnabled = true; // Si está muteado por el juego (errores)

  /// Inicializar el servicio
  Future<void> initialize() async {
    try {
      // Crear nuevo player si no existe o si fue dispuesto
      if (_continuousPlayer == null || _isPlayerDisposed) {
        _continuousPlayer = AudioPlayer();
        _isPlayerDisposed = false;
      }

      await _continuousPlayer!.setReleaseMode(ReleaseMode.stop);
      await _continuousPlayer!.setPlayerMode(PlayerMode.lowLatency);
      await NoteAudioService.initialize();

      _isInitialized = true;
      print('✅ ContinuousSongService initialized');
    } catch (e) {
      print('❌ Error initializing ContinuousSongService: $e');
      _isInitialized = false;
      _continuousPlayer = null;
      _isPlayerDisposed = true;
    }
  }

  /// Helper para verificar si el player está disponible
  bool _isPlayerAvailable() {
    return _continuousPlayer != null && !_isPlayerDisposed && _isInitialized;
  }

  /// Helper para ejecutar operaciones de audio de manera segura
  Future<void> _safeAudioOperation(
      Future<void> Function(AudioPlayer player) operation) async {
    if (!_isPlayerAvailable()) {
      print('⚠️ Audio player not available for operation');
      return;
    }

    try {
      await operation(_continuousPlayer!);
    } catch (e) {
      print('❌ Audio operation failed: $e');
      // Si hay error, marcar como dispuesto para reinicializar en la siguiente operación
      _isPlayerDisposed = true;
    }
  }

  /// Cargar canción y sus notas desde la base de datos
  Future<bool> loadSong(String songId) async {
    if (!_isInitialized) await initialize();

    try {
      print('🔄 Loading song: $songId');

      final notes = await DatabaseService.getSongNotes(songId);

      if (notes.isEmpty) {
        print('⚠️ No notes found for song: $songId');
        return false;
      }

      // Las notas ya vienen con ChromaticNote asociadas desde DatabaseService
      _songNotes = notes;
      _chromaticNotesCache = {};

      // Llenar el cache de ChromaticNote para acceso rápido
      for (var songNote in _songNotes) {
        if (songNote.chromaticId != null && songNote.chromaticNote != null) {
          _chromaticNotesCache[songNote.chromaticId!] = songNote.chromaticNote!;
        }
      }

      // Ordenar notas por measure_number y luego por start_time_ms
      _songNotes.sort((a, b) {
        final measureComparison = a.measureNumber.compareTo(b.measureNumber);
        if (measureComparison != 0) return measureComparison;
        return a.startTimeMs.compareTo(b.startTimeMs);
      });

      print('✅ Loaded ${_songNotes.length} notes for song $songId');

      // Precargar todos los audios de las notas
      await _precacheAllNoteAudios();

      return true;
    } catch (e) {
      print('❌ Error loading song: $e');
      return false;
    }
  }

  /// Precargar todos los audios de las notas
  Future<void> _precacheAllNoteAudios() async {
    print('🔄 Precargando audios de notas...');

    // Crear lista de notas con URLs para usar con NoteAudioService.precacheAllNotesFromDatabase
    final notesWithUrls = _songNotes
        .where((note) => note.noteUrl != null && note.noteUrl!.isNotEmpty)
        .map((note) => note.chromaticNote)
        .where((chromaticNote) => chromaticNote != null)
        .toList();

    if (notesWithUrls.isNotEmpty) {
      try {
        await NoteAudioService.precacheAllNotesFromDatabase(notesWithUrls);
      } catch (e) {
        print('⚠️ Error precaching notes: $e');
      }
    }

    print('✅ Precarga de audios completada');
  }

  /// Iniciar reproducción continua de la canción
  Future<void> play() async {
    if (!_isInitialized || _songNotes.isEmpty) {
      print('⚠️ Service not initialized or no notes loaded');
      return;
    }

    print('▶️ Starting continuous song playback');

    _isPlaying = true;
    _isPaused = false;
    _currentNoteIndex = 0;
    _songStartTime = DateTime.now().millisecondsSinceEpoch;
    _gameAudioEnabled = true;

    // Iniciar el programador de notas
    _scheduleNextNote();

    // Iniciar el timer de progreso
    _startProgressTimer();
  }

  /// Pausar la reproducción
  Future<void> pause() async {
    if (!_isPlaying) return;

    print('⏸️ Pausing continuous playback');

    _isPaused = true;
    _playbackTimer?.cancel();
    _noteScheduler?.cancel();

    await _safeAudioOperation((player) async {
      await player.pause();
    });
  }

  /// Reanudar la reproducción
  Future<void> resume() async {
    if (!_isPaused) return;

    print('▶️ Resuming continuous playback');

    _isPaused = false;
    _songStartTime =
        DateTime.now().millisecondsSinceEpoch - _getCurrentPlayTime();

    await _safeAudioOperation((player) async {
      await player.resume();
    });
    _scheduleNextNote();
    _startProgressTimer();
  }

  /// Detener la reproducción completamente
  Future<void> stop() async {
    print('⏹️ Stopping continuous playback');

    _isPlaying = false;
    _isPaused = false;
    _currentNoteIndex = 0;

    _playbackTimer?.cancel();
    _noteScheduler?.cancel();

    await _safeAudioOperation((player) async {
      await player.stop();
    });
  }

  /// Mutear el audio del juego (cuando el jugador falla)
  Future<void> muteGame() async {
    if (_gameAudioEnabled) {
      print('🔇 Muting game audio due to player error');
      _gameAudioEnabled = false;
      await _safeAudioOperation((player) async {
        await player.setVolume(0.0);
      });
    }
  }

  /// Desmutear el audio del juego (cuando el jugador acierta)
  Future<void> unmuteGame() async {
    if (!_gameAudioEnabled) {
      print('🔊 Unmuting game audio - player back on track');
      _gameAudioEnabled = true;
      await _safeAudioOperation((player) async {
        await player.setVolume(1.0);
      });
    }
  }

  /// Verificar si el audio del juego está muteado
  bool get isGameMuted => !_gameAudioEnabled;

  /// Obtener tiempo actual de reproducción
  int _getCurrentPlayTime() {
    if (!_isPlaying || _isPaused) return 0;
    return DateTime.now().millisecondsSinceEpoch - _songStartTime;
  }

  /// Programar la siguiente nota para reproducir
  void _scheduleNextNote() {
    if (!_isPlaying || _isPaused || _currentNoteIndex >= _songNotes.length) {
      if (_currentNoteIndex >= _songNotes.length) {
        _onSongComplete();
      }
      return;
    }

    final currentNote = _songNotes[_currentNoteIndex];
    final currentTime = _getCurrentPlayTime();
    final noteStartTime = currentNote.startTimeMs;

    // Calcular cuánto tiempo falta para que empiece esta nota
    final delayMs = noteStartTime - currentTime;

    if (delayMs <= 0) {
      // La nota debería estar sonando ahora
      _playNote(currentNote);
    } else {
      // Programar la nota para el futuro
      _noteScheduler = Timer(Duration(milliseconds: delayMs), () {
        if (_isPlaying && !_isPaused) {
          _playNote(currentNote);
        }
      });
    }
  }

  /// Reproducir una nota específica con duración precisa
  void _playNote(SongNote note) {
    if (!_isPlaying || _isPaused) return;

    try {
      print(
          '🎵 Playing note: ${note.noteName} at ${note.startTimeMs}ms (duration: ${note.durationMs}ms)');

      // Callback de inicio de nota
      onNoteStart?.call(note);

      // Solo reproducir el audio si el juego no está muteado
      if (_gameAudioEnabled &&
          note.noteUrl != null &&
          note.noteUrl!.isNotEmpty) {
        _playContinuousNoteAudio(note);
      }

      // Programar el final de la nota
      Timer(Duration(milliseconds: note.durationMs), () {
        _onNoteEnd(note);
      });

      // Avanzar al siguiente índice
      _currentNoteIndex++;

      // Programar la siguiente nota
      _scheduleNextNote();
    } catch (e) {
      print('❌ Error playing note ${note.noteName}: $e');
      // Continuar con la siguiente nota en caso de error
      _currentNoteIndex++;
      _scheduleNextNote();
    }
  }

  /// Reproducir el audio de una nota de forma continua
  Future<void> _playContinuousNoteAudio(SongNote note) async {
    try {
      await _safeAudioOperation((player) async {
        // Detener audio anterior
        await player.stop();

        // Configurar para reproducir por la duración exacta
        await player.setReleaseMode(ReleaseMode.release);

        // Reproducir desde URL
        await player.play(UrlSource(note.noteUrl!));
      });

      // Programar parada automática después de la duración
      Timer(Duration(milliseconds: note.durationMs), () async {
        await _safeAudioOperation((player) async {
          await player.stop();
        });
      });
    } catch (e) {
      print('❌ Error playing continuous note audio: $e');
    }
  }

  /// Manejar el final de una nota
  void _onNoteEnd(SongNote note) {
    print('✅ Note ended: ${note.noteName}');
    onNoteEnd?.call(note);
  }

  /// Manejar la finalización de la canción
  void _onSongComplete() {
    print('🎉 Song playback completed');
    _isPlaying = false;
    onSongComplete?.call();
  }

  /// Iniciar timer de progreso
  void _startProgressTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isPlaying || _isPaused) {
        timer.cancel();
        return;
      }

      final currentTime = _getCurrentPlayTime();
      final totalDuration = _songNotes.isNotEmpty
          ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
          : 0;

      onProgressUpdate?.call(currentTime, totalDuration);
    });
  }

  /// Obtener la nota que debería estar sonando en el tiempo actual
  SongNote? getCurrentNote() {
    if (_songNotes.isEmpty) return null;

    final currentTime = _getCurrentPlayTime();

    for (var note in _songNotes) {
      if (currentTime >= note.startTimeMs &&
          currentTime <= note.startTimeMs + note.durationMs) {
        return note;
      }
    }

    return null;
  }

  /// Obtener la próxima nota que va a sonar
  SongNote? getNextNote() {
    if (_currentNoteIndex >= _songNotes.length) return null;
    return _songNotes[_currentNoteIndex];
  }

  /// Obtener información del estado actual
  Map<String, dynamic> getPlaybackInfo() {
    return {
      'isPlaying': _isPlaying,
      'isPaused': _isPaused,
      'isMuted': !_gameAudioEnabled,
      'currentTime': _getCurrentPlayTime(),
      'totalDuration': _songNotes.isNotEmpty
          ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
          : 0,
      'currentNoteIndex': _currentNoteIndex,
      'totalNotes': _songNotes.length,
      'currentNote': getCurrentNote()?.noteName,
      'nextNote': getNextNote()?.noteName,
    };
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await stop();
    _playbackTimer?.cancel();
    _noteScheduler?.cancel();

    // Disponer del player de manera segura
    if (_continuousPlayer != null && !_isPlayerDisposed) {
      try {
        await _continuousPlayer!.dispose();
      } catch (e) {
        print('⚠️ Error disposing audio player: $e');
      }
      _continuousPlayer = null;
      _isPlayerDisposed = true;
    }

    _songNotes.clear();
    _chromaticNotesCache.clear();
    _isInitialized = false;

    print('🗑️ ContinuousSongService disposed');
  }
}
