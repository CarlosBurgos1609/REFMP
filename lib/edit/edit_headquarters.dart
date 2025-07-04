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
    Map<String, dynamic>? initialSedeData,
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
      await Supabase.instance.client.from('sedes').update({
        'name': _nameController.text.trim(),
        'type_headquarters': _typeHeadquartersController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contact_number': _contactNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'ubication': _ubicationController.text.trim(),
        'photo': _photoController.text.trim(),
      }).eq('id', widget.id);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: _cancelEdit,
        ),
        title: const Text(
          'Editar Sede',
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
                    const SizedBox(height: 10),
                    _photoController.text.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Image.network(
                                  _photoController.text,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Error al cargar la imagen',
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: const Text(
                                      'La imagen no se puede editar',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'No hay imagen disponible',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          customInputDecoration('Nombre', Icons.business),
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
                      controller: _typeHeadquartersController,
                      decoration:
                          customInputDecoration('Tipo de Sede', Icons.category),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      validator: (value) => value!.trim().isEmpty
                          ? 'Ingrese el tipo de sede'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: customInputDecoration(
                          'Descripción', Icons.description),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactNumberController,
                      decoration: customInputDecoration(
                          'Número de Contacto', Icons.phone),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
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
                      decoration:
                          customInputDecoration('Dirección', Icons.location_on),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Ingrese la dirección' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ubicationController,
                      decoration: customInputDecoration(
                          'Ubicación (URL del mapa)', Icons.map),
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black,
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
                            onPressed: _isLoading ? null : _updateHeadquarters,
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
