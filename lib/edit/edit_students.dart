import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditStudentScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const EditStudentScreen({super.key, required this.student});

  @override
  _EditStudentScreenState createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  List<dynamic> _selectedInstrumentIds = [];
  List<dynamic> _selectedSedeIds = [];
  List<Map<String, dynamic>> _instruments = [];
  List<Map<String, dynamic>> _sedes = [];
  bool _isLoading = false;
  bool _instrumentsChanged = false;
  bool _sedesChanged = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Student data received: ${widget.student}');
    _initializeForm();
    _fetchInstrumentsAndSedes();
  }

  void _initializeForm() {
    _firstNameController.text = widget.student['first_name'] ?? '';
    _lastNameController.text = widget.student['last_name'] ?? '';
    _emailController.text = widget.student['email'] ?? '';
    _idNumberController.text = widget.student['identification_number'] ?? '';

    final instrumentsList =
        widget.student['student_instruments'] as List<dynamic>?;
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
      debugPrint('No student_instruments data found');
      _selectedInstrumentIds = [];
    }

    final sedesList = widget.student['student_sedes'] as List<dynamic>?;
    if (sedesList != null && sedesList.isNotEmpty) {
      _selectedSedeIds = sedesList
          .where((e) => e['sedes'] != null && e['sedes']['id'] != null)
          .map((e) {
        final id = e['sedes']['id'];
        debugPrint('Sede ID: $id, type: ${id.runtimeType}');
        return id;
      }).toList();
    } else {
      debugPrint('No student_sedes data found');
      _selectedSedeIds = [];
    }

    debugPrint(
        'Initial instruments: $_selectedInstrumentIds, sedes: $_selectedSedeIds');
    setState(() {}); // Force UI refresh
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
        debugPrint('Fetched instruments: $_instruments, sedes: $_sedes');
      });
    } catch (e) {
      debugPrint('Error fetching instruments or sedes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar instrumentos o sedes: $e')),
      );
    }
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

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
      // Update student details
      await Supabase.instance.client.from('students').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'identification_number': _idNumberController.text.trim(),
      }).eq('id', widget.student['id']);

      // Update instruments only if changed
      if (_instrumentsChanged) {
        await Supabase.instance.client
            .from('student_instruments')
            .delete()
            .eq('student_id', widget.student['id']);
        if (_selectedInstrumentIds.isNotEmpty) {
          final instrumentInserts = _selectedInstrumentIds
              .map((id) => {
                    'student_id': widget.student['id'],
                    'instrument_id': id,
                  })
              .toList();
          await Supabase.instance.client
              .from('student_instruments')
              .insert(instrumentInserts);
        }
      }

      // Update sedes only if changed
      if (_sedesChanged) {
        await Supabase.instance.client
            .from('student_sedes')
            .delete()
            .eq('student_id', widget.student['id']);
        if (_selectedSedeIds.isNotEmpty) {
          final sedeInserts = _selectedSedeIds
              .map((id) => {
                    'student_id': widget.student['id'],
                    'sede_id': id,
                  })
              .toList();
          await Supabase.instance.client
              .from('student_sedes')
              .insert(sedeInserts);
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudiante actualizado con éxito')),
      );
    } catch (e) {
      debugPrint('Error updating student: $e');
      String errorMessage = 'Error al actualizar estudiante';
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
      labelStyle: TextStyle(
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
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
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
          'Editar Estudiante',
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
                            onPressed: _isLoading ? null : _updateStudent,
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
