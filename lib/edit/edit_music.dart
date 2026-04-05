import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refmp/models/chromatic_note.dart';
import 'package:refmp/models/song_note.dart';
import 'package:refmp/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditMusicPage extends StatefulWidget {
  final String songId;
  final String? initialSongName;
  final Map<String, dynamic>? initialSongData;

  const EditMusicPage({
    super.key,
    required this.songId,
    this.initialSongName,
    this.initialSongData,
  });

  @override
  State<EditMusicPage> createState() => _EditMusicPageState();
}

class _EditMusicPageState extends State<EditMusicPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _songData;
  final Set<String> _songFieldKeys = <String>{};
  final List<_EditableSongNote> _notes = <_EditableSongNote>[];
  final Set<String> _deletedNoteIds = <String>{};
  final List<ChromaticNote> _chromaticOptions = <ChromaticNote>[];
  final ScrollController _timelineScrollController = ScrollController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _difficultyController = TextEditingController();
  final TextEditingController _mp3Controller = TextEditingController();
  final TextEditingController _bpmController = TextEditingController();
  final TextEditingController _timeSignatureController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPlaying = false;
  bool _hasAudioSource = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int? _instrumentId;
  int _flagMs = 0;
  double _timelineViewportWidth = 0;
  bool _isNotesStep = false;
  bool _isDraggingNote = false;
  String? _activeDraggedNoteId;
  String? _pressedNoteId;
  Timer? _noteHoldTimer;
  double? _lastDragGlobalX;
  DateTime _ignoreTapUntil = DateTime.fromMillisecondsSinceEpoch(0);
  String _songImageUrl = '';

  // Keep editor timeline in absolute song time (no fixed artificial lead-in).
  static const int _gameLeadInMs = 0;

  static const double _timelineScale = 0.12;
  static const double _laneHeight = 86;
  static const double _timelinePadding = 24;

  @override
  void initState() {
    super.initState();
    _setPortraitMode();
    _loadEditorData();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });
      _syncTimelineToPlayback(position.inMilliseconds);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  @override
  void dispose() {
    _noteHoldTimer?.cancel();
    _setPortraitMode();
    _audioPlayer.dispose();
    _timelineScrollController.dispose();
    _nameController.dispose();
    _artistController.dispose();
    _difficultyController.dispose();
    _mp3Controller.dispose();
    _bpmController.dispose();
    _timeSignatureController.dispose();
    super.dispose();
  }

  Future<void> _setLandscapeMode() async {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _setPortraitMode() async {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _goToNotesStep() async {
    await _setLandscapeMode();
    if (!mounted) return;
    setState(() {
      _isNotesStep = true;
    });
  }

  Future<void> _goToSongStep() async {
    await _setPortraitMode();
    if (!mounted) return;
    setState(() {
      _isNotesStep = false;
    });
  }

  Future<void> _loadEditorData() async {
    try {
      final response = await _supabase
          .from('songs')
          .select('*, instruments(id, name, image)')
          .eq('id', widget.songId)
          .maybeSingle();

      final Map<String, dynamic>? song = response != null
          ? Map<String, dynamic>.from(response)
          : widget.initialSongData != null
              ? Map<String, dynamic>.from(widget.initialSongData!)
              : null;

      if (song == null) {
        throw Exception('No se encontró la canción');
      }

      _songData = song;
      _songFieldKeys
        ..clear()
        ..addAll(song.keys.map((key) => key.toString()));

      _instrumentId = _extractInstrumentId(song);
      _songImageUrl = song['image']?.toString() ??
          (song['instruments'] is Map
              ? (song['instruments'] as Map)['image']?.toString() ?? ''
              : '');

      _nameController.text =
          song['name']?.toString() ?? widget.initialSongName ?? '';
      _artistController.text = song['artist']?.toString() ?? '';
      _difficultyController.text = song['difficulty']?.toString() ?? '';
      _mp3Controller.text = song['mp3_file']?.toString() ?? '';
      _bpmController.text = _parseInt(song['bpm'])?.toString() ?? '120';
      _timeSignatureController.text =
          song['time_signature']?.toString() ?? '4/4';
      _bpm = _parseInt(song['bpm']) ?? 120;
      _beatsPerMeasure =
          _parseTimeSignature(song['time_signature']?.toString());

      final notes = await DatabaseService.getSongNotes(widget.songId);
      _notes
        ..clear()
        ..addAll(notes.asMap().entries.map((entry) {
          return _EditableSongNote.fromSongNote(entry.value);
        }));
      _sortNotes();
      _syncAllNotes();
      _flagMs = 0;

      if (_instrumentId != null) {
        await _loadChromaticOptions(_instrumentId!);
      }

      _updateAudioAvailability();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading music editor: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar la canción: $e')),
        );
      }
    }
  }

  Future<void> _loadChromaticOptions(int instrumentId) async {
    try {
      final response = await _supabase
          .from('chromatic_scale')
          .select('''
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
          ''')
          .eq('instrument_id', instrumentId)
          .order('octave', ascending: true)
          .order('english_name', ascending: true);

      _chromaticOptions
        ..clear()
        ..addAll((response as List<dynamic>).map((item) {
          return ChromaticNote.fromJson(Map<String, dynamic>.from(item));
        }));
    } catch (e) {
      debugPrint('Error loading chromatic options: $e');
    }
  }

  void _updateAudioAvailability() {
    final source = _mp3Controller.text.trim();
    _hasAudioSource = source.isNotEmpty;
  }

  int get _effectiveDurationMs {
    return math.max(_totalDuration.inMilliseconds, _songDurationMs);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  int _parseTimeSignature(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 4;
    }

    final parts = value.split('/');
    if (parts.isEmpty) return 4;
    return int.tryParse(parts.first.trim()) ?? 4;
  }

  int get _songDurationMs {
    final notesEnd = _notes.isEmpty
        ? 0
        : _notes
            .map((note) => note.startTimeMs + note.durationMs)
            .reduce(math.max);
    final metadataDuration =
        (_parseInt(_songData?['duration_seconds']) ?? 0) * 1000;
    return math.max(notesEnd, metadataDuration > 0 ? metadataDuration : 30000);
  }

  void _syncAllNotes() {
    for (final note in _notes) {
      _syncNoteTiming(note);
    }
  }

  void _syncNoteTiming(_EditableSongNote note) {
    final bpm = _parseInt(_bpmController.text) ?? _bpm;
    final msPerBeat = 60000 / math.max(1, bpm);
    final totalBeats = note.startTimeMs / msPerBeat;
    final beatInMeasure = totalBeats % _beatsPerMeasure;
    note.beatPosition = double.parse(beatInMeasure.toStringAsFixed(2));
    note.noteType = _durationToNoteType(note.durationMs, msPerBeat);
    note.velocity = note.velocity.clamp(1, 127);
  }

  String _durationToNoteType(int durationMs, double msPerBeat) {
    final beats = durationMs / msPerBeat;
    if (beats >= 3.5) return 'whole';
    if (beats >= 1.75) return 'half';
    if (beats >= 0.875) return 'quarter';
    if (beats >= 0.5) return 'eighth';
    return 'sixteenth';
  }

  int _extractInstrumentId(Map<String, dynamic> song) {
    final directInstrument = _parseInt(song['instrument']);
    if (directInstrument != null) return directInstrument;

    final nestedInstrument = song['instruments'];
    if (nestedInstrument is Map<String, dynamic>) {
      return _parseInt(nestedInstrument['id']) ?? 0;
    }

    if (nestedInstrument is Map) {
      return _parseInt(nestedInstrument['id']) ?? 0;
    }

    return 0;
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      final startComparison = a.startTimeMs.compareTo(b.startTimeMs);
      if (startComparison != 0) return startComparison;
      final durationComparison = a.durationMs.compareTo(b.durationMs);
      if (durationComparison != 0) return durationComparison;
      return a.id.compareTo(b.id);
    });

    _reindexMeasureNumbers();
  }

  void _reindexMeasureNumbers() {
    for (var index = 0; index < _notes.length; index++) {
      _notes[index].measureNumber = index + 1;
    }
  }

  ChromaticNote? _findChromaticById(int? chromaticId) {
    if (chromaticId == null) return null;
    for (final note in _chromaticOptions) {
      if (note.id == chromaticId) {
        return note;
      }
    }
    return null;
  }

  Future<void> _togglePlayback() async {
    final source = _mp3Controller.text.trim();
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay archivo mp3 para reproducir.')),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
        return;
      }

      if (source.startsWith('http://') || source.startsWith('https://')) {
        await _audioPlayer.play(UrlSource(source));
      } else {
        final file = File(source);
        if (!await file.exists()) {
          throw Exception('El archivo local no existe: $source');
        }
        await _audioPlayer.play(DeviceFileSource(source));
      }

      final seekFromPosition = _currentPosition.inMilliseconds;
      if (seekFromPosition > 0) {
        await _audioPlayer.seek(Duration(milliseconds: seekFromPosition));
      }

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error reproduciendo canción: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reproducir la canción: $e')),
        );
      }
    }
  }

  Future<void> _seekPlayback(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  Future<void> _playFromFlag() async {
    if (!_hasAudioSource) return;

    await _seekPlayback(Duration(milliseconds: _flagMs));
    if (!_isPlaying) {
      await _togglePlayback();
    }
  }

  Future<void> _playFromStart() async {
    if (!_hasAudioSource) return;

    await _seekPlayback(Duration.zero);
    if (!_isPlaying) {
      await _togglePlayback();
    }
  }

  int _hitLineTimeMs() {
    if (!_timelineScrollController.hasClients || _timelineViewportWidth <= 0) {
      return _currentPosition.inMilliseconds.clamp(0, _effectiveDurationMs);
    }

    final hitX =
        _timelineScrollController.offset + (_timelineViewportWidth / 2);
    final timeMs = (hitX / _timelineScale).round() - _gameLeadInMs;
    return timeMs.clamp(0, _effectiveDurationMs);
  }

  Future<void> _playFromHitLine() async {
    if (!_hasAudioSource) return;

    final fromMs = _hitLineTimeMs();
    await _seekPlayback(Duration(milliseconds: fromMs));
    if (!_isPlaying) {
      await _togglePlayback();
    }
  }

  void _setFlagAtCurrentTime() {
    setState(() {
      _flagMs = _currentPosition.inMilliseconds.clamp(0, _effectiveDurationMs);
    });
  }

  Future<void> _cancelAndExit() async {
    final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Cancelar cambios'),
              content: const Text(
                  'Se cerrara el editor sin guardar los cambios. Deseas continuar?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Si, salir'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDiscard || !mounted) return;
    await _setPortraitMode();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<bool> _saveSong({required bool autoArrangeNotes}) async {
    if (!_formKey.currentState!.validate()) return false;

    if (autoArrangeNotes) {
      _autoArrangeNotes();
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updateData = <String, dynamic>{};

      if (_songFieldKeys.contains('name')) {
        updateData['name'] = _nameController.text.trim();
      }
      if (_songFieldKeys.contains('artist')) {
        updateData['artist'] = _artistController.text.trim();
      }
      if (_songFieldKeys.contains('difficulty')) {
        updateData['difficulty'] = _difficultyController.text.trim();
      }
      if (_songFieldKeys.contains('mp3_file')) {
        updateData['mp3_file'] = _mp3Controller.text.trim();
      }
      if (_songFieldKeys.contains('bpm')) {
        updateData['bpm'] = _parseInt(_bpmController.text) ?? _bpm;
      }
      if (_songFieldKeys.contains('time_signature')) {
        updateData['time_signature'] = _timeSignatureController.text.trim();
      }

      if (updateData.isNotEmpty) {
        await _supabase
            .from('songs')
            .update(updateData)
            .eq('id', widget.songId);
      }

      for (final deletedId in _deletedNoteIds) {
        await _supabase.from('song_notes').delete().eq('id', deletedId);
      }

      for (final note in _notes) {
        if (note.isNew) {
          final inserted = await _supabase
              .from('song_notes')
              .insert(note.toInsertMap(widget.songId))
              .select('id')
              .single();
          note.id = inserted['id'].toString();
          note.isNew = false;
        } else {
          await _supabase
              .from('song_notes')
              .update(note.toUpdateMap(widget.songId))
              .eq('id', note.id);
        }
      }

      _deletedNoteIds.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoArrangeNotes
                  ? 'Cambios guardados y notas organizadas automáticamente'
                  : 'Cambios guardados con éxito',
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error saving music editor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar los cambios: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showSaveOptionsDialog() async {
    if (_isSaving) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Guardar cambios'),
          content: const Text(
            'Elige cómo quieres guardar la edición de la canción y sus notas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('stay'),
              child:
                  const Text('Guardar notas de la canción y seguir editando'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('exit'),
              child: const Text('Guardar todos los cambios y salir'),
            ),
          ],
        );
      },
    );

    if (action == null) return;

    final saved = await _saveSong(autoArrangeNotes: false);
    if (!saved || !mounted) return;

    if (action == 'exit') {
      await _setPortraitMode();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _autoArrangeNotes() {
    if (_notes.isEmpty) return;

    final availableDuration = _songDurationMs;
    final spacing = availableDuration / (_notes.length + 1);
    final baseDuration = math.max(350, (spacing * 0.7).round());

    for (var index = 0; index < _notes.length; index++) {
      final note = _notes[index];
      note.startTimeMs = math.max(0, (spacing * (index + 1)).round());
      note.durationMs = baseDuration;
      _syncNoteTiming(note);
    }

    _sortNotes();
  }

  void _moveNote(_EditableSongNote note, double deltaDx) {
    final deltaMs = (deltaDx / _timelineScale).round();
    note.startTimeMs = math.max(0, note.startTimeMs + deltaMs);
    _syncNoteTiming(note);
    _sortNotes();
    setState(() {});
  }

  void _startNoteLongPressDrag(_EditableSongNote note, double globalX) {
    setState(() {
      _isDraggingNote = true;
      _activeDraggedNoteId = note.id;
      _lastDragGlobalX = globalX;
      _ignoreTapUntil = DateTime.now().add(const Duration(milliseconds: 350));
    });
  }

  void _updateNoteLongPressDrag(_EditableSongNote note, double globalX) {
    if (_activeDraggedNoteId != note.id) return;
    final previousX = _lastDragGlobalX ?? globalX;
    final deltaDx = globalX - previousX;
    _lastDragGlobalX = globalX;

    if (deltaDx.abs() < 0.1) return;
    _moveNote(note, deltaDx);
  }

  void _endNoteLongPressDrag(_EditableSongNote note) {
    if (_activeDraggedNoteId != note.id) return;
    setState(() {
      _isDraggingNote = false;
      _activeDraggedNoteId = null;
      _pressedNoteId = null;
      _lastDragGlobalX = null;
      _ignoreTapUntil = DateTime.now().add(const Duration(milliseconds: 180));
    });
  }

  void _cancelPendingNoteHold() {
    _noteHoldTimer?.cancel();
    _noteHoldTimer = null;
  }

  void _onNotePointerDown(
    _EditableSongNote note,
    PointerDownEvent event,
    double visualWidth,
    bool isThinNote,
  ) {
    final localX = event.localPosition.dx;
    final onResizeHandle =
        !isThinNote && (localX <= 22 || localX >= (visualWidth - 22));
    if (onResizeHandle) return;

    _cancelPendingNoteHold();
    _pressedNoteId = note.id;
    _lastDragGlobalX = event.position.dx;

    _noteHoldTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _pressedNoteId != note.id) return;
      _startNoteLongPressDrag(note, event.position.dx);
    });
  }

  void _onNotePointerMove(_EditableSongNote note, PointerMoveEvent event) {
    if (_activeDraggedNoteId != note.id) return;
    _updateNoteLongPressDrag(note, event.position.dx);
  }

  void _onNotePointerUp(_EditableSongNote note) {
    _cancelPendingNoteHold();

    final isDraggingThisNote = _activeDraggedNoteId == note.id;
    final wasPressedThisNote = _pressedNoteId == note.id;
    _pressedNoteId = null;

    if (isDraggingThisNote) {
      _endNoteLongPressDrag(note);
      return;
    }

    if (wasPressedThisNote) {
      _onNoteTap(note);
    }
  }

  void _onNotePointerCancel(_EditableSongNote note) {
    _cancelPendingNoteHold();

    if (_activeDraggedNoteId == note.id) {
      _endNoteLongPressDrag(note);
      return;
    }

    if (_pressedNoteId == note.id) {
      _pressedNoteId = null;
    }
  }

  bool _shouldHandleTapOnNote() {
    return DateTime.now().isAfter(_ignoreTapUntil);
  }

  void _onNoteTap(_EditableSongNote note) {
    if (!_shouldHandleTapOnNote()) return;
    _showNoteEditor(
      note: note,
      isNew: note.isNew,
    );
  }

  void _resizeNoteEnd(_EditableSongNote note, double deltaDx) {
    final deltaMs = (deltaDx / _timelineScale).round();
    note.durationMs = math.max(1, note.durationMs + deltaMs);
    _syncNoteTiming(note);
    setState(() {});
  }

  void _resizeNoteStart(_EditableSongNote note, double deltaDx) {
    final deltaMs = (deltaDx / _timelineScale).round();
    final newStart = math.max(0, note.startTimeMs + deltaMs);
    final consumed = newStart - note.startTimeMs;
    final newDuration = math.max(1, note.durationMs - consumed);
    final adjustedStart = note.startTimeMs + (note.durationMs - newDuration);

    note.startTimeMs = math.max(0, adjustedStart);
    note.durationMs = newDuration;
    _syncNoteTiming(note);
    _sortNotes();
    setState(() {});
  }

  void _syncTimelineToPlayback(int timeMs) {
    if (!_timelineScrollController.hasClients ||
        _timelineViewportWidth <= 0 ||
        _isDraggingNote) {
      return;
    }

    final timelineMs = timeMs + _gameLeadInMs;
    final rawTarget =
        (timelineMs * _timelineScale) - (_timelineViewportWidth / 2);
    final maxExtent = _timelineScrollController.position.maxScrollExtent;
    final target = rawTarget.clamp(0.0, maxExtent);

    _timelineScrollController.jumpTo(target.toDouble());
  }

  Future<void> _showNoteEditor({
    required _EditableSongNote note,
    required bool isNew,
  }) async {
    if (_chromaticOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No hay notas cromáticas disponibles para este instrumento.'),
        ),
      );
      return;
    }

    late ChromaticNote selectedChromatic;
    selectedChromatic =
        _findChromaticById(note.chromaticId) ?? _chromaticOptions.first;
    final startController =
        TextEditingController(text: note.startTimeMs.toString());
    final durationController =
        TextEditingController(text: note.durationMs.toString());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editar nota',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedChromatic.id,
                      decoration: const InputDecoration(
                        labelText: 'Nota',
                        border: OutlineInputBorder(),
                      ),
                      items: _chromaticOptions
                          .map(
                            (chromatic) => DropdownMenuItem<int>(
                              value: chromatic.id,
                              child: Text(
                                '${chromatic.englishName} (${chromatic.spanishName})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final match = _findChromaticById(value);
                        if (match != null) {
                          setModalState(() {
                            selectedChromatic = match;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Start time (ms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (ms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              final startTime =
                                  int.tryParse(startController.text.trim()) ??
                                      note.startTimeMs;
                              final duration = int.tryParse(
                                      durationController.text.trim()) ??
                                  note.durationMs;
                              setState(() {
                                note.chromaticId = selectedChromatic.id;
                                note.chromaticNote = selectedChromatic;
                                note.startTimeMs = math.max(0, startTime);
                                note.durationMs = math.max(1, duration);
                                _syncNoteTiming(note);
                                _sortNotes();
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Guardar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteNote(note);
                            },
                            child: const Text('Eliminar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNote() async {
    if (_chromaticOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay notas disponibles para agregar.')),
      );
      return;
    }

    final baseChromatic = _chromaticOptions.first;
    final lastEnd = _notes.isEmpty
        ? 0
        : _notes
            .map((note) => note.startTimeMs + note.durationMs)
            .reduce(math.max);
    final newNote = _EditableSongNote(
      id: 'new_${DateTime.now().microsecondsSinceEpoch}',
      songId: widget.songId,
      startTimeMs: _currentPosition.inMilliseconds > 0
          ? _currentPosition.inMilliseconds
          : lastEnd + 500,
      durationMs: 900,
      beatPosition: 0,
      measureNumber: 1,
      noteType: 'quarter',
      velocity: 100,
      chromaticId: baseChromatic.id,
      chromaticNote: baseChromatic,
      isNew: true,
    );
    _syncNoteTiming(newNote);

    setState(() {
      _notes.add(newNote);
      _sortNotes();
    });

    await _showNoteEditor(note: newNote, isNew: true);
  }

  Future<void> _deleteNote(_EditableSongNote note) async {
    setState(() {
      _notes.removeWhere((item) => item.id == note.id);
      if (!note.isNew) {
        _deletedNoteIds.add(note.id);
      }
      _reindexMeasureNumbers();
    });
  }

  Widget _buildSongImage() {
    final imageUrl = _songImageUrl.trim();
    final hasNetworkImage =
        imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.isAbsolute == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 230,
        color: Colors.black12,
        child: hasNetworkImage
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/refmmp.png',
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                'assets/images/refmmp.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
      ),
    );
  }

  Widget _buildSongFields() {
    final currentDifficulty = _difficultyController.text.trim();
    final difficultyOptions = <String>{'Fácil', 'Medio', 'Difícil'};
    if (currentDifficulty.isNotEmpty) {
      difficultyOptions.add(currentDifficulty);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '| Editar canción',
          style: TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration:
              _inputDecoration('Nombre de la canción', Icons.music_note),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa el nombre'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _artistController,
          decoration: _inputDecoration('Artista', Icons.person),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa el artista'
              : null,
        ),
        const SizedBox(height: 12),
        if (_songFieldKeys.contains('difficulty'))
          DropdownButtonFormField<String>(
            value: currentDifficulty.isEmpty ? null : currentDifficulty,
            decoration: _inputDecoration('Dificultad', Icons.speed),
            items: difficultyOptions
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _difficultyController.text = value;
              });
            },
          )
        else
          TextFormField(
            controller: _difficultyController,
            decoration: _inputDecoration('Dificultad', Icons.speed_outlined),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mp3Controller,
          decoration:
              _inputDecoration('URL o ruta de la canción', Icons.audiotrack),
          onChanged: (_) => _updateAudioAvailability(),
        ),
        const SizedBox(height: 12),
        if (_songFieldKeys.contains('bpm'))
          TextFormField(
            controller: _bpmController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('BPM', Icons.timer),
            onChanged: (_) {
              setState(() {
                _syncAllNotes();
              });
            },
          ),
        const SizedBox(height: 12),
        if (_songFieldKeys.contains('time_signature'))
          TextFormField(
            controller: _timeSignatureController,
            decoration: _inputDecoration('Compás', Icons.music_video),
            onChanged: (value) {
              setState(() {
                _beatsPerMeasure = _parseTimeSignature(value);
                _syncAllNotes();
              });
            },
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: Colors.blue),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildPlaybackCard() {
    final positionSeconds = _currentPosition.inMilliseconds / 1000;
    final totalSeconds = _effectiveDurationMs / 1000;
    final sliderMax = math.max(1.0, totalSeconds);
    final sliderValue = math.min(positionSeconds, sliderMax);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '| Reproducción',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _hasAudioSource ? _togglePlayback : null,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(_isPlaying ? 'Pausar' : 'Reproducir canción'),
          ),
          const SizedBox(height: 8),
          Slider(
            min: 0,
            max: sliderMax,
            value: sliderValue,
            onChanged: _hasAudioSource
                ? (value) {
                    _seekPlayback(
                        Duration(milliseconds: (value * 1000).round()));
                  }
                : null,
          ),
          Text(
            '${_formatDuration(_currentPosition)} / ${_formatDuration(Duration(milliseconds: (totalSeconds * 1000).round()))}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '| Bandera de reproducción',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
              'Bandera: ${_formatDuration(Duration(milliseconds: _flagMs))} (${_flagMs} ms)'),
          const SizedBox(height: 8),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _hasAudioSource ? _setFlagAtCurrentTime : null,
                  icon: const Icon(Icons.flag, color: Colors.blue),
                  label: const Text(
                    'Fijar bandera',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _hasAudioSource ? _playFromFlag : null,
                  icon: const Icon(Icons.play_arrow, color: Colors.amber),
                  label: const Text('Reproducir desde bandera',
                      style: TextStyle(color: Colors.amber)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTimeline() {
    final noteCount = math.max(_notes.length, 1);
    final estimatedHeight = math.max(320.0,
        (noteCount > 2 ? 2 : noteCount) * _laneHeight + _timelinePadding * 2);
    final timelineWidth = math.max(
      MediaQuery.of(context).size.width - 32,
      (_songDurationMs * _timelineScale) + 120,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '| Notas de la canción',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _hasAudioSource ? _playFromHitLine : null,
                icon: const Icon(Icons.play_arrow, color: Colors.blue),
                label: const Text('Desde línea roja',
                    style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_notes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Text(
                'La canción no tiene notas. Usa Agregar para crear la primera nota.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                _timelineViewportWidth = constraints.maxWidth;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: estimatedHeight,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _timelineScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: timelineWidth,
                          height: estimatedHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TimelineGridPainter(
                                    beatsPerMeasure: _beatsPerMeasure,
                                    bpm: _parseInt(_bpmController.text) ?? _bpm,
                                    maxDurationMs: _songDurationMs,
                                    scale: _timelineScale,
                                  ),
                                ),
                              ),
                              ..._notes.asMap().entries.map((entry) {
                                final index = entry.key;
                                final note = entry.value;
                                final lane = index % 2;
                                final top =
                                    _timelinePadding + (lane * _laneHeight);
                                final left =
                                    (note.startTimeMs + _gameLeadInMs) *
                                        _timelineScale;
                                final visualWidth =
                                    _noteVisualWidth(note.durationMs);
                                final touchWidth = math.max(28.0, visualWidth);
                                final chromatic = note.chromaticNote ??
                                    _findChromaticById(note.chromaticId);
                                final color =
                                    chromatic?.noteColor ?? Colors.blue;
                                final showTiming = note.durationMs >= 1500;
                                final isThinNote = note.durationMs < 1500;
                                final isActiveDrag =
                                    _activeDraggedNoteId == note.id;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  child: Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (event) =>
                                        _onNotePointerDown(
                                      note,
                                      event,
                                      visualWidth,
                                      isThinNote,
                                    ),
                                    onPointerMove: (event) =>
                                        _onNotePointerMove(note, event),
                                    onPointerUp: (_) => _onNotePointerUp(note),
                                    onPointerCancel: (_) =>
                                        _onNotePointerCancel(note),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      child: SizedBox(
                                        width: touchWidth,
                                        height: 68,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: AnimatedScale(
                                            scale: isActiveDrag ? 1.1 : 1.0,
                                            duration: const Duration(
                                                milliseconds: 140),
                                            curve: Curves.easeOutCubic,
                                            child: Container(
                                              width: visualWidth,
                                              height: 68,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.92),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(
                                                      isActiveDrag
                                                          ? 0.28
                                                          : 0.18,
                                                    ),
                                                    blurRadius:
                                                        isActiveDrag ? 10 : 6,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: isThinNote
                                                  ? null
                                                  : Row(
                                                      children: [
                                                        GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onHorizontalDragStart:
                                                              (_) {
                                                            setState(() {
                                                              _isDraggingNote =
                                                                  true;
                                                            });
                                                          },
                                                          onHorizontalDragUpdate:
                                                              (details) =>
                                                                  _resizeNoteStart(
                                                            note,
                                                            details.delta.dx,
                                                          ),
                                                          onHorizontalDragEnd:
                                                              (_) {
                                                            setState(() {
                                                              _isDraggingNote =
                                                                  false;
                                                            });
                                                          },
                                                          child: const SizedBox(
                                                            width: 18,
                                                            child: Icon(
                                                              Icons.drag_handle,
                                                              color:
                                                                  Colors.white,
                                                              size: 16,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Center(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  chromatic
                                                                          ?.englishName ??
                                                                      'Nota',
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                if (showTiming) ...[
                                                                  const SizedBox(
                                                                      height:
                                                                          2),
                                                                  Text(
                                                                    'start_time: ${note.startTimeMs} ms',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                  Text(
                                                                    'duracion: ${note.durationMs} ms',
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onHorizontalDragStart:
                                                              (_) {
                                                            setState(() {
                                                              _isDraggingNote =
                                                                  true;
                                                            });
                                                          },
                                                          onHorizontalDragUpdate:
                                                              (details) =>
                                                                  _resizeNoteEnd(
                                                            note,
                                                            details.delta.dx,
                                                          ),
                                                          onHorizontalDragEnd:
                                                              (_) {
                                                            setState(() {
                                                              _isDraggingNote =
                                                                  false;
                                                            });
                                                          },
                                                          child: const SizedBox(
                                                            width: 18,
                                                            child: Icon(
                                                              Icons.drag_handle,
                                                              color:
                                                                  Colors.white,
                                                              size: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              Positioned(
                                left:
                                    (_flagMs + _gameLeadInMs) * _timelineScale,
                                top: 0,
                                bottom: 0,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Bandera',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: (constraints.maxWidth / 2) - 1,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
          const Text(
            'Línea roja = hit. Mantén presionada la nota para moverla y suéltala para fijar posición. Arrastra los extremos para cortar adelante o atrás. Puedes reproducir desde la línea roja.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  double _noteVisualWidth(int durationMs) {
    final safeDurationMs = math.max(1, durationMs);
    return safeDurationMs * _timelineScale;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildAppBarActions(bool compactActions) {
    if (!_isNotesStep) {
      return <Widget>[
        IconButton(
          tooltip: 'Cancelar cambios',
          onPressed: _cancelAndExit,
          icon: const Icon(Icons.cancel, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Guardar',
          onPressed: _isSaving ? null : _showSaveOptionsDialog,
          icon: const Icon(Icons.save, color: Colors.white),
        ),
        const SizedBox(width: 6),
      ];
    }

    final actions = <Widget>[
      IconButton(
        tooltip: 'Cancelar cambios',
        onPressed: _cancelAndExit,
        icon: const Icon(Icons.cancel, color: Colors.white),
      ),
      IconButton(
        tooltip: 'Guardar',
        onPressed: _isSaving ? null : _showSaveOptionsDialog,
        icon: const Icon(Icons.save, color: Colors.white),
      ),
      IconButton(
        tooltip: 'Reproducir',
        onPressed: _hasAudioSource ? _togglePlayback : null,
        icon: Icon(
          _isPlaying ? Icons.pause_circle : Icons.play_circle,
          color: Colors.white,
        ),
      ),
      IconButton(
        tooltip: 'Agregar nota',
        onPressed: _isNotesStep ? _addNote : null,
        icon: const Icon(Icons.add_circle, color: Colors.white),
      ),
    ];

    if (_isNotesStep && !compactActions) {
      actions.add(
        IconButton(
          tooltip: 'Reproducir desde línea roja',
          onPressed: _hasAudioSource ? _playFromHitLine : null,
          icon: const Icon(Icons.playlist_play, color: Colors.white),
        ),
      );
    }

    if (!compactActions) {
      actions.add(
        IconButton(
          tooltip: 'Reproducir desde inicio',
          onPressed: _hasAudioSource ? _playFromStart : null,
          icon: const Icon(Icons.restart_alt, color: Colors.white),
        ),
      );
      if (_isNotesStep) {
        actions.add(
          IconButton(
            tooltip: 'Bandera actual',
            onPressed: _hasAudioSource ? _setFlagAtCurrentTime : null,
            icon: const Icon(Icons.flag, color: Colors.white),
          ),
        );
      }
    } else {
      actions.add(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'start' && _hasAudioSource) {
              _playFromStart();
            } else if (value == 'hit' && _hasAudioSource) {
              _playFromHitLine();
            } else if (value == 'flag' && _hasAudioSource) {
              _setFlagAtCurrentTime();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'start',
              child: Text('Reproducir desde inicio'),
            ),
            if (_isNotesStep)
              const PopupMenuItem<String>(
                value: 'hit',
                child: Text('Reproducir desde línea roja'),
              ),
            if (_isNotesStep)
              const PopupMenuItem<String>(
                value: 'flag',
                child: Text('Fijar bandera actual'),
              ),
          ],
        ),
      );
    }

    actions.add(const SizedBox(width: 6));
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compactActions = screenWidth < 780;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () async {
            if (_isNotesStep) {
              await _goToSongStep();
              return;
            }
            Navigator.pop(context);
          },
        ),
        title: Text(
          _isNotesStep ? 'Editar notas y pista' : 'Editar canción',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: _buildAppBarActions(compactActions),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _songData == null
              ? const Center(child: Text('No se pudo cargar la canción.'))
              : (!_isNotesStep
                  ? Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 110, 12, 24),
                        children: [
                          _buildSongImage(),
                          const SizedBox(height: 14),
                          _buildSongFields(),
                          const SizedBox(height: 14),
                          _buildPlaybackCard(),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 100, 0, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 8),
                                _buildFlagCard(),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: SingleChildScrollView(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: _buildNotesTimeline(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )),
      floatingActionButton: _isLoading || _songData == null
          ? null
          : (!_isNotesStep
              ? FloatingActionButton.extended(
                  onPressed: _isSaving ? null : _goToNotesStep,
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Siguiente'),
                )
              : null),
    );
  }
}

class _EditableSongNote {
  String id;
  final String songId;
  int startTimeMs;
  int durationMs;
  double beatPosition;
  int measureNumber;
  String noteType;
  int velocity;
  int? chromaticId;
  ChromaticNote? chromaticNote;
  bool isNew;

  _EditableSongNote({
    required this.id,
    required this.songId,
    required this.startTimeMs,
    required this.durationMs,
    required this.beatPosition,
    required this.measureNumber,
    required this.noteType,
    required this.velocity,
    required this.chromaticId,
    required this.chromaticNote,
    required this.isNew,
  });

  factory _EditableSongNote.fromSongNote(SongNote note) {
    return _EditableSongNote(
      id: note.id,
      songId: note.songId,
      startTimeMs: note.startTimeMs,
      durationMs: note.durationMs,
      beatPosition: note.beatPosition,
      measureNumber: note.measureNumber,
      noteType: note.noteType,
      velocity: note.velocity,
      chromaticId: note.chromaticId,
      chromaticNote: note.chromaticNote,
      isNew: false,
    );
  }

  Map<String, dynamic> toInsertMap(String songId) {
    return {
      'song_id': songId,
      'start_time_ms': startTimeMs,
      'duration_ms': durationMs,
      'beat_position': beatPosition,
      'measure_number': measureNumber,
      'note_type': noteType,
      'velocity': velocity,
      'chromatic_id': chromaticId,
    };
  }

  Map<String, dynamic> toUpdateMap(String songId) {
    return {
      'song_id': songId,
      'start_time_ms': startTimeMs,
      'duration_ms': durationMs,
      'beat_position': beatPosition,
      'measure_number': measureNumber,
      'note_type': noteType,
      'velocity': velocity,
      'chromatic_id': chromaticId,
    };
  }
}

class _TimelineGridPainter extends CustomPainter {
  final int beatsPerMeasure;
  final int bpm;
  final int maxDurationMs;
  final double scale;

  _TimelineGridPainter({
    required this.beatsPerMeasure,
    required this.bpm,
    required this.maxDurationMs,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.blue.withOpacity(0.12)
      ..strokeWidth = 1;

    final strongPaint = Paint()
      ..color = Colors.blue.withOpacity(0.25)
      ..strokeWidth = 2;

    final msPerBeat = 60000 / math.max(1, bpm);
    final msPerMeasure = msPerBeat * math.max(1, beatsPerMeasure);
    final totalWidth = math.max(size.width, (maxDurationMs * scale) + 200);

    for (double x = 0; x <= totalWidth; x += msPerBeat * scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double x = 0; x <= totalWidth; x += msPerMeasure * scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), strongPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
    return oldDelegate.beatsPerMeasure != beatsPerMeasure ||
        oldDelegate.bpm != bpm ||
        oldDelegate.maxDurationMs != maxDurationMs ||
        oldDelegate.scale != scale;
  }
}
