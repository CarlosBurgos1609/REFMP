import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song_note.dart';

class DatabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Obtener todas las notas de una canción ordenadas por tiempo de inicio
  static Future<List<SongNote>> getSongNotes(String songId) async {
    try {
      print('🔍 Fetching notes for song ID: $songId');
      final response = await _supabase
          .from('song_notes')
          .select('*')
          .eq('song_id', songId)
          .order('start_time_ms', ascending: true);

      print('📡 Database response: $response');
      final notes = (response as List<dynamic>)
          .map((json) => SongNote.fromJson(json as Map<String, dynamic>))
          .toList();

      print('✅ Successfully converted ${notes.length} notes from database');
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
          .select('*')
          .eq('song_id', songId)
          .gte('start_time_ms', startTimeMs)
          .lte('start_time_ms', endTimeMs)
          .order('start_time_ms', ascending: true);

      return (response as List<dynamic>)
          .map((json) => SongNote.fromJson(json as Map<String, dynamic>))
          .toList();
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
}
