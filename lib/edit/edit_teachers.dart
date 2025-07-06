import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditTeacherScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const EditTeacherScreen({super.key, required this.teacher});

  @override
  _EditTeacherScreenState createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<dynamic> _selectedInstrumentIds = [];
  List<dynamic> _selectedSedeIds = [];
  List<Map<String, dynamic>> _instruments = [];
  List<Map<String, dynamic>> _sedes = [];
  File? _presentationImageFile;
  bool _isLoading = false;
  bool _instrumentsChanged = false;
  bool _sedesChanged = false;
  bool _presentationImageChanged = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Teacher data received: ${widget.teacher}');
    _initializeForm();
    _fetchInstrumentsAndSedes();
  }

  void _initializeForm() {
    _firstNameController.text = widget.teacher['first_name']?.toString() ?? '';
    _lastNameController.text = widget.teacher['last_name']?.toString() ?? '';
    _emailController.text = widget.teacher['email']?.toString() ?? '';
    _idNumberController.text =
        widget.teacher['identification_number']?.toString() ?? '';
    // Initialize description, default to empty string if null
    _descriptionController.text =
        widget.teacher['description']?.toString() ?? '';

    debugPrint('Description initialized: ${_descriptionController.text}');
    debugPrint(
        'Image presentation URL: ${widget.teacher['image_presentation']}');
    debugPrint(
        'Checking if description exists in teacher: ${widget.teacher.containsKey('description')}');
    debugPrint(
        'Checking if image_presentation exists in teacher: ${widget.teacher.containsKey('image_presentation')}');

    final instrumentsList =
        widget.teacher['teacher_instruments'] as List<dynamic>?;
    if (instrumentsList != null && instrumentsList.isNotEmpty) {
      _selectedInstrumentIds = instrumentsList
          .where(
              (e) => e['instruments'] != null && e['instruments']['id'] != null)
          .map((e) {
        final id = e['instruments']['id'];
        debugPrint('Instrument ID: $id, type: ${id.runtimeType}');
        return id;
      }).toList();
    } else {
      debugPrint('No teacher_instruments data found');
      _selectedInstrumentIds = [];
    }

    final sedesList = widget.teacher['teacher_headquarters'] as List<dynamic>?;
    if (sedesList != null && sedesList.isNotEmpty) {
      _selectedSedeIds = sedesList
          .where((e) => e['sedes'] != null && e['sedes']['id'] != null)
          .map((e) {
        final id = e['sedes']['id'];
        debugPrint('Sede ID: $id, type: ${id.runtimeType}');
        return id;
      }).toList();
    } else {
      debugPrint('No teacher_headquarters data found');
      _selectedSedeIds = [];
    }

    debugPrint(
        'Initial instruments: $_selectedInstrumentIds, sedes: $_selectedSedeIds');
    setState(() {});
  }

  Future<void> _fetchInstrumentsAndSedes() async {
    try {
      final instrumentsResponse = await Supabase.instance.client
          .from('instruments')
          .select('id, name')
          .order('name', ascending: true);
      final sedesResponse = await Supabase.instance.client
          .from('sedes')
          .select('id, name')
          .order('name', ascending: true);

      setState(() {
        _instruments = List<Map<String, dynamic>>.from(instrumentsResponse);
        _sedes = List<Map<String, dynamic>>.from(sedesResponse);
        debugPrint('Fetched instruments: $_instruments');
        debugPrint('Fetched sedes: $_sedes');
      });
    } catch (e) {
      debugPrint('Error fetching instruments or sedes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar instrumentos o sedes: $e')),
      );
    }
  }

  Future<void> pickPresentationImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _presentationImageFile = File(pickedFile.path);
        _presentationImageChanged = true;
        debugPrint('New presentation image selected: ${pickedFile.path}');
      });
    } else {
      debugPrint('No image selected');
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final fileName =
          'presentation_${DateTime.now().millisecondsSinceEpoch}.png';
      await Supabase.instance.client.storage
          .from('teachers')
          .upload('presentation_images/$fileName', file);
      final url = Supabase.instance.client.storage
          .from('teachers')
          .getPublicUrl('presentation_images/$fileName');
      debugPrint('Uploaded presentation image URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error uploading presentation image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen de presentación: $e')),
      );
      return null;
    }
  }

  Future<void> _updateTeacher() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    if (_instrumentsChanged && _selectedInstrumentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un instrumento')),
      );
      return;
    }
    if (_sedesChanged && _selectedSedeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos una sede')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? presentationImageUrl = widget.teacher['image_presentation'];
      if (_presentationImageChanged && _presentationImageFile != null) {
        presentationImageUrl = await uploadImage(_presentationImageFile!);
        if (presentationImageUrl == null) {
          throw Exception('Failed to upload presentation image');
        }
      }

      // Update teacher details
      final updateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'identification_number': _idNumberController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_presentation':
            presentationImageUrl, // Set image_presentation directly
      };
      debugPrint('Updating teacher with data: $updateData');
      await Supabase.instance.client
          .from('teachers')
          .update(updateData)
          .eq('id', widget.teacher['id']);

      // Update instruments only if changed
      if (_instrumentsChanged) {
        await Supabase.instance.client
            .from('teacher_instruments')
            .delete()
            .eq('teacher_id', widget.teacher['id']);
        if (_selectedInstrumentIds.isNotEmpty) {
          final instrumentInserts = _selectedInstrumentIds
              .map((id) => {
                    'teacher_id': widget.teacher['id'],
                    'instrument_id': id,
                  })
              .toList();
          await Supabase.instance.client
              .from('teacher_instruments')
              .insert(instrumentInserts);
        }
      }

      // Update sedes only if changed
      if (_sedesChanged) {
        await Supabase.instance.client
            .from('teacher_headquarters')
            .delete()
            .eq('teacher_id', widget.teacher['id']);
        if (_selectedSedeIds.isNotEmpty) {
          final sedeInserts = _selectedSedeIds
              .map((id) => {
                    'teacher_id': widget.teacher['id'],
                    'sede_id': id,
                  })
              .toList();
          await Supabase.instance.client
              .from('teacher_headquarters')
              .insert(sedeInserts);
        }
      }

      // Verify update in database
      final updatedTeacher = await Supabase.instance.client
          .from('teachers')
          .select('description, image_presentation')
          .eq('id', widget.teacher['id'])
          .single();
      debugPrint('Updated teacher data: $updatedTeacher');

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profesor actualizado con éxito')),
      );
    } catch (e) {
      debugPrint('Error updating teacher: $e');
      String errorMessage = 'Error al actualizar profesor';
      if (e.toString().contains('unique constraint')) {
        if (e.toString().contains('email')) {
          errorMessage = 'El correo electrónico ya está en uso';
        } else if (e.toString().contains('identification_number')) {
          errorMessage = 'El número de identificación ya está registrado';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelEdit() {
    Navigator.pop(context);
  }

  InputDecoration customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.blue,
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: _cancelEdit,
        ),
        title: const Text(
          'Editar Profesor',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: customInputDecoration('Nombre', Icons.person),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Ingrese el nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration:
                          customInputDecoration('Apellido', Icons.person),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Ingrese el apellido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: customInputDecoration(
                          'Correo Electrónico', Icons.email),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.trim().isEmpty) return 'Ingrese el correo';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Ingrese un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idNumberController,
                      decoration: customInputDecoration(
                          'Número de Identificación', Icons.badge),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.trim().isEmpty
                          ? 'Ingrese el número de identificación'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Instrumentos',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _instruments.isEmpty
                        ? Text(
                            'Cargando instrumentos...',
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.blue,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _instruments.map((instrument) {
                              final isSelected = _selectedInstrumentIds
                                  .contains(instrument['id']);
                              return ChoiceChip(
                                label: Text(
                                  instrument['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.blue,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.blue,
                                backgroundColor: themeProvider.isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: themeProvider.isDarkMode
                                        ? Colors.blue.withOpacity(0.5)
                                        : Colors.blue,
                                  ),
                                ),
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  setState(() {
                                    _instrumentsChanged = true;
                                    if (selected) {
                                      _selectedInstrumentIds
                                          .add(instrument['id']);
                                    } else {
                                      _selectedInstrumentIds
                                          .remove(instrument['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16),
                    Text(
                      'Sedes',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sedes.isEmpty
                        ? Text(
                            'Cargando sedes...',
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.blue,
                            ),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _sedes.map((sede) {
                              final isSelected =
                                  _selectedSedeIds.contains(sede['id']);
                              return ChoiceChip(
                                label: Text(
                                  sede['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : themeProvider.isDarkMode
                                            ? Colors.white
                                            : Colors.blue,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.blue,
                                backgroundColor: themeProvider.isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: themeProvider.isDarkMode
                                        ? Colors.blue.withOpacity(0.5)
                                        : Colors.blue,
                                  ),
                                ),
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  setState(() {
                                    _sedesChanged = true;
                                    if (selected) {
                                      _selectedSedeIds.add(sede['id']);
                                    } else {
                                      _selectedSedeIds.remove(sede['id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 40,
                      thickness: 2,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 34, 34, 34)
                          : const Color.fromARGB(255, 236, 234, 234),
                    ),
                    const Text(
                      'Los siguientes campos son opcionales',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Imagen de Presentación',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La imagen es opcional; se usará la predeterminada si no se selecciona.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                            image: _presentationImageFile != null
                                ? DecorationImage(
                                    image: FileImage(_presentationImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : widget.teacher['image_presentation'] !=
                                            null &&
                                        widget.teacher['image_presentation']
                                            .toString()
                                            .isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(widget
                                            .teacher['image_presentation']),
                                        fit: BoxFit.cover,
                                        onError: (exception, stackTrace) {
                                          debugPrint(
                                              'Error loading image: $exception');
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Error al cargar la imagen: $exception')),
                                          );
                                        },
                                      )
                                    : null,
                          ),
                          child: _presentationImageFile == null &&
                                  (widget.teacher['image_presentation'] ==
                                          null ||
                                      widget.teacher['image_presentation']
                                          .toString()
                                          .isEmpty)
                              ? const Center(
                                  child: Icon(Icons.cloud_upload,
                                      size: 80, color: Colors.blue),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.blue,
                            onPressed: pickPresentationImage,
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: customInputDecoration(
                          'Descripción', Icons.description),
                      maxLines: 4,
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      // Remove validator to make description optional
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isLoading ? null : _updateTeacher,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.red),
                            ),
                            onPressed: _cancelEdit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
