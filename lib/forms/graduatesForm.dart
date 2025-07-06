import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterGraduateForm extends StatefulWidget {
  @override
  _RegisterGraduateFormState createState() => _RegisterGraduateFormState();
}

class _RegisterGraduateFormState extends State<RegisterGraduateForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();

  List<int> selectedSedeIds = [];
  List<Map<String, dynamic>> sedes = [];

  List<int> selectedInstrumentIds = [];
  List<Map<String, dynamic>> instruments = [];

  File? imageFile;

  @override
  void initState() {
    super.initState();
    fetchSedes();
    fetchInstruments();
  }

  Future<void> fetchSedes() async {
    try {
      final response = await supabase.from('sedes').select('id, name');
      setState(() {
        sedes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching sedes: $e');
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

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage
          .from('graduates')
          .upload('profile_images/$fileName', file);
      return supabase.storage
          .from('graduates')
          .getPublicUrl('profile_images/$fileName');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> registerGraduate() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedSedeIds.isEmpty) {
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
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile!);
      }

      final response = await supabase
          .from('graduates')
          .insert({
            'first_name': firstNameController.text,
            'last_name': lastNameController.text,
            'email': emailController.text,
            'password': passwordController.text,
            'identification_number': idNumberController.text,
            'profile_image': imageUrl,
          })
          .select()
          .single();

      final graduateId = response['id'];

      // Insert sede relationships
      for (var sedeId in selectedSedeIds) {
        await supabase.from('graduate_sedes').insert({
          'graduate_id': graduateId,
          'sede_id': sedeId,
        });
      }

      // Insert instrument relationships
      for (var instrumentId in selectedInstrumentIds) {
        await supabase.from('graduate_instruments').insert({
          'graduate_id': graduateId,
          'instrument_id': instrumentId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egresado registrado con éxito')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error registering graduate: $e');
      String errorMessage = 'Error al registrar egresado';
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
          'Registrar Egresado',
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
                onTap: pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: imageFile != null
                        ? DecorationImage(
                            image: FileImage(imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageFile == null
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
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: lastNameController,
                decoration: customInputDecoration('Apellido', Icons.person),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: idNumberController,
                decoration: customInputDecoration(
                    'Número de identificación', Icons.badge),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration:
                    customInputDecoration('Correo electrónico', Icons.email),
                validator: (value) {
                  if (value!.isEmpty) return 'Campo requerido';
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
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              MultiSelectDialogField(
                items: sedes
                    .map((sede) =>
                        MultiSelectItem<int>(sede['id'], sede['name']))
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
                    selectedSedeIds = results.cast<int>();
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    'Registrar Egresado',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: registerGraduate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
