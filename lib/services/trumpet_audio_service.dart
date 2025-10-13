import 'package:audioplayers/audioplayers.dart';
import '../models/song_note.dart';

/// Servicio centralizado para la reproducción de sonidos de notas de trompeta
/// Reutilizable por todos los niveles de juego (begginer, medium, difficult)
class TrumpetAudioService {
  static TrumpetAudioService? _instance;
  late AudioPlayer _audioPlayer;

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

  /// Reproducir el sonido correspondiente a una nota musical
  /// [noteName] - Nombre de la nota (ej: F4, Bb4, G#5, etc.)
  Future<void> playNote(String noteName) async {
    try {
      // Normalizar el nombre de la nota (convertir bemoles a sostenidos)
      String normalizedNote = _normalizeNoteName(noteName);

      // Buscar el archivo de audio correspondiente
      final audioFile = _noteToAudioFile[normalizedNote];
      if (audioFile != null) {
        // Detener cualquier sonido anterior
        await _audioPlayer.stop();

        // Reproducir el nuevo sonido
        await _audioPlayer.play(AssetSource('Trumpet_notes/$audioFile'));
        print('🎵 Playing trumpet note: $audioFile for note: $noteName');
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

  /// Configurar el volumen del reproductor
  /// [volume] - Volumen de 0.0 a 1.0
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Detener la reproducción actual
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Pausar la reproducción actual
  Future<void> pause() async {
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
    _audioPlayer.dispose();
    _instance = null;
  }
}
