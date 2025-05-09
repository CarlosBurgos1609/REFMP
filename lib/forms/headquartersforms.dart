import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class HeadquartersForm extends StatefulWidget {
  const HeadquartersForm({super.key});

  @override
  _HeadquartersFormState createState() => _HeadquartersFormState();
}

class _HeadquartersFormState extends State<HeadquartersForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _ubicationController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    final fileName = const Uuid().v4();
    final storageResponse = await Supabase.instance.client.storage
        .from('headquarters')
        .upload('headquarters_images/$fileName.jpg', imageFile);

    if (storageResponse.isNotEmpty) {
      final publicUrl = Supabase.instance.client.storage
          .from('headquarters')
          .getPublicUrl('headquarters_images/$fileName.jpg');
      return publicUrl;
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una imagen.')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final imageUrl = await _uploadImage(_selectedImage!);

        if (imageUrl == null) {
          throw Exception('No se pudo subir la imagen.');
        }

        await Supabase.instance.client.from('sedes').insert({
          'name': _nameController.text,
          'address': _addressController.text,
          'description': _descriptionController.text,
          'contact_number': _contactNumberController.text,
          'ubication': _ubicationController.text,
          'photo': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sede creada exitosamente')),
        );

        _formKey.currentState!.reset();
        setState(() {
          _selectedImage = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la sede: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration customInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Sede',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: customInputDecoration('Nombre de la sede'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el nombre de la sede' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _addressController,
                decoration: customInputDecoration('Dirección'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa la Dirección o lugar' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: customInputDecoration('Descripción'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una breve descripción' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactNumberController,
                decoration: customInputDecoration('Número de contacto'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el número de contacto' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ubicationController,
                decoration: customInputDecoration('Ubicación (URL del mapa)'),
                validator: (value) => value!.isEmpty
                    ? 'Por favor, ingrese la url de la Ubicación'
                    : null,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : const Center(child: Text('Selecciona una imagen')),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Crear Sede',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
