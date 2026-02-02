import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:refmp/services/notification_service.dart';

class HeadquartersForm extends StatefulWidget {
  const HeadquartersForm({super.key});

  @override
  _HeadquartersFormState createState() => _HeadquartersFormState();
}

class _HeadquartersFormState extends State<HeadquartersForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _ubicationController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;

  List<int> selectedInstrumentIds = [];
  List<Map<String, dynamic>> instruments = [];

  @override
  void initState() {
    super.initState();
    fetchInstruments();
  }

  Future<void> fetchInstruments() async {
    try {
      final response = await supabase.from('instruments').select('id, name');
      setState(() {
        instruments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching instruments: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = const Uuid().v4();
      await supabase.storage
          .from('headquarters')
          .upload('headquarters_images/$fileName.jpg', imageFile);
      return supabase.storage
          .from('headquarters')
          .getPublicUrl('headquarters_images/$fileName.jpg');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }

      final response = await supabase
          .from('sedes')
          .insert({
            'name': _nameController.text,
            'address': _addressController.text,
            'description': _descriptionController.text,
            'contact_number': _contactNumberController.text,
            'ubication': _ubicationController.text,
            'photo': imageUrl,
          })
          .select()
          .single();

      final headquartersId = response['id'];

      // Insert instrument relationships
      for (var instrumentId in selectedInstrumentIds) {
        await supabase.from('headquarters_instruments').insert({
          'headquarters_id': headquartersId,
          'instrument_id': instrumentId,
        });
      }

      // Crear notificación para todos los usuarios
      try {
        final notifResponse = await supabase
            .from('notifications')
            .insert({
              'title': 'Nueva Sede: ${_nameController.text}',
              'message':
                  'Se agregó una nueva sede. Da clic para ver más detalles',
              'icon': 'home',
              'redirect_to': '/sedes',
              'image': imageUrl,
            })
            .select()
            .single();

        // Enviar notificaciones push a todos los usuarios
        if (notifResponse['id'] != null) {
          final notifId = notifResponse['id'] is int
              ? notifResponse['id'] as int
              : int.tryParse(notifResponse['id'].toString()) ?? 0;

          if (notifId > 0) {
            await NotificationService.sendNotificationToAllUsers(notifId);
          }
        }
      } catch (notifError) {
        debugPrint('⚠️ Error al enviar notificaciones: $notifError');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sede creada exitosamente')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedImage = null;
        selectedInstrumentIds = [];
      });
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating headquarters: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear la sede: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  InputDecoration customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: Colors.blue),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _contactNumberController.dispose();
    _ubicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Sede',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '| Imagen de la Sede',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              // Text(
              //   'La imagen es opcional; se usará la predeterminada si no se selecciona.',
              //   style: TextStyle(
              //     color: Colors.grey[600],
              //     fontSize: 14,
              //   ),
              // ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Center(
                          child: Icon(Icons.cloud_upload,
                              size: 80, color: Colors.blue),
                        )
                      : null,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration:
                    customInputDecoration('Nombre de la sede', Icons.business),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el nombre de la sede' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration:
                    customInputDecoration('Dirección', Icons.location_on),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa la Dirección o lugar' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    customInputDecoration('Descripción', Icons.description),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una breve descripción' : null,
                maxLines: 3,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _contactNumberController,
                decoration:
                    customInputDecoration('Número de contacto', Icons.phone),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el número de contacto' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _ubicationController,
                decoration: customInputDecoration(
                    'Ubicación (URL del mapa)', Icons.map),
                validator: (value) => value!.isEmpty
                    ? 'Por favor, ingrese la url de la Ubicación'
                    : null,
              ),
              SizedBox(height: 10),
              MultiSelectDialogField(
                items: instruments
                    .map((instrument) => MultiSelectItem<int>(
                        instrument['id'], instrument['name']))
                    .toList(),
                title: Text(
                  'Seleccionar Instrumentos',
                  style: TextStyle(
                      color:
                          themeProvider.isDarkMode ? Colors.white : Colors.blue,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                selectedColor: Colors.blue,
                itemsTextStyle: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                selectedItemsTextStyle: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.transparent
                      : Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
                buttonIcon: Icon(Icons.music_note, color: Colors.blue),
                buttonText: Text(
                  'Seleccionar Instrumentos',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                chipDisplay: MultiSelectChipDisplay(
                  chipColor: Colors.blue.withOpacity(0.2),
                  textStyle: TextStyle(color: Colors.blue),
                ),
                onConfirm: (results) {
                  setState(() {
                    selectedInstrumentIds = results.cast<int>();
                  });
                },
              ),
              SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text(
                          'Crear Sede',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _submitForm,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
