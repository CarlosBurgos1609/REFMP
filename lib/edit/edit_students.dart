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
        title: const Text(
          'Editar Estudiante',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Ingrese el nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Apellido',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Ingrese el apellido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.email,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
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
                      decoration: InputDecoration(
                        labelText: 'Número de Identificación',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.badge,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
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
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
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
                            children: _instruments.map((instrument) {
                              final isSelected = _selectedInstrumentIds
                                  .contains(instrument['id']);
                              return ChoiceChip(
                                label: Text(
                                  instrument['name'],
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.white : Colors.blue,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.blue,
                                backgroundColor: Colors.blue.withOpacity(0.1),
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
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sedes.isEmpty
                        ? const Text(
                            'Cargando sedes...',
                            style: TextStyle(color: Colors.blue),
                          )
                        : Wrap(
                            spacing: 8,
                            children: _sedes.map((sede) {
                              final isSelected =
                                  _selectedSedeIds.contains(sede['id']);
                              return ChoiceChip(
                                label: Text(
                                  sede['name'],
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.white : Colors.blue,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.blue,
                                backgroundColor: Colors.blue.withOpacity(0.1),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Actualizar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
