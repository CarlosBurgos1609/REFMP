import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelsFormPage extends StatefulWidget {
  final String instrumentName;

  const LevelsFormPage({super.key, required this.instrumentName});

  @override
  State<LevelsFormPage> createState() => _LevelsFormPageState();
}

class _LevelsFormPageState extends State<LevelsFormPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  int? _instrumentId;
  String _instrumentImageUrl = '';
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _loadInstrumentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _numberController.dispose();
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
      if (instrumentsResponse is List) {
        for (final item in instrumentsResponse) {
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

        if (matched != null && matched.isEmpty) {
          matched = null;
        }
      }

      if (matched != null) {
        _instrumentId = matched['id'] as int?;
        _instrumentImageUrl = matched['image']?.toString() ?? '';
        await _suggestNextLevelNumber();
      }
    } catch (e) {
      debugPrint('Error loading instrument data for levels form: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _suggestNextLevelNumber() async {
    if (_instrumentId == null) return;

    try {
      final lastLevel = await _supabase
          .from('levels')
          .select('number')
          .eq('instrument_id', _instrumentId!)
          .order('number', ascending: false)
          .limit(1)
          .maybeSingle();

      final next = (lastLevel?['number'] as int? ?? 0) + 1;
      _numberController.text = '$next';
    } catch (e) {
      debugPrint('Error getting next level number: $e');
      if (_numberController.text.trim().isEmpty) {
        _numberController.text = '1';
      }
    }
  }

  Future<void> _pickImageFile() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
      });
    } catch (e) {
      debugPrint('Error picking level image file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
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
            'Selecciona una imagen desde tu celular para usarla en el nivel.',
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

  String _buildSafeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
  }

  Future<String> _resolveLevelImageUrl() async {
    if (_selectedImageFile == null) {
      throw Exception('Debes subir la imagen del nivel.');
    }

    final extension = _selectedImageFile!.path.contains('.')
        ? _selectedImageFile!.path.split('.').last.toLowerCase()
        : 'png';
    final safeName = _buildSafeFileName(
      _nameController.text.isEmpty ? 'level' : _nameController.text,
    );
    final fileName =
        'level_${DateTime.now().millisecondsSinceEpoch}_$safeName.$extension';

    await _supabase.storage
        .from('levels')
        .upload(fileName, _selectedImageFile!);
    return _supabase.storage.from('levels').getPublicUrl(fileName);
  }

  int _parseLevelNumber() {
    final parsed = int.tryParse(_numberController.text.trim());
    return parsed ?? 0;
  }

  Future<void> _createLevel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_instrumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró el instrumento: ${widget.instrumentName}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final levelNumber = _parseLevelNumber();
      if (levelNumber <= 0) {
        throw Exception('El número de nivel debe ser mayor a 0.');
      }

      final imageUrl = await _resolveLevelImageUrl();

      await _supabase.from('levels').insert({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'number': levelNumber,
        'image': imageUrl,
        'instrument_id': _instrumentId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nivel creado correctamente.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Error creating level: $e');
      if (!mounted) return;

      final message = e.toString().contains('duplicate key') ||
              e.toString().contains('23505')
          ? 'Ya existe un nivel con ese número para este instrumento.'
          : 'Error al crear el nivel: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
                    Colors.transparent,
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
                    'NUEVO NIVEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instrumentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
          '| Datos del nivel',
          style: TextStyle(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: widget.instrumentName,
          enabled: false,
          decoration: _inputDecoration('Instrumento', Icons.music_note),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _numberController,
          keyboardType: TextInputType.number,
          decoration:
              _inputDecoration('Número de nivel', Icons.format_list_numbered),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Ingresa el número del nivel';
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return 'Debe ser un número mayor a 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration('Nombre del nivel', Icons.school),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa el nombre del nivel'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
          decoration: _inputDecoration('Descripción', Icons.description),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa una descripción'
              : null,
        ),
        const SizedBox(height: 10),
        const Text(
          'La imagen es obligatoria para crear el nivel.',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _showImageSourceDialog,
            icon: const Icon(Icons.upload_file_rounded, color: Colors.blue),
            label: const Text(
              'Subir imagen del nivel',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _createLevel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline, color: Colors.white),
        label: Text(
          _isSaving ? 'Guardando...' : 'Guardar nivel',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
          'Agregar nivel',
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
                  _buildBottomAction(),
                ],
              ),
            ),
    );
  }
}
