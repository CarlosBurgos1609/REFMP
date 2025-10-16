class NoteSpacingService {
  // Duración mínima entre notas en milisegundos para evitar solapamiento
  static const int minNoteSpacing = 300; // 300ms entre notas
  static const int defaultNoteDuration = 500; // 500ms duración por defecto
  
  /// Calcula el tiempo de inicio sugerido para una nueva nota
  /// considerando las notas existentes para evitar solapamiento
  static int calculateSafeStartTime(
    List<Map<String, dynamic>> existingNotes,
    int? preferredStartTime,
  ) {
    // Si no hay notas existentes, usar el tiempo preferido o 0
    if (existingNotes.isEmpty) {
      return preferredStartTime ?? 0;
    }
    
    // Ordenar notas por tiempo de inicio
    final sortedNotes = List<Map<String, dynamic>>.from(existingNotes);
    sortedNotes.sort((a, b) => 
        (a['start_time_ms'] as int).compareTo(b['start_time_ms'] as int));
    
    int suggestedTime = preferredStartTime ?? 0;
    
    // Verificar cada nota existente
    for (final note in sortedNotes) {
      final noteStart = note['start_time_ms'] as int;
      final noteDuration = note['duration_ms'] as int? ?? defaultNoteDuration;
      final noteEnd = noteStart + noteDuration;
      
      // Si hay conflicto, mover la nueva nota después de esta
      if (_hasTimeConflict(suggestedTime, noteStart, noteEnd)) {
        suggestedTime = noteEnd + minNoteSpacing;
      }
    }
    
    return suggestedTime;
  }
  
  /// Verifica si hay conflicto de tiempo entre dos notas
  static bool _hasTimeConflict(int newNoteStart, int existingStart, int existingEnd) {
    final newNoteDuration = defaultNoteDuration;
    final newNoteEnd = newNoteStart + newNoteDuration;
    
    // Hay conflicto si las notas se solapan
    return !(newNoteEnd + minNoteSpacing <= existingStart || 
             newNoteStart >= existingEnd + minNoteSpacing);
  }
  
  /// Genera una secuencia de tiempos espaciados automáticamente
  static List<int> generateSpacedTimes(int noteCount, {
    int startTime = 0,
    int? customSpacing,
  }) {
    final spacing = customSpacing ?? (defaultNoteDuration + minNoteSpacing);
    return List.generate(noteCount, (index) => startTime + (index * spacing));
  }
  
  /// Valida si una lista de notas tiene conflictos de tiempo
  static List<String> validateNoteSequence(List<Map<String, dynamic>> notes) {
    final conflicts = <String>[];
    
    for (int i = 0; i < notes.length; i++) {
      final noteA = notes[i];
      final startA = noteA['start_time_ms'] as int;
      final durationA = noteA['duration_ms'] as int? ?? defaultNoteDuration;
      final endA = startA + durationA;
      
      for (int j = i + 1; j < notes.length; j++) {
        final noteB = notes[j];
        final startB = noteB['start_time_ms'] as int;
        final durationB = noteB['duration_ms'] as int? ?? defaultNoteDuration;
        final endB = startB + durationB;
        
        if (_hasTimeConflict(startA, startB, endB)) {
          conflicts.add(
            'Conflicto entre nota ${i + 1} (${startA}ms-${endA}ms) '
            'y nota ${j + 1} (${startB}ms-${endB}ms)'
          );
        }
      }
    }
    
    return conflicts;
  }
}