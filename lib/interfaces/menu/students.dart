import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.title});
  final String title;

  @override
  _StudentsPageState createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  File? profileImage;

  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName =
          'students/profile_${DateTime.now().millisecondsSinceEpoch}.png';
      await Supabase.instance.client.storage
          .from('students')
          .upload(fileName, imageFile);
      return Supabase.instance.client.storage
          .from('students')
          .getPublicUrl(fileName);
    } catch (error) {
      print('Error al subir la imagen: $error');
      return null;
    }
  }

  Future<void> addStudent() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    String? imageUrl;
    if (profileImage != null) {
      imageUrl = await uploadImage(profileImage!);
    }
    await Supabase.instance.client.from('students').insert({
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'identification_number': _idNumberController.text,
      'password': _passwordController.text,
      'profile_image': imageUrl,
    });
    Navigator.pop(context);
  }

  Future<void> fetchStudents() async {
    final response =
        await Supabase.instance.client.from('students').select('*');
    setState(() {
      students = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> deleteStudent(int studentId) async {
    await Supabase.instance.client
        .from('students')
        .delete()
        .eq('id', studentId);
    fetchStudents();
  }

  void showStudentOptions(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(
                Icons.info,
                color: Colors.blue,
              ),
              title: Text(
                'Más información',
                style: TextStyle(color: Colors.blue),
              ),
              onTap: () {
                Navigator.pop(context);
                showStudentDetails(student);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Eliminar estudiante',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDeleteConfirmation(student['id']);
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteConfirmation(int studentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar estudiante'),
          content:
              Text('¿Estás seguro de que deseas eliminar a este estudiante?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                deleteStudent(studentId);
                Navigator.pop(context);
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void showStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${student['first_name']} ${student['last_name']}',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(80),
                child: student['profile_image'] != null &&
                        student['profile_image'].isNotEmpty
                    ? Image.network(student['profile_image'], height: 100)
                    : Image.asset('assets/images/refmmp.png', height: 100),
              ),
              SizedBox(height: 10),
              Text('Email: ${student['email']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Estudiantes',
          style: TextStyle(color: Colors.white),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
        onPressed: () => addStudent(),
        backgroundColor: Colors.blue,
      ),
      drawer: Menu.buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: fetchStudents, // Llamamos la función al refrescar
        child: ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: student['profile_image'] != null &&
                        student['profile_image'].isNotEmpty
                    ? Image.network(student['profile_image'],
                        height: 50, width: 50, fit: BoxFit.cover)
                    : Image.asset('assets/images/refmmp.png',
                        height: 50, width: 50, fit: BoxFit.cover),
              ),
              title: Text('${student['first_name']} ${student['last_name']}'),
              subtitle: Text(student['email']),
              trailing: IconButton(
                icon: Icon(Icons.more_vert),
                onPressed: () => showStudentOptions(context, student),
              ),
            );
          },
        ),
      ),
    );
  }
}
