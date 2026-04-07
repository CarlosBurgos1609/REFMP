import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:diacritic/diacritic.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:refmp/edit/edit_music.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SongsFormPage extends StatefulWidget {
  final String instrumentName;

  const SongsFormPage({super.key, required this.instrumentName});

  @override
  State<SongsFormPage> createState() => _SongsFormPageState();
}

class _SongsFormPageState extends State<SongsFormPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _difficultyController = TextEditingController();
  final TextEditingController _imageLinkController = TextEditingController();
  final TextEditingController _bpmController = TextEditingController();
  final TextEditingController _timeSignatureController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProcessingTrim = false;
  bool _isPlaying = false;
  bool _isInTrimMode = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _audioTrimStart = Duration.zero;
  Duration _audioTrimEnd = Duration.zero;
  int? _instrumentId;
  String _instrumentImageUrl = '';
  final List<Map<String, dynamic>> _availableSongLevels =
      <Map<String, dynamic>>[];
  final Set<String> _selectedSongLevelKeys = <String>{};
  File? _selectedImageFile;
  String? _selectedAudioPath;
  String? _selectedAudioName;

  final List<String> _difficultyOptions = <String>['Fácil', 'Medio', 'Difícil'];
  final List<String> _allowedAudioExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
  ];

  bool _isFfmpegTrimSupportedPlatform() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  bool _isMissingFfmpegPluginError(Object error) {
    if (error is MissingPluginException) return true;
    if (error is PlatformException &&
        (error.code.toLowerCase().contains('missing') ||
            error.message
                    ?.toLowerCase()
                    .contains('no implementation found for method') ==
                true)) {
      return true;
    }
    return error
        .toString()
        .toLowerCase()
        .contains('no implementation found for method ffmpegsession');
  }

  @override
  void initState() {
    super.initState();
    _difficultyController.text = 'Fácil';
    _bpmController.text = '120';
    _timeSignatureController.text = '4/4';
    _loadInstrumentData();
    _loadAvailableSongLevels();

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentPosition = _effectiveTrimStart();
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;

      final trimStart = _effectiveTrimStart();
      final trimEnd = _effectiveTrimEnd();

      if (trimEnd.inMilliseconds > trimStart.inMilliseconds &&
          position.inMilliseconds >= trimEnd.inMilliseconds - 100) {
        _audioPlayer.pause();
        _audioPlayer.seek(trimStart);
        setState(() {
          _isPlaying = false;
          _currentPosition = trimStart;
        });
        return;
      }

      setState(() {
        _currentPosition = position;
      });
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
    _audioPlayer.dispose();
    _nameController.dispose();
    _artistController.dispose();
    _difficultyController.dispose();
    _imageLinkController.dispose();
    _bpmController.dispose();
    _timeSignatureController.dispose();
    super.dispose();
  }

  String _normalizeInstrumentName(String value) {
    return removeDiacritics(value)
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _loadInstrumentData() async {
    try {
      final requestedName = _normalizeInstrumentName(widget.instrumentName);
      final instrumentsResponse =
          await _supabase.from('instruments').select('id, name, image');

      if (!mounted) return;

      Map<String, dynamic>? matched;
      // ignore: unnecessary_type_check
      if (instrumentsResponse is List) {
        for (final item in instrumentsResponse) {
          // ignore: unnecessary_type_check
          if (item is! Map<String, dynamic>) continue;
          final dbName =
              _normalizeInstrumentName(item['name']?.toString() ?? '');
          if (dbName == requestedName) {
            matched = item;
            break;
          }
        }

        matched ??= instrumentsResponse.cast<Map<String, dynamic>>().firstWhere(
          (item) {
            final dbName =
                _normalizeInstrumentName(item['name']?.toString() ?? '');
            return dbName.contains(requestedName) ||
                requestedName.contains(dbName);
          },
          orElse: () => <String, dynamic>{},
        );

        // ignore: unnecessary_null_comparison
        if (matched != null && matched.isEmpty) {
          matched = null;
        }
      }

      if (matched != null) {
        setState(() {
          _instrumentId = matched!['id'] as int?;
          _instrumentImageUrl = matched['image']?.toString() ?? '';
          _isLoading = false;
        });
      } else {
        debugPrint('No instrument found for: ${widget.instrumentName}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading instrument data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedAudioExtensions,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      final path = pickedFile.path;
      if (path == null || path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer la ruta del archivo seleccionado.'),
          ),
        );
        return;
      }

      final extension = path.split('.').last.toLowerCase();
      if (!_allowedAudioExtensions.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona solo archivos de audio.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedAudioPath = path;
        _selectedAudioName = pickedFile.name;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _audioTrimStart = Duration.zero;
        _audioTrimEnd = Duration.zero;
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Error picking audio file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo seleccionar el audio: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableSongLevels() async {
    try {
      final response = await _fetchLevelsForSongsForm();
      final levels = response
          .whereType<Map<String, dynamic>>()
          .where((item) => _levelKey(item['id']).isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _availableSongLevels
          ..clear()
          ..addAll(levels);

        if (_selectedSongLevelKeys.isEmpty) {
          _selectedSongLevelKeys
            ..clear()
            ..addAll(levels.map((item) => _levelKey(item['id'])));
        }
      });
    } catch (e) {
      debugPrint('Error loading available song levels: $e');
    }
  }

  Future<List<dynamic>> _fetchLevelsForSongsForm() async {
    try {
      final response = await _supabase
          .from('level')
          .select('id, name, image, description')
          .order('name', ascending: true);
      return (response as List<dynamic>);
    } catch (_) {
      final response = await _supabase
          .from('levels')
          .select('id, name, image, description')
          .order('name', ascending: true);
      return (response as List<dynamic>);
    }
  }

  String _levelKey(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  dynamic _levelIdFromKey(String key) {
    for (final level in _availableSongLevels) {
      if (_levelKey(level['id']) == key) {
        return level['id'];
      }
    }
    return key;
  }

  Future<void> _saveSongLevelsForSong(dynamic songId) async {
    if (_selectedSongLevelKeys.isEmpty) return;

    final inserts = _selectedSongLevelKeys
        .map(
          (key) => <String, dynamic>{
            'song_id': songId,
            'level_id': _levelIdFromKey(key),
          },
        )
        .toList();

    if (inserts.isEmpty) return;
    await _supabase.from('song_levels').insert(inserts);
  }

  Future<void> _pickImageFile() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
        _imageLinkController.clear();
      });
    } catch (e) {
      debugPrint('Error picking image file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.image_rounded, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Agregar imagen',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Puedes subir una imagen desde tu celular o pegar un link (por ejemplo, de Spotify).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _pickImageFile();
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Subir imagen'),
            ),
          ],
        );
      },
    );
  }

  void _clearAudio() {
    if (_isPlaying) {
      _audioPlayer.stop();
    }
    setState(() {
      _selectedAudioPath = null;
      _selectedAudioName = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _audioTrimStart = Duration.zero;
      _audioTrimEnd = Duration.zero;
      _isPlaying = false;
    });
  }

  void _toggleTrimMode() {
    setState(() {
      _isInTrimMode = !_isInTrimMode;
      if (_isInTrimMode) {
        if (_audioTrimEnd.inMilliseconds == 0) {
          _audioTrimEnd = _totalDuration;
        }
      }
    });
  }

  Duration _effectiveTrimStart() {
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs <= 0) return Duration.zero;
    final startMs = _audioTrimStart.inMilliseconds.clamp(0, totalMs);
    return Duration(milliseconds: startMs);
  }

  Duration _effectiveTrimEnd() {
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs <= 0) return Duration.zero;
    final startMs = _effectiveTrimStart().inMilliseconds;
    final rawEndMs = _audioTrimEnd.inMilliseconds > 0
        ? _audioTrimEnd.inMilliseconds
        : totalMs;
    final endMs = rawEndMs.clamp(startMs, totalMs);
    return Duration(milliseconds: endMs);
  }

  bool _hasAppliedTrim() {
    if (_totalDuration.inMilliseconds <= 0) return false;
    final start = _effectiveTrimStart();
    final end = _effectiveTrimEnd();
    return start.inMilliseconds > 0 ||
        end.inMilliseconds < _totalDuration.inMilliseconds;
  }

  Future<void> _showTrimValueDialog({required bool isStart}) async {
    if (_totalDuration.inMilliseconds <= 0) return;

    final totalMs = _totalDuration.inMilliseconds;
    final start = _effectiveTrimStart();
    final end = _effectiveTrimEnd();
    var tempMs = isStart ? start.inMilliseconds : end.inMilliseconds;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final minMs = isStart ? 0 : _effectiveTrimStart().inMilliseconds;
            final maxMs =
                isStart ? _effectiveTrimEnd().inMilliseconds : totalMs;
            final clamped = tempMs.clamp(minMs, maxMs);
            tempMs = clamped;

            return AlertDialog(
              title: Text(isStart ? 'Ajustar inicio' : 'Ajustar final'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: tempMs)),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    min: minMs / 1000,
                    max: math.max(minMs / 1000 + 0.1, maxMs / 1000),
                    value: tempMs / 1000,
                    onChanged: (value) {
                      setDialogState(() {
                        tempMs = (value * 1000).round();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (isStart) {
                        _audioTrimStart = Duration(milliseconds: tempMs);
                        if (_audioTrimStart > _effectiveTrimEnd()) {
                          _audioTrimEnd = _audioTrimStart;
                        }
                      } else {
                        _audioTrimEnd = Duration(milliseconds: tempMs);
                        if (_effectiveTrimEnd() < _effectiveTrimStart()) {
                          _audioTrimStart = _effectiveTrimEnd();
                        }
                      }
                    });

                    if (_isPlaying) {
                      final newStart = _effectiveTrimStart();
                      final newEnd = _effectiveTrimEnd();
                      if (_currentPosition < newStart ||
                          _currentPosition > newEnd) {
                        _seekPlayback(newStart);
                      }
                    }

                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildAudioTrimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recortar pista',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.red),
              onPressed: _toggleTrimMode,
              tooltip: 'Cerrar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.withOpacity(0.1),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: AudioWaveformTrimmer(
                  totalDuration: _totalDuration,
                  trimStart: _audioTrimStart,
                  trimEnd: _audioTrimEnd,
                  currentPosition:
                      _isPlaying ? _currentPosition : _audioTrimStart,
                  onTrimStartChanged: (newStart) {
                    setState(() {
                      _audioTrimStart = newStart;
                      if (_audioTrimStart.compareTo(_audioTrimEnd) > 0) {
                        _audioTrimEnd = _audioTrimStart;
                      }
                    });

                    if (_isPlaying) {
                      final start = _effectiveTrimStart();
                      final end = _effectiveTrimEnd();
                      if (_currentPosition < start || _currentPosition > end) {
                        _seekPlayback(start);
                      }
                    }
                  },
                  onTrimEndChanged: (newEnd) {
                    setState(() {
                      _audioTrimEnd = newEnd;
                      if (_audioTrimEnd.compareTo(_audioTrimStart) < 0) {
                        _audioTrimStart = _audioTrimEnd;
                      }
                    });

                    if (_isPlaying) {
                      final start = _effectiveTrimStart();
                      final end = _effectiveTrimEnd();
                      if (_currentPosition > end) {
                        _seekPlayback(start);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _showTrimValueDialog(isStart: true),
                    child: Text(
                      'Inicio: ${_formatDuration(_audioTrimStart)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showTrimValueDialog(isStart: false),
                    child: Text(
                      'Final: ${_formatDuration(_effectiveTrimEnd())}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    'Duración: ${_formatDuration(Duration(milliseconds: (_effectiveTrimEnd().inMilliseconds - _effectiveTrimStart().inMilliseconds).abs()))}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Future<void> _showTrimDialog() async {
    _toggleTrimMode();
  }

  // ignore: unused_element
  String _formatFfmpegTimestamp(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds;
    final hours = totalMilliseconds ~/ 3600000;
    final minutes = (totalMilliseconds % 3600000) ~/ 60000;
    final seconds = (totalMilliseconds % 60000) / 1000.0;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(3).padLeft(6, '0')}';
  }

  // ignore: unused_element
  String _escapeFfmpegPath(String value) {
    return value.replaceAll("'", "'\\''");
  }

  Future<String> _exportTrimmedAudio(String inputPath) async {
    throw MissingPluginException(
      'ffmpeg_kit no disponible en esta compilacion',
    );
  }

  // ignore: unused_element
  Future<void> _saveTrimmedAudio() async {
    final localPath = _selectedAudioPath;
    if (localPath == null || localPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes subir una pista.')),
      );
      return;
    }

    if (!_hasAppliedTrim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ajusta inicio y final antes de guardar el corte.')),
      );
      return;
    }

    setState(() {
      _isProcessingTrim = true;
    });

    try {
      await _audioPlayer.stop();
      final trimmedPath = await _exportTrimmedAudio(localPath);
      final originalName = _selectedAudioName ?? p.basename(localPath);
      final baseName = p.basenameWithoutExtension(originalName);
      final extension = p.extension(trimmedPath);

      setState(() {
        _selectedAudioPath = trimmedPath;
        _selectedAudioName = '${baseName}_cortada$extension';
        _isPlaying = false;
        _isInTrimMode = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _audioTrimStart = Duration.zero;
        _audioTrimEnd = Duration.zero;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Recorte guardado. Se subirá la versión cortada.')),
      );
    } catch (e) {
      if (!mounted) return;

      if (_isMissingFfmpegPluginError(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo recortar porque FFmpeg no esta disponible en esta ejecucion. Cierra y abre la app con flutter clean && flutter pub get (preferiblemente en Android/iOS).',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el recorte: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingTrim = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    final source = _selectedAudioPath?.trim() ?? '';
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero debes subir una pista.')),
      );
      return;
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permiten pistas locales del dispositivo.'),
        ),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
        });
        return;
      }

      final file = File(source);
      if (!await file.exists()) {
        throw Exception('El archivo local no existe: $source');
      }
      await _audioPlayer.play(DeviceFileSource(source));

      final trimStart = _effectiveTrimStart();
      final trimEnd = _effectiveTrimEnd();
      var startPosition = _currentPosition;
      if (startPosition < trimStart || startPosition >= trimEnd) {
        startPosition = trimStart;
      }
      await _audioPlayer.seek(startPosition);

      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Error reproduciendo pista: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reproducir la pista: $e')),
        );
      }
    }
  }

  Future<void> _seekPlayback(Duration position) async {
    try {
      final trimStart = _effectiveTrimStart();
      final trimEnd = _effectiveTrimEnd();
      final clampedMs = position.inMilliseconds.clamp(
        trimStart.inMilliseconds,
        trimEnd.inMilliseconds,
      );
      final clampedPosition = Duration(milliseconds: clampedMs);

      await _audioPlayer.seek(clampedPosition);
      if (!mounted) return;
      setState(() {
        _currentPosition = clampedPosition;
      });
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  int _parseInt(String value, int fallback) {
    return int.tryParse(value.trim()) ?? fallback;
  }

  // ignore: unused_element
  int _defaultCoinsForDifficulty(String difficulty) {
    return 10;
  }

  String _buildSafeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
  }

  Future<String> _uploadAudioFile(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('El archivo de audio no existe en el dispositivo.');
    }

    final songName = _buildSafeFileName(
        _nameController.text.isEmpty ? 'song' : _nameController.text);
    final extension = localPath.contains('.')
        ? localPath.split('.').last.toLowerCase()
        : 'mp3';
    final fileName =
        'song_${DateTime.now().millisecondsSinceEpoch}_$songName.$extension';
    final storagePath = 'song_audio/$fileName';

    await _supabase.storage.from('songs').upload(storagePath, file);
    return _supabase.storage.from('songs').getPublicUrl(storagePath);
  }

  Future<String> _resolveSongImageUrl() async {
    if (_selectedImageFile != null) {
      final extension = _selectedImageFile!.path.contains('.')
          ? _selectedImageFile!.path.split('.').last.toLowerCase()
          : 'jpg';
      final safeName = _buildSafeFileName(
        _nameController.text.isEmpty ? 'song' : _nameController.text,
      );
      final fileName =
          'song_image_${DateTime.now().millisecondsSinceEpoch}_$safeName.$extension';
      final storagePath = 'song_images/$fileName';

      await _supabase.storage
          .from('songs')
          .upload(storagePath, _selectedImageFile!);
      return _supabase.storage.from('songs').getPublicUrl(storagePath);
    }

    final link = _imageLinkController.text.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && uri.isAbsolute) {
        return link;
      }

      throw Exception('El link de imagen no es válido.');
    }

    return _instrumentImageUrl.trim();
  }

  Future<bool> _createSong() async {
    if (!_formKey.currentState!.validate()) return false;

    if (_instrumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró el instrumento: ${widget.instrumentName}.',
          ),
        ),
      );
      return false;
    }

    if (_selectedAudioPath == null || _selectedAudioPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes agregar una pista de audio.')),
      );
      return false;
    }

    if (_selectedSongLevelKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un nivel disponible.'),
        ),
      );
      return false;
    }

    if (_hasAppliedTrim() && !_isFfmpegTrimSupportedPlatform()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El recorte exportado no esta disponible en esta plataforma. Usa Android o iOS para subir la cancion cortada.',
          ),
        ),
      );
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final insertData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'artist': _artistController.text.trim(),
        'difficulty': _difficultyController.text.trim(),
        'instrument': _instrumentId,
        'bpm': _parseInt(_bpmController.text, 120),
        'time_signature': _timeSignatureController.text.trim(),
      };

      final imageUrl = await _resolveSongImageUrl();
      insertData['image'] = imageUrl;

      var audioPathForUpload = _selectedAudioPath!;
      if (_hasAppliedTrim()) {
        try {
          audioPathForUpload = await _exportTrimmedAudio(audioPathForUpload);
        } catch (e) {
          if (_isMissingFfmpegPluginError(e)) {
            throw Exception(
              'FFmpeg no esta disponible para exportar el recorte en esta ejecucion. Reinicia la app y prueba en Android/iOS.',
            );
          }
          rethrow;
        }
      }

      final audioUrl = await _uploadAudioFile(audioPathForUpload);
      insertData['mp3_file'] = audioUrl;

      final createdSong = await _supabase
          .from('songs')
          .insert(insertData)
          .select('id, name, image, mp3_file, artist, difficulty, instrument')
          .single();

      await _saveSongLevelsForSong(createdSong['id']);

      final user = _supabase.auth.currentUser;
      if (user != null) {
        try {
          await _supabase.from('user_songs').insert({
            'user_id': user.id,
            'song_id': createdSong['id'],
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('No se pudo registrar la propiedad de la canción: $e');
        }
      }

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canción creada correctamente.')),
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EditMusicPage(
            songId: createdSong['id'].toString(),
            initialSongName: createdSong['name']?.toString(),
            initialSongData: Map<String, dynamic>.from(createdSong),
          ),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Error creating song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la canción: $e')),
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

  Color _primaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.blue;
  }

  Color _secondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade300 : Colors.blue;
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final primary = _primaryTextColor(context);
    final secondary = _secondaryTextColor(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: secondary, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: primary),
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

  Widget _buildHeader() {
    final link = _imageLinkController.text.trim();
    final hasLinkImage =
        link.isNotEmpty && Uri.tryParse(link)?.isAbsolute == true;
    final hasInstrumentImage = _instrumentImageUrl.trim().isNotEmpty &&
        Uri.tryParse(_instrumentImageUrl)?.isAbsolute == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 250,
        color: Colors.black12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_selectedImageFile != null)
              Image.file(_selectedImageFile!, fit: BoxFit.cover)
            else if (hasLinkImage)
              CachedNetworkImage(
                imageUrl: link,
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
            else if (hasInstrumentImage)
              CachedNetworkImage(
                imageUrl: _instrumentImageUrl,
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
            else
              Image.asset(
                'assets/images/refmmp.png',
                fit: BoxFit.cover,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.12),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar canción',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instrumentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _showImageSourceDialog,
                          icon: const Icon(
                            Icons.upload_file_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Subir imagen',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70),
                            backgroundColor: Colors.black.withOpacity(0.25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    final primaryText = _primaryTextColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '| Nueva canción',
          style: TextStyle(
            color: primaryText,
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
        DropdownButtonFormField<String>(
          value: _difficultyController.text.trim().isEmpty
              ? null
              : _difficultyController.text.trim(),
          decoration: _inputDecoration('Dificultad', Icons.speed),
          items: _difficultyOptions
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
        ),
        const SizedBox(height: 12),
        _buildSongLevelsSelector(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _imageLinkController,
          decoration: _inputDecoration(
            'Link de imagen (Spotify recomendado)',
            Icons.link,
          ),
          onChanged: (_) {
            if (_selectedImageFile != null) {
              setState(() {
                _selectedImageFile = null;
              });
              return;
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bpmController,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('BPM', Icons.timer),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _timeSignatureController,
          decoration: _inputDecoration('Compás', Icons.music_video),
        ),
      ],
    );
  }

  Widget _buildSongLevelsSelector() {
    final primaryText = _primaryTextColor(context);
    final secondaryText = _secondaryTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Niveles disponibles de la canción',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedSongLevelKeys.isEmpty
                ? 'Selecciona al menos 1 nivel (puedes activar 1, 2 o 3).'
                : 'Activos: ${_selectedSongLevelKeys.length}',
            style: TextStyle(color: secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_availableSongLevels.isEmpty)
            const Text(
              'No se encontraron niveles en la base de datos.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSongLevels.map((level) {
                final key = _levelKey(level['id']);
                final isSelected = _selectedSongLevelKeys.contains(key);
                final label =
                    level['name']?.toString().trim().isNotEmpty == true
                        ? level['name'].toString()
                        : 'Nivel';

                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            if (value) {
                              _selectedSongLevelKeys.add(key);
                            } else {
                              _selectedSongLevelKeys.remove(key);
                            }
                          });
                        },
                  selectedColor: Colors.blue.withOpacity(0.2),
                  checkmarkColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.blue.shade800)
                        : (isDark ? Colors.grey.shade300 : Colors.blue),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey.shade400,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaybackCard() {
    final primaryText = _primaryTextColor(context);
    final secondaryText = _secondaryTextColor(context);
    final trimStart = _effectiveTrimStart();
    final trimEnd = _effectiveTrimEnd();
    final positionSeconds = _currentPosition.inMilliseconds / 1000;
    final trimStartSeconds = trimStart.inMilliseconds / 1000;
    final trimEndSeconds = math.max(1, trimEnd.inMilliseconds) / 1000;
    final sliderMax = math.max(trimStartSeconds + 0.1, trimEndSeconds);
    final sliderValue = positionSeconds.clamp(trimStartSeconds, sliderMax);
    final hasAudio = _selectedAudioPath != null;
    final isBusy = _isSaving || _isProcessingTrim;
    // ignore: unused_local_variable
    final hasTrimApplied = _hasAppliedTrim();

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
          Text(
            '| Reproducción',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : _pickAudioFile,
              icon: const Icon(Icons.upload_file_rounded, color: Colors.blue),
              label: const Text(
                'Subir pista',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),
          if (_selectedAudioName != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Archivo: $_selectedAudioName',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recorte deshabilitado temporalmente.
                    // Se conserva la logica en el archivo para reactivarla despues.
                    IconButton(
                      icon: const Icon(Icons.delete_rounded,
                          color: Colors.red, size: 18),
                      onPressed: isBusy ? null : _clearAudio,
                      tooltip: 'Eliminar pista',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
              ],
            ),
            // Recorte deshabilitado temporalmente.
            // if (hasTrimApplied) ...[...]
            // if (_isInTrimMode) ...[...]
          ],
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
            onPressed: hasAudio && !isBusy ? _togglePlayback : null,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(_isPlaying ? 'Pausar' : 'Reproducir pista'),
          ),
          const SizedBox(height: 8),
          Slider(
            min: trimStartSeconds,
            max: sliderMax,
            value: sliderValue,
            activeColor: Colors.blue,
            inactiveColor: Colors.blue.withOpacity(0.25),
            onChanged: hasAudio && !isBusy
                ? (value) {
                    _seekPlayback(
                        Duration(milliseconds: (value * 1000).round()));
                  }
                : null,
          ),
          Text(
            '${_formatDuration(_currentPosition)} / ${_formatDuration(trimEnd)}',
            style: TextStyle(fontSize: 13, color: secondaryText),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBottomAction() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isSaving || _isProcessingTrim) ? null : _createSong,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        label: const Text(
          'Siguiente (Editar notas)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final appBarForegroundColor = isDarkTheme ? Colors.white : Colors.blue;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_rounded, color: appBarForegroundColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agregar canción',
          style: TextStyle(
            color: appBarForegroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 110, 12, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildFormFields(),
                  const SizedBox(height: 14),
                  _buildPlaybackCard(),
                  const SizedBox(height: 14),
                  _buildBottomAction(),
                ],
              ),
            ),
    );
  }
}

