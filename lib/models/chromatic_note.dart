import 'package:flutter/material.dart';

class ChromaticNote {
  final int id;
  final int instrumentId;
  final String englishName; // F#3, G3, etc.
  final String spanishName; // Fa sostenido, Sol, etc.
  final int octave;
  final String? alternative; // Para notas como Gb3, Ab3
  final String piston1; // "Tocando" o "Aire"
  final String piston2; // "Tocando" o "Aire"
  final String piston3; // "Tocando" o "Aire"
  final String? noteUrl; // URL opcional del audio

  ChromaticNote({
    required this.id,
    required this.instrumentId,
    required this.englishName,
    required this.spanishName,
    required this.octave,
    this.alternative,
    required this.piston1,
    required this.piston2,
    required this.piston3,
    this.noteUrl,
  });

  // Factory constructor para crear desde JSON/Map (respuesta de Supabase)
  factory ChromaticNote.fromJson(Map<String, dynamic> json) {
    return ChromaticNote(
      id: json['id'] as int,
      instrumentId: json['instrument_id'] as int,
      englishName: json['english_name'] as String,
      spanishName: json['spanish_name'] as String,
      octave: json['octave'] as int,
      alternative: json['alternative'] as String?,
      piston1: json['piston_1'] as String,
      piston2: json['piston_2'] as String,
      piston3: json['piston_3'] as String,
      noteUrl: json['note_url'] as String?,
    );
  }

  // Convertir a Map para enviar a la base de datos
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'instrument_id': instrumentId,
      'english_name': englishName,
      'spanish_name': spanishName,
      'octave': octave,
      'alternative': alternative,
      'piston_1': piston1,
      'piston_2': piston2,
      'piston_3': piston3,
      'note_url': noteUrl,
    };
  }

  // Obtener la lista de pistones que deben presionarse
  List<int> get requiredPistons {
    List<int> pistons = [];
    if (piston1 == "Tocando") pistons.add(1);
    if (piston2 == "Tocando") pistons.add(2);
    if (piston3 == "Tocando") pistons.add(3);
    return pistons;
  }

  // Verificar si todos los pistones están en "Aire" (nota libre)
  bool get isOpenNote {
    return piston1 == "Aire" && piston2 == "Aire" && piston3 == "Aire";
  }

  // Verificar si los pistones presionados coinciden exactamente
  bool matchesPistonCombination(Set<int> pressedPistons) {
    final requiredSet = requiredPistons.toSet();
    return requiredSet.difference(pressedPistons).isEmpty &&
        pressedPistons.difference(requiredSet).isEmpty;
  }

  // Obtener el color base para la nota según los pistones requeridos
  Color get noteColor {
    final pistons = requiredPistons;
    if (pistons.isEmpty) {
      return Colors.white; // Sin pistones (nota natural/aire)
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
      return Colors.orange; // Combinación de pistones
    }
  }

  @override
  String toString() {
    return 'ChromaticNote{id: $id, note: $englishName, pistons: [$piston1, $piston2, $piston3]}';
  }
}
