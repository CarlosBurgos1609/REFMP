import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/song_note.dart';

/// Configuración de tiempo para una nota específica
class NoteTiming {
  final int startMs;
  final int durationMs;

  const NoteTiming({required this.startMs, required this.durationMs});
}

/// Servicio centralizado para la reproducción de sonidos de notas de trompeta
/// Reutilizable por todos los niveles de juego (begginer, medium, difficult)
class TrumpetAudioService {
  static TrumpetAudioService? _instance;
  late AudioPlayer _audioPlayer;
  Timer? _currentNoteTimer; // Timer para controlar la duración de 2 segundos

  // Singleton pattern para asegurar una sola instancia
  static TrumpetAudioService get instance {
    _instance ??= TrumpetAudioService._internal();
    return _instance!;
  }

  TrumpetAudioService._internal() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setVolume(0.7); // Volumen al 70%
  }

  // Mapeo completo de notas musicales a archivos de audio
  static const Map<String, String> _noteToAudioFile = {
    // Octava 3
    'F#3': 'F#3.ogg',
    'GB3': 'F#3.ogg', // Gb es lo mismo que F#
    'G3': 'G3.ogg',
    'G#3': 'G#3.ogg',
    'AB3': 'G#3.ogg', // Ab es lo mismo que G#
    'A3': 'A3.ogg',
    'A#3': 'A#3.ogg',
    'BB3': 'A#3.ogg', // Bb es lo mismo que A#
    'B3': 'B3.ogg',

    // Octava 4
    'C4': 'C4.ogg',
    'C#4': 'C#4.ogg',
    'DB4': 'C#4.ogg', // Db es lo mismo que C#
    'D4': 'D4.ogg',
    'D#4': 'D#4.ogg',
    'EB4': 'D#4.ogg', // Eb es lo mismo que D#
    'E4': 'E4.ogg',
    'F4': 'F4.ogg',
    'F#4': 'F#4.ogg',
    'GB4': 'F#4.ogg', // Gb es lo mismo que F#
    'G4': 'G4.ogg',
    'G#4': 'G#4.ogg',
    'AB4': 'G#4.ogg', // Ab es lo mismo que G#
    'A4': 'A4.ogg',
    'A#4': 'A#4.ogg',
    'BB4': 'A#4.ogg', // Bb es lo mismo que A#
    'B4': 'B4.ogg',

    // Octava 5
    'C5': 'C5.ogg',
    'C#5': 'C#5.ogg',
    'DB5': 'C#5.ogg', // Db es lo mismo que C#
    'D5': 'D5.ogg',
    'D#5': 'D#5.ogg',
    'EB5': 'D#5.ogg', // Eb es lo mismo que D#
    'E5': 'E5.ogg',
    'F5': 'F5.ogg',
    'F#5': 'F#5.ogg',
    'GB5': 'F#5.ogg', // Gb es lo mismo que F#
    'G5': 'G5.ogg',
    'G#5': 'G#5.ogg',
    'AB5': 'G#5.ogg', // Ab es lo mismo que G#
    'A5': 'A5.ogg',
    'A#5': 'A#5.ogg',
    'BB5': 'A#5.ogg', // Bb es lo mismo que A#
    'B5': 'B5.ogg',

    // Octava 6
    'C6': 'C6.ogg',
    'C#6': 'C#6.ogg',
    'DB6': 'C#6.ogg', // Db es lo mismo que C#
    'D6': 'D6.ogg',
    'D#6': 'D#6.ogg',
    'EB6': 'D#6.ogg', // Eb es lo mismo que D#
    'E6': 'E6.ogg',
    'F#6': 'F#6.ogg',
    'GB6': 'F#6.ogg', // Gb es lo mismo que F#
  };

  // Configuraciones específicas de tiempo para cada nota
  // Todas las notas ahora empiezan a los 0.5 segundos (500ms) para cortar el inicio
  static const Map<String, NoteTiming> _noteTimingConfig = {
    // Octava 3 - Todas empiezan a los 500ms
    'F#3': NoteTiming(startMs: 500, durationMs: 1000),
    'G3': NoteTiming(startMs: 500, durationMs: 1200),
    'G#3': NoteTiming(startMs: 500, durationMs: 1000),
    'A3': NoteTiming(startMs: 500, durationMs: 1100),
    'A#3': NoteTiming(startMs: 500, durationMs: 900),
    'B3': NoteTiming(startMs: 500, durationMs: 1000),

    // Octava 4 - Todas empiezan a los 500ms
    'C4': NoteTiming(startMs: 500, durationMs: 1000),
    'C#4': NoteTiming(startMs: 500, durationMs: 1100),
    'D4': NoteTiming(startMs: 500, durationMs: 1000),
    'D#4': NoteTiming(startMs: 500, durationMs: 1000),
    'E4': NoteTiming(startMs: 500, durationMs: 1200),
    'F4': NoteTiming(startMs: 500, durationMs: 1000),
    'F#4': NoteTiming(startMs: 500, durationMs: 1000),
    'G4': NoteTiming(startMs: 500, durationMs: 1100),
    'G#4': NoteTiming(startMs: 500, durationMs: 1000),
    'A4': NoteTiming(startMs: 500, durationMs: 1200),
    'A#4': NoteTiming(startMs: 500, durationMs: 1000),
    'B4': NoteTiming(startMs: 500, durationMs: 1000),

    // Octava 5 - Todas empiezan a los 500ms
    'C5': NoteTiming(startMs: 500, durationMs: 1000),
    'C#5': NoteTiming(startMs: 500, durationMs: 1000),
    'D5': NoteTiming(startMs: 500, durationMs: 1100),
    'D#5': NoteTiming(startMs: 500, durationMs: 1000),
    'E5': NoteTiming(startMs: 500, durationMs: 1000),
    'F5': NoteTiming(startMs: 500, durationMs: 1200),
    'F#5': NoteTiming(startMs: 500, durationMs: 1000),
    'G5': NoteTiming(startMs: 500, durationMs: 1100),
    'G#5': NoteTiming(startMs: 500, durationMs: 1000),
    'A5': NoteTiming(startMs: 500, durationMs: 1000),
    'A#5': NoteTiming(startMs: 500, durationMs: 1000),
    'B5': NoteTiming(startMs: 500, durationMs: 1100),

    // Octava 6 - Todas empiezan a los 500ms
    'C6': NoteTiming(startMs: 500, durationMs: 1000),
    'C#6': NoteTiming(startMs: 500, durationMs: 1200),
    'D6': NoteTiming(startMs: 500, durationMs: 1000),
    'D#6': NoteTiming(startMs: 500, durationMs: 1100),
    'E6': NoteTiming(startMs: 500, durationMs: 1000),
    'F#6': NoteTiming(startMs: 500, durationMs: 1200),
  };

  /// Reproducir el sonido correspondiente a una nota musical
  /// [noteName] - Nombre de la nota (ej: F4, Bb4, G#5, etc.)
  /// Reproduce la mejor parte del audio donde la nota suena más clara
  /// Duración: 2 segundos completos o hasta que cambie la nota
  Future<void> playNote(String noteName) async {
    try {
      // Normalizar el nombre de la nota (convertir bemoles a sostenidos)
      String normalizedNote = _normalizeNoteName(noteName);

      // Buscar el archivo de audio correspondiente
      final audioFile = _noteToAudioFile[normalizedNote];
      if (audioFile != null) {
        // Cancelar el timer anterior si existe
        _currentNoteTimer?.cancel();

        // Detener cualquier sonido anterior
        await _audioPlayer.stop();

        // Obtener configuración de tiempo específica para esta nota
        final timing = _getNoteTimingConfig(normalizedNote);

        // Reproducir el nuevo sonido con la configuración específica
        await _audioPlayer.play(
          AssetSource('Trumpet_notes/$audioFile'),
          position: Duration(milliseconds: timing.startMs),
        );

        // Programar la parada del audio después de 2 segundos
        _currentNoteTimer = Timer(Duration(milliseconds: 2000), () async {
          try {
            if (_audioPlayer.state == PlayerState.playing) {
              await _audioPlayer.stop();
            }
          } catch (e) {
            print('❌ Error stopping audio after 2 seconds: $e');
          }
        });

        print('🎵 Playing trumpet note: $audioFile for note: $noteName');
        print('⏱️ Duration: 2 seconds (starting at ${timing.startMs}ms)');
        print('🔄 Will be interrupted if new note is played');
      } else {
        print(
            '⚠️ No audio file found for note: $noteName (normalized: $normalizedNote)');
      }
    } catch (e) {
      print('❌ Error playing trumpet note sound: $e');
    }
  }

  /// Reproducir sonido directamente desde un objeto SongNote
  /// [songNote] - Objeto SongNote que contiene la información de la nota
  Future<void> playSongNote(SongNote songNote) async {
    await playNote(songNote.noteName);
  }

  /// Reproducir una nota con control personalizado de tiempo
  /// [noteName] - Nombre de la nota
  /// [startMs] - Tiempo de inicio en milisegundos (por defecto 500ms)
  /// [durationMs] - Duración de reproducción en milisegundos (por defecto 1000ms)
  Future<void> playNoteWithTiming(
    String noteName, {
    int startMs = 500,
    int durationMs = 1000,
  }) async {
    try {
      // Normalizar el nombre de la nota
      String normalizedNote = _normalizeNoteName(noteName);

      // Buscar el archivo de audio correspondiente
      final audioFile = _noteToAudioFile[normalizedNote];
      if (audioFile != null) {
        // Detener cualquier sonido anterior
        await _audioPlayer.stop();

        // Reproducir desde la posición específica
        await _audioPlayer.play(
          AssetSource('Trumpet_notes/$audioFile'),
          position: Duration(milliseconds: startMs),
        );

        // Programar la parada después de la duración especificada
        Future.delayed(Duration(milliseconds: durationMs), () async {
          try {
            if (_audioPlayer.state == PlayerState.playing) {
              await _audioPlayer.stop();
            }
          } catch (e) {
            print('❌ Error stopping audio: $e');
          }
        });

        print(
            '🎵 Playing note: $audioFile (${startMs}ms - ${startMs + durationMs}ms)');
      } else {
        print('⚠️ No audio file found for note: $noteName');
      }
    } catch (e) {
      print('❌ Error playing trumpet note with timing: $e');
    }
  }

  /// Normalizar el nombre de la nota convirtiendo bemoles a sostenidos equivalentes
  String _normalizeNoteName(String noteName) {
    String normalizedNote = noteName.toUpperCase();

    // Convertir bemoles a sostenidos equivalentes
    if (normalizedNote.contains('B')) {
      // Mapeo de bemoles a sostenidos
      final bemolesMap = {
        'DB': 'C#',
        'EB': 'D#',
        'GB': 'F#',
        'AB': 'G#',
        'BB': 'A#',
      };

      for (final entry in bemolesMap.entries) {
        if (normalizedNote.startsWith(entry.key)) {
          normalizedNote = normalizedNote.replaceFirst(entry.key, entry.value);
          break;
        }
      }
    }

    return normalizedNote;
  }

  /// Obtener la configuración de tiempo específica para una nota
  /// Si no existe configuración específica, usa valores por defecto (empezando a los 500ms)
  NoteTiming _getNoteTimingConfig(String normalizedNoteName) {
    return _noteTimingConfig[normalizedNoteName] ??
        const NoteTiming(
            startMs: 500,
            durationMs: 1000); // Valores por defecto empezando a 500ms
  }

  /// Configurar el volumen del reproductor
  /// [volume] - Volumen de 0.0 a 1.0
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Detener la reproducción actual
  Future<void> stop() async {
    _currentNoteTimer?.cancel(); // Cancelar timer al detener manualmente
    await _audioPlayer.stop();
  }

  /// Pausar la reproducción actual
  Future<void> pause() async {
    _currentNoteTimer?.cancel(); // Cancelar timer al pausar
    await _audioPlayer.pause();
  }

  /// Reanudar la reproducción pausada
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  /// Obtener el estado actual del reproductor
  PlayerState get playerState => _audioPlayer.state;

  /// Verificar si hay una nota disponible para reproducir
  bool hasAudioForNote(String noteName) {
    String normalizedNote = _normalizeNoteName(noteName);
    return _noteToAudioFile.containsKey(normalizedNote);
  }

  /// Obtener la lista de todas las notas disponibles
  List<String> get availableNotes => _noteToAudioFile.keys.toList();

  /// Liberar recursos del reproductor
  void dispose() {
    _currentNoteTimer?.cancel(); // Cancelar timer antes de limpiar
    _audioPlayer.dispose();
    _instance = null;
  }
}
