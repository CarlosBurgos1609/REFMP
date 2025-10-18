import 'dart:async';
import '../models/song_note.dart';
import '../models/chromatic_note.dart';
import 'database_service.dart';
import 'note_audio_service.dart';

/// Servicio simplificado para reproducir canciones como audio continuo
/// Enfoque: Control inteligente de mute/unmute sin manejar reproducción directa
class ContinuousAudioController {
  static final ContinuousAudioController _instance =
      ContinuousAudioController._internal();
  factory ContinuousAudioController() => _instance;
  ContinuousAudioController._internal();

  // Lista de notas de la canción ordenadas por tiempo
  List<SongNote> _songNotes = [];
  Map<int, ChromaticNote> _chromaticNotesCache = {};

  // Control de reproducción
  bool _isInitialized = false;
  bool _isActive = false;
  bool _isPaused = false;

  // Timing y sincronización
  int _songStartTime = 0;
  int _currentNoteIndex = 0;
  Timer? _progressTimer;
  Timer? _noteTracker;

  // Callbacks para eventos del juego
  Function(SongNote)? onNoteStart;
  Function(SongNote)? onNoteEnd;
  Function()? onSongComplete;
  Function(int currentTime, int totalDuration)? onProgressUpdate;

  // Estado del juego
  bool _playerIsOnTrack = true; // Si el jugador está tocando correctamente
  SongNote?
      _currentExpectedNote; // Nota que se espera que el jugador toque ahora

  /// Inicializar el servicio
  Future<void> initialize() async {
    try {
      await NoteAudioService.initialize();
      _isInitialized = true;
      print('✅ ContinuousAudioController initialized');
    } catch (e) {
      print('❌ Error initializing ContinuousAudioController: $e');
      _isInitialized = false;
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

  /// Iniciar seguimiento de notas (no reproduce audio, solo hace tracking)
  Future<void> startTracking() async {
    if (!_isInitialized || _songNotes.isEmpty) {
      print('⚠️ Service not initialized or no notes loaded');
      return;
    }

    print('▶️ Starting continuous audio tracking');

    _isActive = true;
    _isPaused = false;
    _currentNoteIndex = 0;
    _songStartTime = DateTime.now().millisecondsSinceEpoch;
    _playerIsOnTrack = true;

    // Iniciar el tracker de notas
    _startNoteTracking();

    // Iniciar el timer de progreso
    _startProgressTimer();
  }

  /// Pausar el tracking
  Future<void> pause() async {
    if (!_isActive) return;

    print('⏸️ Pausing tracking');

    _isPaused = true;
    _progressTimer?.cancel();
    _noteTracker?.cancel();
  }

  /// Reanudar el tracking
  Future<void> resume() async {
    if (!_isPaused) return;

    print('▶️ Resuming tracking');

    _isPaused = false;
    _songStartTime = DateTime.now().millisecondsSinceEpoch - _getCurrentTime();

    _startNoteTracking();
    _startProgressTimer();
  }

  /// Detener el tracking completamente
  Future<void> stop() async {
    print('⏹️ Stopping tracking');

    _isActive = false;
    _isPaused = false;
    _currentNoteIndex = 0;

    _progressTimer?.cancel();
    _noteTracker?.cancel();
  }

  /// Notificar cuando el jugador presiona pistones correctos
  void onPlayerHit(Set<int> pressedPistons) {
    if (_currentExpectedNote != null) {
      if (_currentExpectedNote!.matchesPistonCombination(pressedPistons)) {
        if (!_playerIsOnTrack) {
          _playerIsOnTrack = true;
          print('🔊 Player back on track!');
          // Aquí NO necesitamos unmutear nada, el juego maneja su propio audio
        }
      }
    }
  }

  /// Notificar cuando el jugador falla o deja pasar una nota
  void onPlayerMiss() {
    if (_playerIsOnTrack) {
      _playerIsOnTrack = false;
      print('🔇 Player off track!');
      // Aquí NO necesitamos mutear nada, el juego maneja su propio audio
    }
  }

  /// Verificar si el jugador está en el track
  bool get isPlayerOnTrack => _playerIsOnTrack;

  /// Obtener la nota que se espera que el jugador toque ahora
  SongNote? get currentExpectedNote => _currentExpectedNote;

  /// Obtener tiempo actual desde el inicio
  int _getCurrentTime() {
    if (!_isActive || _isPaused) return 0;
    return DateTime.now().millisecondsSinceEpoch - _songStartTime;
  }

  /// Iniciar tracking de notas
  void _startNoteTracking() {
    _noteTracker?.cancel();
    _noteTracker = Timer.periodic(Duration(milliseconds: 50), (timer) {
      if (!_isActive || _isPaused) {
        timer.cancel();
        return;
      }

      _updateCurrentNote();
    });
  }

  /// Actualizar la nota actual esperada
  void _updateCurrentNote() {
    if (_currentNoteIndex >= _songNotes.length) {
      if (_currentExpectedNote != null) {
        // La canción ha terminado
        _currentExpectedNote = null;
        _onSongComplete();
      }
      return;
    }

    final currentTime = _getCurrentTime();
    final nextNote = _songNotes[_currentNoteIndex];

    // Verificar si es hora de la siguiente nota (con ventana de tolerancia de 500ms antes)
    if (currentTime >= nextNote.startTimeMs - 500) {
      if (_currentExpectedNote != nextNote) {
        // Nueva nota activa
        _currentExpectedNote = nextNote;
        onNoteStart?.call(nextNote);
        print(
            '🎵 Expected note: ${nextNote.noteName} at ${nextNote.startTimeMs}ms');
      }
    }

    // Verificar si la nota actual ha terminado
    if (_currentExpectedNote != null &&
        currentTime >=
            _currentExpectedNote!.startTimeMs +
                _currentExpectedNote!.durationMs) {
      onNoteEnd?.call(_currentExpectedNote!);
      _currentNoteIndex++;
      _currentExpectedNote = null;
    }
  }

  /// Manejar la finalización de la canción
  void _onSongComplete() {
    print('🎉 Song tracking completed');
    _isActive = false;
    onSongComplete?.call();
  }

  /// Iniciar timer de progreso
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!_isActive || _isPaused) {
        timer.cancel();
        return;
      }

      final currentTime = _getCurrentTime();
      final totalDuration = _songNotes.isNotEmpty
          ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
          : 0;

      onProgressUpdate?.call(currentTime, totalDuration);
    });
  }

  /// Obtener información del estado actual
  Map<String, dynamic> getTrackingInfo() {
    return {
      'isActive': _isActive,
      'isPaused': _isPaused,
      'isPlayerOnTrack': _playerIsOnTrack,
      'currentTime': _getCurrentTime(),
      'totalDuration': _songNotes.isNotEmpty
          ? _songNotes.last.startTimeMs + _songNotes.last.durationMs
          : 0,
      'currentNoteIndex': _currentNoteIndex,
      'totalNotes': _songNotes.length,
      'currentNote': _currentExpectedNote?.noteName,
      'nextNote': _currentNoteIndex < _songNotes.length
          ? _songNotes[_currentNoteIndex].noteName
          : null,
    };
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await stop();
    _progressTimer?.cancel();
    _noteTracker?.cancel();

    _songNotes.clear();
    _chromaticNotesCache.clear();
    _isInitialized = false;

    print('🗑️ ContinuousAudioController disposed');
  }
}
