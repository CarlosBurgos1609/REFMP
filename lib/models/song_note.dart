import 'package:flutter/material.dart';
import 'chromatic_note.dart';

class SongNote {
  final String id;
  final String songId;
  final int startTimeMs; // Tiempo de inicio en milisegundos
  final int durationMs; // Duración en milisegundos
  final double beatPosition; // Posición en el compás
  final int measureNumber; // Número de compás
  final String noteType; // quarter, eighth, half, etc.
  final int velocity; // Intensidad de la nota (80 por defecto)
  final int? chromaticId; // ID que conecta con chromatic_scale
  final DateTime createdAt;

  // NUEVO: Referencia a ChromaticNote (debe ser configurada externamente)
  ChromaticNote? _chromaticNote;

  SongNote({
    required this.id,
    required this.songId,
    required this.startTimeMs,
    required this.durationMs,
    required this.beatPosition,
    required this.measureNumber,
    required this.noteType,
    required this.velocity,
    this.chromaticId, // opcional para compatibilidad
    required this.createdAt,
  });

  // Factory constructor para crear desde JSON/Map (respuesta de Supabase)
  factory SongNote.fromJson(Map<String, dynamic> json) {
    return SongNote(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      startTimeMs: json['start_time_ms'] as int,
      durationMs: json['duration_ms'] as int,
      beatPosition: (json['beat_position'] as num).toDouble(),
      measureNumber: json['measure_number'] as int,
      noteType: json['note_type'] as String,
      velocity: json['velocity'] as int,
      chromaticId: json['chromatic_id'] as int?, // puede ser null
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // toJson() removido - no se necesita para solo lectura de datos

  void setChromaticNote(ChromaticNote? chromaticNote) {
    _chromaticNote = chromaticNote;
  }

  // Obtener la referencia a ChromaticNote (para usar en FallingNote)
  ChromaticNote? get chromaticNote => _chromaticNote;

  // Obtener el nombre de la nota desde ChromaticNote (english_name)
  String get noteName {
    if (_chromaticNote != null) {
      return _chromaticNote!
          .englishName; // Usar english_name en lugar de spanish_name
    }
    // Fallback: retornar 'Unknown' si no hay ChromaticNote
    return 'Unknown';
  }

  // Obtener la URL del sonido de la nota
  String? get noteUrl {
    if (_chromaticNote != null) {
      return _chromaticNote!.noteUrl;
    }
    return null;
  }

  // Obtener combinación de pistones desde ChromaticNote (ACTUALIZADO)
  List<int> get pistonCombination {
    if (_chromaticNote != null) {
      return _chromaticNote!.requiredPistons;
    }

    // Fallback: mapeo manual para compatibilidad
    return _getLegacyPistonCombination();
  }

  // Método de fallback para compatibilidad (mapeo simplificado)
  List<int> _getLegacyPistonCombination() {
    // Sin ChromaticNote, retornar lista vacía (nota abierta por defecto)
    return [];
  }

  // Obtener color basado en los pistones requeridos
  Color get noteColor {
    if (_chromaticNote != null) {
      return _chromaticNote!.noteColor;
    }

    // Fallback color logic
    final pistons = pistonCombination;
    if (pistons.isEmpty) {
      return Colors.white; // Sin pistones (nota natural)
    } else if (pistons.length == 1) {
      switch (pistons.first) {
        case 1:
          return Colors.red;
        case 2:
          return Colors.green;
        case 3:
          return Colors.blue;
        default:
          return Colors.white;
      }
    } else {
      // Combinación de pistones - color mezclado
      return Colors.orange;
    }
  }

  // Verificar si los pistones presionados coinciden exactamente
  bool matchesPistonCombination(Set<int> pressedPistons) {
    if (_chromaticNote != null) {
      return _chromaticNote!.matchesPistonCombination(pressedPistons);
    }

    // Fallback logic
    final requiredPistons = pistonCombination.toSet();
    return requiredPistons.difference(pressedPistons).isEmpty &&
        pressedPistons.difference(requiredPistons).isEmpty;
  }

  // Verificar si es una nota libre (todos los pistones en "Aire")
  bool get isOpenNote {
    if (_chromaticNote != null) {
      return _chromaticNote!.isOpenNote;
    }
    return pistonCombination.isEmpty;
  }

  @override
  String toString() {
    return 'SongNote{noteName: $noteName, startTime: ${startTimeMs}ms, duration: ${durationMs}ms, pistons: $pistonCombination, chromaticId: $chromaticId}';
  }
}
