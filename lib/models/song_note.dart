class SongNote {
  final String id;
  final String songId;
  final String noteName; // F4, G4, A4, etc.
  final int startTimeMs; // Tiempo de inicio en milisegundos
  final int durationMs; // Duración en milisegundos
  final double beatPosition; // Posición en el compás
  final int measureNumber; // Número de compás
  final String noteType; // quarter, eighth, half, etc.
  final int velocity; // Intensidad de la nota (80 por defecto)
  final DateTime createdAt;

  SongNote({
    required this.id,
    required this.songId,
    required this.noteName,
    required this.startTimeMs,
    required this.durationMs,
    required this.beatPosition,
    required this.measureNumber,
    required this.noteType,
    required this.velocity,
    required this.createdAt,
  });

  // Factory constructor para crear desde JSON/Map (respuesta de Supabase)
  factory SongNote.fromJson(Map<String, dynamic> json) {
    return SongNote(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      noteName: json['note_name'] as String,
      startTimeMs: json['start_time_ms'] as int,
      durationMs: json['duration_ms'] as int,
      beatPosition: (json['beat_position'] as num).toDouble(),
      measureNumber: json['measure_number'] as int,
      noteType: json['note_type'] as String,
      velocity: json['velocity'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convertir a Map para enviar a la base de datos
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song_id': songId,
      'note_name': noteName,
      'start_time_ms': startTimeMs,
      'duration_ms': durationMs,
      'beat_position': beatPosition,
      'measure_number': measureNumber,
      'note_type': noteType,
      'velocity': velocity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Mapear nombres de notas a combinaciones de pistones de trompeta
  List<int> get pistonCombination {
    switch (noteName.toUpperCase()) {
      // Octava 4
      case 'C4':
        return []; // Sin pistones (nota natural)
      case 'C#4':
      case 'DB4':
        return [2, 3]; // Pistones 2 y 3
      case 'D4':
        return [1, 3]; // Pistones 1 y 3
      case 'D#4':
      case 'EB4':
        return [2]; // Pistón 2
      case 'E4':
        return [1, 2]; // Pistones 1 y 2
      case 'F4':
        return [1]; // Pistón 1
      case 'F#4':
      case 'GB4':
        return [2]; // Pistón 2
      case 'G4':
        return []; // Sin pistones
      case 'G#4':
      case 'AB4':
        return [2, 3]; // Pistones 2 y 3
      case 'A4':
        return [1, 2]; // Pistones 1 y 2
      case 'A#4':
      case 'BB4':
        return [1]; // Pistón 1
      case 'B4':
        return [2]; // Pistón 2

      // Octava 5
      case 'C5':
        return []; // Sin pistones
      case 'C#5':
      case 'DB5':
        return [2, 3]; // Pistones 2 y 3
      case 'D5':
        return [1, 3]; // Pistones 1 y 3
      case 'D#5':
      case 'EB5':
        return [2]; // Pistón 2
      case 'E5':
        return [1, 2]; // Pistones 1 y 2
      case 'F5':
        return [1]; // Pistón 1
      case 'F#5':
      case 'GB5':
        return [2]; // Pistón 2
      case 'G5':
        return []; // Sin pistones
      case 'G#5':
      case 'AB5':
        return [2, 3]; // Pistones 2 y 3
      case 'A5':
        return [1, 2]; // Pistones 1 y 2
      case 'A#5':
      case 'BB5':
        return [1]; // Pistón 1
      case 'B5':
        return [2]; // Pistón 2

      // Octava 3 (notas graves)
      case 'C3':
        return []; // Sin pistones
      case 'C#3':
      case 'DB3':
        return [2, 3]; // Pistones 2 y 3
      case 'D3':
        return [1, 3]; // Pistones 1 y 3
      case 'D#3':
      case 'EB3':
        return [2]; // Pistón 2
      case 'E3':
        return [1, 2]; // Pistones 1 y 2
      case 'F3':
        return [1]; // Pistón 1
      case 'F#3':
      case 'GB3':
        return [2]; // Pistón 2
      case 'G3':
        return []; // Sin pistones
      case 'G#3':
      case 'AB3':
        return [2, 3]; // Pistones 2 y 3
      case 'A3':
        return [1, 2]; // Pistones 1 y 2
      case 'A#3':
      case 'BB3':
        return [1]; // Pistón 1
      case 'B3':
        return [2]; // Pistón 2

      default:
        return []; // Default sin pistones si no se reconoce la nota
    }
  }

  // Obtener el color de la nota basado en los pistones requeridos
  List<int> get noteColors {
    final pistons = pistonCombination;
    if (pistons.isEmpty) {
      return [0]; // Color especial para notas naturales (sin pistones)
    }
    return pistons;
  }

  // Verificar si la combinación de pistones presionados coincide con la nota
  bool matchesPistonCombination(Set<int> pressedPistons) {
    final requiredPistons = pistonCombination.toSet();

    // Si no se requieren pistones, no debe haber ningún pistón presionado
    if (requiredPistons.isEmpty) {
      return pressedPistons.isEmpty;
    }

    // Los pistones presionados deben coincidir exactamente con los requeridos
    return pressedPistons.length == requiredPistons.length &&
        pressedPistons.containsAll(requiredPistons);
  }

  @override
  String toString() {
    return 'SongNote{noteName: $noteName, startTime: ${startTimeMs}ms, duration: ${durationMs}ms, pistons: $pistonCombination}';
  }
}
