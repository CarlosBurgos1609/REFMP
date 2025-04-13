import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  int? selectedSedeId;
  List<dynamic> sedes = [];

  List<dynamic> instrumentos = [];
  List<int> selectedInstrumentIds = [];

  File? imageFile;

  @override
  void initState() {
    super.initState();
    fetchSedes();
    fetchInstrumentos();
  }

  Future<void> fetchSedes() async {
    final response = await supabase.from('sedes').select('id, name');
    setState(() {
      sedes = response;
    });
  }

  Future<void> fetchInstrumentos() async {
    final response = await supabase.from('instruments').select('id, name');
    setState(() {
      instrumentos = response;
    });
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
    final fileExt = file.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';

    // ignore: unused_local_variable
    final storageResponse = await supabase.storage
        .from('students')
        .upload('profile_images/$fileName', file);

    final imageUrl = supabase.storage
        .from('students')
        .getPublicUrl('profile_images/$fileName');

    return imageUrl;
  }

  Future<void> registerStudent() async {
    if (_formKey.currentState!.validate() &&
        selectedSedeId != null &&
        imageFile != null) {
      _formKey.currentState!.save();
      final imageUrl = await uploadImage(imageFile!);

      final response = await supabase
          .from('students')
          .insert({
            'first_name': firstNameController.text,
            'last_name': lastNameController.text,
            'email': emailController.text,
            'password': passwordController.text,
            'identification_number': idNumberController.text,
            'sede_id': selectedSedeId,
            'profile_image': imageUrl,
          })
          .select()
          .single();

      final studentId = response['id'];

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registrar Estudiante')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Text(
              'Imagen de Perfil',
              style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
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
              decoration: customInputDecoration('Nombre'),
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: lastNameController,
              decoration: customInputDecoration('Apellido'),
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: idNumberController,
              decoration: customInputDecoration('Número de identificación'),
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: emailController,
              decoration: customInputDecoration('Correo electrónico'),
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: passwordController,
              decoration: customInputDecoration('Contraseña'),
              obscureText: true,
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: selectedSedeId,
              items: sedes
                  .map((sede) => DropdownMenuItem<int>(
                        value: sede['id'],
                        child: Text(sede['name'],
                            style: TextStyle(color: Colors.blue)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedSedeId = value;
                });
              },
              decoration: customInputDecoration('Sede'),
              validator: (value) =>
                  value == null ? 'Seleccione una sede' : null,
            ),
            SizedBox(height: 20),
            Text('Instrumentos',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ...instrumentos.map((instrumento) {
              final instrumentId = instrumento['id'] as int;
              return CheckboxListTile(
                title: Text(instrumento['name'],
                    style: TextStyle(color: Colors.blue)),
                value: selectedInstrumentIds.contains(instrumentId),
                activeColor: Colors.blue,
                onChanged: (bool? selected) {
                  setState(() {
                    if (selected == true) {
                      selectedInstrumentIds.add(instrumentId);
                    } else {
                      selectedInstrumentIds.remove(instrumentId);
                    }
                  });
                },
              );
            }).toList(),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              onPressed: registerStudent,
              child: Text('Registrar Estudiante'),
            ),
          ]),
        ),
      ),
    );
  }
}
