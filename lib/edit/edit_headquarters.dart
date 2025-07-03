import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditHeadquarters extends StatefulWidget {
  final String id;
  final String name;

  const EditHeadquarters({
    super.key,
    required this.id,
    required this.name,
    Map<String, dynamic>? initialSedeData, // Hacerlo opcional
  });

  @override
  State<EditHeadquarters> createState() => _EditHeadquartersState();
}

class _EditHeadquartersState extends State<EditHeadquarters> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeHeadquartersController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _ubicationController = TextEditingController();
  final _photoController = TextEditingController();
  List<dynamic> _selectedInstrumentIds = [];
  List<Map<String, dynamic>> _instruments = [];
  bool _isLoading = false;
  bool _instrumentsChanged = false;
  Map<String, dynamic>? _sedeData;

  @override
  void initState() {
    super.initState();
    _fetchSedeData();
    _fetchInstruments();
  }

  Future<void> _fetchSedeData() async {
    try {
      final response = await Supabase.instance.client
          .from('sedes')
          .select(
              'id, name, type_headquarters, description, contact_number, address, ubication, photo')
          .eq('id', widget.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _sedeData = Map<String, dynamic>.from(response);
          _nameController.text = _sedeData!['name'] ?? '';
          _typeHeadquartersController.text =
              _sedeData!['type_headquarters'] ?? '';
          _descriptionController.text = _sedeData!['description'] ?? '';
          _contactNumberController.text = _sedeData!['contact_number'] ?? '';
          _addressController.text = _sedeData!['address'] ?? '';
          _ubicationController.text = _sedeData!['ubication'] ?? '';
          _photoController.text = _sedeData!['photo'] ?? '';
        });

        // Fetch associated instruments
        final instrumentResponse = await Supabase.instance.client
            .from('sede_instruments')
            .select('instruments(id)')
            .eq('sede_id', widget.id);

        setState(() {
          _selectedInstrumentIds = instrumentResponse
              .map((e) => e['instruments']['id'])
              .where((id) => id != null)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching sede data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos de la sede: $e')),
      );
    }
  }

  Future<void> _fetchInstruments() async {
    try {
      final response = await Supabase.instance.client
          .from('instruments')
          .select('id, name')
          .order('name', ascending: true);

      setState(() {
        _instruments = List<Map<String, dynamic>>.from(response);
        debugPrint('Fetched instruments: $_instruments');
      });
    } catch (e) {
      debugPrint('Error fetching instruments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar instrumentos: $e')),
      );
    }
  }

  Future<void> _updateHeadquarters() async {
    if (!_formKey.currentState!.validate()) return;

    if (_instrumentsChanged && _selectedInstrumentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un instrumento')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update sede details
      await Supabase.instance.client.from('sedes').update({
        'name': _nameController.text.trim(),
        'type_headquarters': _typeHeadquartersController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contact_number': _contactNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'ubication': _ubicationController.text.trim(),
        'photo': _photoController.text.trim(),
      }).eq('id', widget.id);

      // Update instruments only if changed
      if (_instrumentsChanged) {
        await Supabase.instance.client
            .from('sede_instruments')
            .delete()
            .eq('sede_id', widget.id);
        if (_selectedInstrumentIds.isNotEmpty) {
          final instrumentInserts = _selectedInstrumentIds
              .map((id) => {
                    'sede_id': widget.id,
                    'instrument_id': id,
                  })
              .toList();
          await Supabase.instance.client
              .from('sede_instruments')
              .insert(instrumentInserts);
        }
      }

      // Devolver true para indicar que la actualización fue exitosa
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sede actualizada con éxito')),
      );
    } catch (e) {
      debugPrint('Error updating sede: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la sede: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeHeadquartersController.dispose();
    _descriptionController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    _ubicationController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Editar Sede',
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
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.business,
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
                      controller: _typeHeadquartersController,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Sede',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.category,
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
                      validator: (value) => value!.trim().isEmpty
                          ? 'Ingrese el tipo de sede'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.description,
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
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: InputDecoration(
                        labelText: 'Número de Contacto',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
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
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value!.trim().isEmpty)
                          return 'Ingrese el número de contacto';
                        if (!RegExp(r'^\+?\d{10,}$').hasMatch(value)) {
                          return 'Ingrese un número de contacto válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Dirección',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.location_on,
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
                          value!.trim().isEmpty ? 'Ingrese la dirección' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ubicationController,
                      decoration: InputDecoration(
                        labelText: 'Ubicación (URL del mapa)',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.map,
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
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value!.trim().isEmpty)
                          return 'Ingrese la URL de ubicación';
                        if (!RegExp(r'^https?://').hasMatch(value)) {
                          return 'Ingrese una URL válida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _photoController,
                      decoration: InputDecoration(
                        labelText: 'URL de la Foto',
                        labelStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        prefixIcon: Icon(
                          Icons.image,
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
                      keyboardType: TextInputType.url,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateHeadquarters,
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
