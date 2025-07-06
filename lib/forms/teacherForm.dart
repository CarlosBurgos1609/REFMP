import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterTeacherForm extends StatefulWidget {
  @override
  _RegisterTeacherFormState createState() => _RegisterTeacherFormState();
}

class _RegisterTeacherFormState extends State<RegisterTeacherForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  List<int> selectedHeadquarterIds = [];
  List<Map<String, dynamic>> headquarters = [];

  List<int> selectedInstrumentIds = [];
  List<Map<String, dynamic>> instruments = [];

  File? profileImageFile;
  File? presentationImageFile;

  @override
  void initState() {
    super.initState();
    fetchHeadquarters();
    fetchInstruments();
  }

  Future<void> fetchHeadquarters() async {
    try {
      final response = await supabase.from('headquarters').select('id, name');
      setState(() {
        headquarters = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching headquarters: $e');
    }
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

  Future<void> pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        profileImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> pickPresentationImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        presentationImageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImage(File file, String folder) async {
    try {
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage.from('teachers').upload('$folder/$fileName', file);
      return supabase.storage
          .from('teachers')
          .getPublicUrl('$folder/$fileName');
    } catch (e) {
      debugPrint('Error uploading image to $folder: $e');
      return null;
    }
  }

  Future<void> registerTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedHeadquarterIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos una sede')),
      );
      return;
    }

    if (selectedInstrumentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione al menos un instrumento')),
      );
      return;
    }

    try {
      String? profileImageUrl;
      String? presentationImageUrl;
      if (profileImageFile != null) {
        profileImageUrl =
            await uploadImage(profileImageFile!, 'profile_images');
      }
      if (presentationImageFile != null) {
        presentationImageUrl =
            await uploadImage(presentationImageFile!, 'presentation_images');
      }

      final response = await supabase
          .from('teachers')
          .insert({
            'first_name': firstNameController.text.trim(),
            'last_name': lastNameController.text.trim(),
            'email': emailController.text.trim(),
            'password': passwordController.text.trim(),
            'identification_number': idNumberController.text.trim(),
            'profile_image': profileImageUrl,
            'description': descriptionController.text.trim(),
            'image_presentation': presentationImageUrl,
          })
          .select()
          .single();

      final teacherId = response['id'];

      // Insert headquarter relationships
      for (var headquarterId in selectedHeadquarterIds) {
        await supabase.from('teacher_headquarters').insert({
          'teacher_id': teacherId,
          'headquarter_id': headquarterId,
        });
      }

      // Insert instrument relationships
      for (var instrumentId in selectedInstrumentIds) {
        await supabase.from('teacher_instruments').insert({
          'teacher_id': teacherId,
          'instrument_id': instrumentId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profesor registrado con éxito')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error registering teacher: $e');
      String errorMessage = 'Error al registrar profesor';
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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Registrar Profesor',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Imagen de Perfil',
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
              GestureDetector(
                onTap: pickProfileImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: profileImageFile != null
                        ? DecorationImage(
                            image: FileImage(profileImageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profileImageFile == null
                      ? const Center(
                          child: Icon(Icons.cloud_upload,
                              size: 80, color: Colors.blue),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: firstNameController,
                decoration: customInputDecoration('Nombre', Icons.person),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: lastNameController,
                decoration: customInputDecoration('Apellido', Icons.person),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: idNumberController,
                decoration: customInputDecoration(
                    'Número de identificación', Icons.badge),
                validator: (value) =>
                    value!.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration:
                    customInputDecoration('Correo electrónico', Icons.email),
                validator: (value) {
                  if (value!.trim().isEmpty) return 'Campo requerido';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                decoration: customInputDecoration('Contraseña', Icons.lock),
                obscureText: true,
                validator: (value) =>
                    value!.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              MultiSelectDialogField(
                items: headquarters
                    .map((headquarter) => MultiSelectItem<int>(
                        headquarter['id'], headquarter['name']))
                    .toList(),
                title: Text(
                  'Seleccionar Sedes',
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
                buttonIcon: const Icon(Icons.location_on, color: Colors.blue),
                buttonText: const Text(
                  'Seleccionar Sedes',
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
                    selectedHeadquarterIds = results.cast<int>();
                  });
                },
              ),
              const SizedBox(height: 10),
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
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
                buttonIcon: const Icon(Icons.music_note, color: Colors.blue),
                buttonText: const Text(
                  'Seleccionar Instrumentos',
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
                    selectedInstrumentIds = results.cast<int>();
                  });
                },
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
              GestureDetector(
                onTap: pickPresentationImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: presentationImageFile != null
                        ? DecorationImage(
                            image: FileImage(presentationImageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: presentationImageFile == null
                      ? const Center(
                          child: Icon(Icons.cloud_upload,
                              size: 80, color: Colors.blue),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: descriptionController,
                decoration:
                    customInputDecoration('Descripción', Icons.description),
                maxLines: 4,
                validator: (value) =>
                    value!.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    'Registrar Profesor',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: registerTeacher,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