class AudioWaveformTrimmer extends StatefulWidget {
  final Duration totalDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final Duration currentPosition;
  final Function(Duration) onTrimStartChanged;
  final Function(Duration) onTrimEndChanged;

  const AudioWaveformTrimmer({
    super.key,
    required this.totalDuration,
    required this.trimStart,
    required this.trimEnd,
    required this.currentPosition,
    required this.onTrimStartChanged,
    required this.onTrimEndChanged,
  });

  @override
  State<AudioWaveformTrimmer> createState() => _AudioWaveformTrimmerState();
}

class _AudioWaveformTrimmerState extends State<AudioWaveformTrimmer> {
  String _draggingHandle = ''; // 'start', 'end', or ''

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      return const Center(child: Text('Sin duración válida'));
    }

    final startPercent =
        (widget.trimStart.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final endPercent =
        (widget.trimEnd.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final currentPercent =
        (widget.currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragStart: (details) {
        final renderBoxSize = context.findRenderObject() as RenderBox?;
        if (renderBoxSize == null) return;

        final width = renderBoxSize.size.width;
        if (width <= 0) return;
        final tapPercent = details.localPosition.dx / width;

        final handleSize = 0.08;
        final distToStart = (tapPercent - startPercent).abs();
        final distToEnd = (tapPercent - endPercent).abs();

        if (distToStart < handleSize) {
          _draggingHandle = 'start';
        } else if (distToEnd < handleSize) {
          _draggingHandle = 'end';
        } else {
          final midPoint = (startPercent + endPercent) / 2;
          _draggingHandle = tapPercent <= midPoint ? 'start' : 'end';
        }
      },
      onHorizontalDragUpdate: (details) {
        final renderBoxSize = context.findRenderObject() as RenderBox?;
        if (renderBoxSize == null) return;

        final width = renderBoxSize.size.width;
        if (width <= 0) return;
        final newPercent = (details.localPosition.dx / width).clamp(0.0, 1.0);
        final newDuration = Duration(
          milliseconds: (newPercent * totalMs).round(),
        );

        if (_draggingHandle == 'start') {
          widget.onTrimStartChanged(newDuration);
        } else if (_draggingHandle == 'end') {
          widget.onTrimEndChanged(newDuration);
        }
      },
      onHorizontalDragEnd: (_) {
        _draggingHandle = '';
      },
      child: CustomPaint(
        painter: WaveformPainter(
          startPercent: startPercent,
          endPercent: endPercent,
          currentPercent: currentPercent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double startPercent;
  final double endPercent;
  final double currentPercent;

  WaveformPainter({
    required this.startPercent,
    required this.endPercent,
    required this.currentPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Dibujar barras simuladas del waveform
    const barCount = 40;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = (i + 0.5) * barWidth;
      final percent = x / size.width;
      final isInTrimmedArea = percent >= startPercent && percent <= endPercent;

      // Altura simulada del waveform (patrón visual)
      final heightMultiplier = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(i * 0.5));
      final barHeight = size.height * heightMultiplier;

      final currentPaint = isInTrimmedArea ? activePaint : paint;

      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        currentPaint,
      );
    }

    // Dibujar overlay de área recortada
    final trimStartX = startPercent * size.width;
    final trimEndX = endPercent * size.width;

    final trimPaint = Paint()
      ..color = Colors.blue.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(trimStartX, 0, trimEndX - trimStartX, size.height),
      trimPaint,
    );

    // Dibujar handles (líneas gruesas en los extremos)
    final handlePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3;

    // Handle de inicio
    canvas.drawLine(
      Offset(trimStartX - 1, 0),
      Offset(trimStartX - 1, size.height),
      handlePaint,
    );

    // Handle final
    canvas.drawLine(
      Offset(trimEndX + 1, 0),
      Offset(trimEndX + 1, size.height),
      handlePaint,
    );

    // Dibujar indicador de posición actual (línea roja)
    if (currentPercent >= startPercent && currentPercent <= endPercent) {
      final currentX = currentPercent * size.width;
      final currentPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2;

      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX, size.height),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.startPercent != startPercent ||
        oldDelegate.endPercent != endPercent ||
        oldDelegate.currentPercent != currentPercent;
  }
}
