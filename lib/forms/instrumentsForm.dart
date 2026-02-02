import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/services/notification_service.dart';

class InstrumentsForm extends StatefulWidget {
  const InstrumentsForm({super.key});

  @override
  _InstrumentsFormState createState() => _InstrumentsFormState();
}

class _InstrumentsFormState extends State<InstrumentsForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

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
          .from('instruments')
          .upload('instrument_images/$fileName.jpg', imageFile);
      return supabase.storage
          .from('instruments')
          .getPublicUrl('instrument_images/$fileName.jpg');
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

      await supabase.from('instruments').insert({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'photo': imageUrl,
      });

      // Crear notificación para todos los usuarios
      try {
        final notifResponse = await supabase.from('notifications').insert({
          'title': 'Nuevo Instrumento: ${_nameController.text}',
          'message':
              'Se agregó un nuevo instrumento. Da clic para ver más detalles',
          'icon': 'music',
          'redirect_to': '/instruments',
          'image': imageUrl,
        }).select().single();

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
        const SnackBar(content: Text('Instrumento creado exitosamente')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedImage = null;
      });
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating instrument: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el instrumento: $e')),
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
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Instrumento',
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
                '| Imagen del Instrumento',
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
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
                decoration: customInputDecoration(
                    'Nombre del instrumento', Icons.music_note),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el nombre del instrumento' : null,
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
              SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text(
                          'Crear Instrumento',
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
