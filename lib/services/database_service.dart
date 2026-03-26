import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_note.dart';
import '../models/chromatic_note.dart';
import 'note_spacing_service.dart';

class DatabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Getter público para acceder al cliente desde otros servicios
  static SupabaseClient get supabase => _supabase;

  // Obtener la URL mp3_file de una canción.
  static Future<String?> getSongMp3File(String songId) async {
    try {
      final response = await _supabase
          .from('songs')
          .select('mp3_file')
          .eq('id', songId)
          .maybeSingle();

      if (response == null) return null;
      final mp3 = response['mp3_file']?.toString().trim();
      if (mp3 == null || mp3.isEmpty) return null;
      return mp3;
    } catch (e) {
      print('❌ Error getting song mp3_file: $e');
      return null;
    }
  }

  // Obtener todas las notas de una canción ordenadas por tiempo de inicio
  static Future<List<SongNote>> getSongNotes(String songId) async {
    try {
      print('🔍 Fetching notes for song ID: $songId');

      // Consulta con JOIN para obtener datos de chromatic_scale
      // ARREGLADO: Ordenar por measure_number y luego por beat_position para manejar notas repetidas correctamente
      final response = await _supabase
          .from('song_notes')
          .select('''
            id,
            song_id,
            start_time_ms,
            duration_ms,
            beat_position,
            measure_number,
            note_type,
            velocity,
            chromatic_id,
            created_at,
            chromatic_scale!inner(
              id,
              instrument_id,
              english_name,
              spanish_name,
              octave,
              alternative,
              piston_1,
              piston_2,
              piston_3,
              note_url
            )
          ''')
          .eq('song_id', songId)
          .order('measure_number', ascending: true)
          .order('beat_position', ascending: true);

      print('📡 Database response: $response');

      // NUEVO: Verificar que datos llegaron
      if (response.isEmpty) {
        print('⚠️ No notes found in database for song: $songId');
        return [];
      }

      print('🔍 Processing ${response.length} notes from database...');

      final notes = (response as List<dynamic>).map((json) {
        print(
            '🔍 Processing note JSON: ${json.toString().substring(0, 200)}...');

        // Crear SongNote desde los datos principales
        final songNote = SongNote.fromJson(json as Map<String, dynamic>);

        // Si hay datos de chromatic_scale, crear ChromaticNote y asociarlo
        if (json['chromatic_scale'] != null) {
          print(
              '✅ Found chromatic_scale data for note: ${json['chromatic_scale']['english_name']}');
          final chromaticData = json['chromatic_scale'] as Map<String, dynamic>;
          final chromaticNote = ChromaticNote.fromJson(chromaticData);
          songNote.setChromaticNote(chromaticNote);
        } else {
          print(
              '❌ No chromatic_scale data found for note with chromatic_id: ${json['chromatic_id']}');
        }

        return songNote;
      }).toList();

      print(
          '✅ Successfully converted ${notes.length} notes from database with chromatic data');
      return notes;
    } catch (e) {
      print('❌ Error al obtener notas de la canción: $e');
      throw Exception('Error al cargar las notas de la canción: $e');
    }
  }

  // Obtener metadatos de una canción (BPM, duración, etc.)
  static Future<Map<String, dynamic>?> getSongMetadata(String songId) async {
    try {
      final response = await _supabase
          .from('songs')
          .select(
              'name, bpm, time_signature, key_signature, duration_seconds, difficulty_level')
          .eq('id', songId)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error al obtener metadatos de la canción: $e');
      return null;
    }
  }

  // Obtener notas por rango de tiempo (útil para cargar solo las notas próximas)
  static Future<List<SongNote>> getSongNotesInTimeRange(
      String songId, int startTimeMs, int endTimeMs) async {
    try {
      final response = await _supabase
          .from('song_notes')
          .select('''
            id,
            song_id,
            start_time_ms,
            duration_ms,
            beat_position,
            measure_number,
            note_type,
            velocity,
            chromatic_id,
            created_at,
            chromatic_scale!inner(
              id,
              instrument_id,
              english_name,
              spanish_name,
              octave,
              alternative,
              piston_1,
              piston_2,
              piston_3,
              note_url
            )
          ''')
          .eq('song_id', songId)
          .gte('start_time_ms', startTimeMs)
          .lte('start_time_ms', endTimeMs)
          .order('measure_number', ascending: true)
          .order('beat_position', ascending: true);

      final notes = (response as List<dynamic>).map((json) {
        final songNote = SongNote.fromJson(json as Map<String, dynamic>);

        if (json['chromatic_scale'] != null) {
          final chromaticData = json['chromatic_scale'] as Map<String, dynamic>;
          final chromaticNote = ChromaticNote.fromJson(chromaticData);
          songNote.setChromaticNote(chromaticNote);
        }

        return songNote;
      }).toList();

      return notes;
    } catch (e) {
      print('Error al obtener notas en rango de tiempo: $e');
      throw Exception('Error al cargar las notas: $e');
    }
  }

  // Obtener el total de notas de una canción
  static Future<int> getTotalNotesCount(String songId) async {
    try {
      final response =
          await _supabase.from('song_notes').select('id').eq('song_id', songId);

      return (response as List<dynamic>).length;
    } catch (e) {
      print('Error al obtener el total de notas: $e');
      return 0;
    }
  }

  // Obtener la duración total de la canción basada en las notas
  static Future<int> getSongDurationFromNotes(String songId) async {
    try {
      final response = await _supabase
          .from('song_notes')
          .select('start_time_ms, duration_ms')
          .eq('song_id', songId)
          .order('start_time_ms', ascending: false)
          .limit(1)
          .single();

      final lastNoteStartTime = response['start_time_ms'] as int;
      final lastNoteDuration = response['duration_ms'] as int;

      return lastNoteStartTime + lastNoteDuration;
    } catch (e) {
      print('Error al calcular duración de la canción: $e');
      return 30000; // Default 30 segundos
    }
  }

  // Verificar si una canción tiene notas disponibles
  static Future<bool> hasSongNotes(String songId) async {
    try {
      final count = await getTotalNotesCount(songId);
      return count > 0;
    } catch (e) {
      print('Error al verificar si la canción tiene notas: $e');
      return false;
    }
  }

  // Obtener estadísticas de una canción
  static Future<Map<String, dynamic>> getSongStats(String songId) async {
    try {
      final notesCount = await getTotalNotesCount(songId);
      final duration = await getSongDurationFromNotes(songId);
      final metadata = await getSongMetadata(songId);

      return {
        'totalNotes': notesCount,
        'durationMs': duration,
        'bpm': metadata?['bpm'] ?? 120,
        'difficulty': metadata?['difficulty_level'] ?? 'beginner',
        'keySignature': metadata?['key_signature'] ?? 'C Major',
        'timeSignature': metadata?['time_signature'] ?? '4/4',
      };
    } catch (e) {
      print('Error al obtener estadísticas de la canción: $e');
      return {
        'totalNotes': 0,
        'durationMs': 30000,
        'bpm': 120,
        'difficulty': 'beginner',
        'keySignature': 'C Major',
        'timeSignature': '4/4',
      };
    }
  }

  // MÉTODOS PARA MANEJAR ESPACIADO DE NOTAS

  /// Insertar una nueva nota con espaciado automático para evitar solapamientos
  static Future<SongNote?> insertNoteWithSpacing({
    required String songId,
    required String chromaticId,
    int? preferredStartTime,
    int? duration,
    String noteType = 'quarter',
    int velocity = 120,
  }) async {
    try {
      // Obtener notas existentes de la canción
      final existingNotesResponse = await _supabase
          .from('song_notes')
          .select('start_time_ms, duration_ms')
          .eq('song_id', songId);

      final existingNotes = existingNotesResponse as List<dynamic>;

      // Calcular tiempo de inicio seguro
      final safeStartTime = NoteSpacingService.calculateSafeStartTime(
        existingNotes.cast<Map<String, dynamic>>(),
        preferredStartTime,
      );

      // Insertar la nueva nota
      final response = await _supabase
          .from('song_notes')
          .insert({
            'song_id': songId,
            'chromatic_id': chromaticId,
            'start_time_ms': safeStartTime,
            'duration_ms': duration ?? NoteSpacingService.defaultNoteDuration,
            'note_type': noteType,
            'velocity': velocity,
          })
          .select()
          .single();

      print('✅ Nota insertada con espaciado en: ${safeStartTime}ms');
      return SongNote.fromJson(response);
    } catch (e) {
      print('❌ Error insertando nota con espaciado: $e');
      return null;
    }
  }

  /// Validar tiempos de una canción y reportar conflictos
  static Future<List<String>> validateSongTiming(String songId) async {
    try {
      final notesResponse = await _supabase
          .from('song_notes')
          .select('start_time_ms, duration_ms')
          .eq('song_id', songId)
          .order('start_time_ms');

      final notes = notesResponse as List<dynamic>;
      return NoteSpacingService.validateNoteSequence(
        notes.cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      print('❌ Error validando tiempos: $e');
      return ['Error al validar: $e'];
    }
  }

  /// Generar una secuencia de notas con espaciado automático
  static Future<List<SongNote>> createSpacedNoteSequence({
    required String songId,
    required List<String> chromaticIds,
    int startTime = 0,
    int? customSpacing,
  }) async {
    try {
      final spacedTimes = NoteSpacingService.generateSpacedTimes(
        chromaticIds.length,
        startTime: startTime,
        customSpacing: customSpacing,
      );

      final createdNotes = <SongNote>[];

      for (int i = 0; i < chromaticIds.length; i++) {
        final response = await _supabase
            .from('song_notes')
            .insert({
              'song_id': songId,
              'chromatic_id': chromaticIds[i],
              'start_time_ms': spacedTimes[i],
              'duration_ms': NoteSpacingService.defaultNoteDuration,
              'note_type': 'quarter',
              'velocity': 80,
            })
            .select()
            .single();

        createdNotes.add(SongNote.fromJson(response));
      }

      print(
          '✅ Secuencia de ${chromaticIds.length} notas creada con espaciado automático');
      return createdNotes;
    } catch (e) {
      print('❌ Error creando secuencia espaciada: $e');
      return [];
    }
  }
}
