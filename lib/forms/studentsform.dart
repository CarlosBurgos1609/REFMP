import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentForm extends StatefulWidget {
  const StudentForm({super.key});

  @override
  _StudentFormState createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedSede;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient supabase = Supabase.instance.client;
  List<String> _sedes = [];

  @override
  void initState() {
    super.initState();
    _fetchSedes();
  }

  Future<void> _fetchSedes() async {
    final response = await supabase.from('sedes').select('name');
    setState(() {
      _sedes = response.map<String>((sede) => sede['name'].toString()).toList();
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final fileName = 'students/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response =
          await supabase.storage.from('students').uploadBinary(fileName, bytes);
      final imageUrl = supabase.storage.from('students').getPublicUrl(fileName);
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      await supabase.from('students').insert({
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'identification_number': _idNumberController.text,
        'sede_name': _selectedSede,
        'email': _emailController.text,
        'password': _passwordController.text,
        'profile_image': _profileImageUrl,
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Formulario de Estudiante')),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(labelText: 'Nombre'),
                    validator: (value) =>
                        value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(labelText: 'Apellido'),
                    validator: (value) =>
                        value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  TextFormField(
                    controller: _idNumberController,
                    decoration:
                        InputDecoration(labelText: 'Número de Identificación'),
                    validator: (value) =>
                        value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedSede,
                    decoration: InputDecoration(labelText: 'Sede'),
                    items: _sedes
                        .map((sede) =>
                            DropdownMenuItem(value: sede, child: Text(sede)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedSede = value),
                    validator: (value) =>
                        value == null ? 'Seleccione una sede' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (value) =>
                        value!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  SizedBox(height: 16),
                  _profileImageUrl != null
                      ? CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(_profileImageUrl!))
                      : Icon(Icons.account_circle, size: 100),
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.image),
                    label: Text('Subir Imagen'),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveStudent,
                        icon: Icon(Icons.save, color: Colors.white),
                        label: Text('Guardar',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.cancel, color: Colors.white),
                        label: Text('Cancelar',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ));
  }
}
