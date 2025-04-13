import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:refmp/forms/studentsform.dart';

import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.title});
  final String title;

  @override
  _StudentsPageState createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  File? profileImage;

  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];

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
    final response = await Supabase.instance.client
        .from('students')
        .select(
            '*, student_instruments(instruments(name)), sedes!students_sede_id_fkey(name)')
        .order('first_name', ascending: true); // Ordenar por nombre

    setState(() {
      students = List<Map<String, dynamic>>.from(response);
      filteredStudents = students;
    });
  }

  void filterStudents(String query) {
    setState(() {
      filteredStudents = students.where((student) {
        final firstName = student['first_name'].toLowerCase();
        return firstName.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> deleteStudent(int studentId) async {
    await Supabase.instance.client
        .from('students')
        .delete()
        .eq('id', studentId)
        .order('first_name', ascending: true);
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
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.blue),
              ),
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
                borderRadius: BorderRadius.circular(500),
                child: student['profile_image'] != null &&
                        student['profile_image'].isNotEmpty
                    ? Image.network(
                        student['profile_image'],
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      )
                    : Image.asset('assets/images/refmmp.png', height: 100),
              ),
              SizedBox(height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['email'],
                    style: TextStyle(color: Colors.blue, height: 2),
                  ),
                  Text(
                    'Instrumento(s): ${student['student_instruments'] != null && student['student_instruments'].isNotEmpty ? student['student_instruments'].map((e) => e['instruments']['name']).join(', ') : 'No asignados'}',
                    style: TextStyle(height: 2),
                  ),
                  Text(
                    'Sede(s): ${student['student_sedes'] != null && student['student_sedes'].isNotEmpty ? student['student_sedes'].map((e) => e['sedes']['name']).join(', ') : 'No asignadas'}',
                    style: TextStyle(height: 2),
                  ),
                ],
              ),
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
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar estudiante...',
            hintStyle: TextStyle(color: Colors.white),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: filterStudents, // Filtra en tiempo real
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterStudentForm()),
          );
        },
        backgroundColor: Colors.blue,
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
      drawer: Menu.buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: fetchStudents,
        color: Colors.blue, // Llamamos la función al refrescar
        child: ListView.builder(
          itemCount: filteredStudents.length,
          itemBuilder: (context, index) {
            final student = filteredStudents[index];
            return Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: student['profile_image'] != null &&
                            student['profile_image'].isNotEmpty
                        ? Image.network(student['profile_image'],
                            height: 50, width: 50, fit: BoxFit.cover)
                        : Image.asset('assets/images/refmmp.png',
                            height: 50, width: 50, fit: BoxFit.cover),
                  ),
                  title: Text(
                    '${student['first_name']} ${student['last_name']}',
                    style: TextStyle(color: Colors.blue),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['email']),
                      Text(
                          'Instrumentos: ${student['student_instruments'] != null && student['student_instruments'].isNotEmpty ? student['student_instruments'].map((e) => e['instruments']['name']).join(', ') : 'No asignados'}'),
                      Text(
                          'Sede: ${student['sedes']?['name'] ?? 'No asignado'}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => showStudentOptions(context, student),
                  ),
                ),
                Divider(thickness: 1, color: Colors.blue), // Línea divisoria
              ],
            );
          },
        ),
      ),
    );
  }
}
