import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:refmp/services/notification_service.dart';

class ObjetsForm extends StatefulWidget {
  const ObjetsForm({super.key});

  @override
  _ObjetsFormState createState() => _ObjetsFormState();
}

class _ObjetsFormState extends State<ObjetsForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  File? _selectedImage;
  String?
      _fileExtension; // To track file extension (e.g., .jpg, .gif, .webp, .avif)
  bool _isLoading = false;

  List<String> selectedCategories = [];
  List<String> categories = [];

  static const int maxImageSizeBytes = 3000000; // 3MB limit

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await supabase.from('objets').select('category');
      final uniqueCategories =
          response.map((item) => item['category'] as String).toSet().toList();
      setState(() {
        categories = uniqueCategories;
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<File?> _compressImage(File file, String extension) async {
    try {
      final tempDir = Directory.systemTemp;
      final targetPath = '${tempDir.path}/${const Uuid().v4()}$extension';
      CompressFormat format;

      switch (extension.toLowerCase()) {
        case '.jpg':
        case '.jpeg':
          format = CompressFormat.jpeg;
          break;
        case '.png':
          format = CompressFormat.png;
          break;
        case '.webp':
          format = CompressFormat.webp;
          break;
        case '.gif':
          // flutter_image_compress doesn't support GIF compression
          return file; // Return original file for GIFs
        default:
          return null; // Unsupported format
      }

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: extension == '.gif' ? 100 : 80, // Minimal compression for GIFs
        minWidth: 1024,
        minHeight: 1024,
        format: format,
      );

      if (compressedFile == null) {
        debugPrint('Image compression failed for $extension');
        return null;
      }

      return File(compressedFile.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File originalFile = File(pickedFile.path);
      final extension = path.extension(pickedFile.path).toLowerCase();
      final supportedFormats = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.avif'
      ];
      if (!supportedFormats.contains(extension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato de archivo no soportado')),
        );
        return;
      }

      File? processedFile = await _compressImage(originalFile, extension);

      if (processedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la imagen')),
        );
        return;
      }

      final fileSize = await processedFile.length();
      if (fileSize > maxImageSizeBytes) {
        final formatName = extension.toUpperCase().replaceFirst('.', '');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            contentPadding: const EdgeInsets.all(16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 8),
                Text(
                  '$formatName demasiado pesado',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El $formatName excede el límite de 3MB (${(fileSize / 1000000).toStringAsFixed(2)}MB). Por favor, elija otro $formatName o comprímalo.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      setState(() {
        _selectedImage = processedFile;
        _fileExtension = extension;
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      if (fileSize > maxImageSizeBytes) {
        throw Exception('Archivo excede el límite de 3MB');
      }

      final fileName = const Uuid().v4();
      final extension = _fileExtension ?? '.jpg';
      final uploadPath = 'object_images/$fileName$extension';

      await supabase.storage.from('objets').upload(uploadPath, imageFile);
      return supabase.storage.from('objets').getPublicUrl(uploadPath);
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
        if (imageUrl == null) {
          throw Exception('Error al subir la imagen');
        }
      }

      // ignore: unused_local_variable
      final response = await supabase
          .from('objets')
          .insert({
            'name': _nameController.text,
            'description': _descriptionController.text,
            'price': int.parse(_priceController.text),
            'image_url': imageUrl,
            'category':
                selectedCategories.isNotEmpty ? selectedCategories.first : null,
          })
          .select()
          .single();

      // Crear notificación para todos los usuarios
      try {
        final notifResponse = await supabase
            .from('notifications')
            .insert({
              'title': 'Nuevo Objeto: ${_nameController.text}',
              'message':
                  'Disponible por ${_priceController.text} monedas. Da clic para ver más detalles',
              'icon': 'star',
              'redirect_to': '/home',
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
        const SnackBar(content: Text('Objeto creado exitosamente')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _selectedImage = null;
        _fileExtension = null;
        selectedCategories = [];
      });
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating object: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el objeto: $e')),
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
      labelStyle:
          const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: Colors.blue),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
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
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Objeto',
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
              const Text(
                '| Imagen del Objeto',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
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
                      ? const Center(
                          child: Icon(Icons.cloud_upload,
                              size: 80, color: Colors.blue),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration:
                    customInputDecoration('Nombre del objeto', Icons.label),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa el nombre del objeto' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    customInputDecoration('Descripción', Icons.description),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una breve descripción' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceController,
                decoration:
                    customInputDecoration('Precio', Icons.monetization_on),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Ingresa el precio';
                  if (int.tryParse(value) == null || int.parse(value) < 0)
                    return 'Ingresa un precio válido';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              MultiSelectDialogField(
                items: categories
                    .map((category) =>
                        MultiSelectItem<String>(category, category))
                    .toList(),
                title: Text(
                  'Seleccionar Categoría',
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
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
                buttonIcon: const Icon(Icons.category, color: Colors.blue),
                buttonText: const Text(
                  'Seleccionar Categoría',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                chipDisplay: MultiSelectChipDisplay(
                  chipColor: Colors.blue.withOpacity(0.2),
                  textStyle: const TextStyle(color: Colors.blue),
                ),
                onConfirm: (results) {
                  setState(() {
                    selectedCategories = results.cast<String>();
                  });
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Crear Objeto',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
