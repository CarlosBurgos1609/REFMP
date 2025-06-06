import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterStudentForm extends StatefulWidget {
  @override
  _RegisterStudentFormState createState() => _RegisterStudentFormState();
}

class _RegisterStudentFormState extends State<RegisterStudentForm> {
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
          .from('students')
          .upload('profile_images/$fileName', file);
      return supabase.storage
          .from('students')
          .getPublicUrl('profile_images/$fileName');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile!);
      }

      final response = await supabase
          .from('students')
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

      final studentId = response['id'];

      // Insert sede relationships
      for (var sedeId in selectedSedeIds) {
        await supabase.from('student_sedes').insert({
          'student_id': studentId,
          'sede_id': sedeId,
        });
      }

      // Insert instrument relationships
      for (var instrumentId in selectedInstrumentIds) {
        await supabase.from('student_instruments').insert({
          'student_id': studentId,
          'instrument_id': instrumentId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estudiante registrado con éxito')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error registering student: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar estudiante')),
      );
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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Registrar Estudiante',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Imagen de Perfil',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                'La imagen es opcional; se usará la predeterminada si no se selecciona.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
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
                      ? Center(
                          child: Icon(Icons.cloud_upload,
                              size: 80, color: Colors.blue),
                        )
                      : null,
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: firstNameController,
                decoration: customInputDecoration('Nombre', Icons.person),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: lastNameController,
                decoration: customInputDecoration('Apellido', Icons.person),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: idNumberController,
                decoration: customInputDecoration(
                    'Número de identificación', Icons.badge),
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              SizedBox(height: 10),
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
              SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                decoration: customInputDecoration('Contraseña', Icons.lock),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
              ),
              SizedBox(height: 10),
              MultiSelectDialogField(
                items: sedes
                    .map((sede) =>
                        MultiSelectItem<int>(sede['id'], sede['name']))
                    .toList(),
                title: Text('Seleccionar Sedes'),
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
                buttonIcon: Icon(Icons.location_on, color: Colors.blue),
                buttonText: Text(
                  'Seleccionar Sedes',
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
                    selectedSedeIds = results.cast<int>();
                  });
                },
              ),
              SizedBox(height: 10),
              MultiSelectDialogField(
                items: instruments
                    .map((instrument) => MultiSelectItem<int>(
                        instrument['id'], instrument['name']))
                    .toList(),
                title: Text('Seleccionar Instrumentos'),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Text(
                    'Registrar Estudiante',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: registerStudent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
