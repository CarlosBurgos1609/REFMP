// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:refmp/connections/register_connections.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/forms/studentsform.dart';
import 'package:refmp/theme/theme_provider.dart';
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
  Map<String, List<Map<String, dynamic>>> groupedStudents = {};
  List<String> alphabet =
      List.generate(26, (index) => String.fromCharCode(65 + index));
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> letterKeys = {};
  String? selectedSede;
  String? selectedInstrument;
  List<String> sedes = [];
  List<String> instruments = [];

  @override
  void initState() {
    super.initState();
    fetchStudents();
    _searchController.addListener(() {
      filterStudents(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    final box = await Hive.openBox('offline_data');
    const cacheKey = 'students_data';

    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      final cachedStudents = box.get(cacheKey);
      if (cachedStudents != null) {
        setState(() {
          students = List<Map<String, dynamic>>.from(cachedStudents);
          filteredStudents = List.from(students);
          debugPrint('Loaded ${students.length} students from cache');
          groupStudents();
          fetchFilters();
        });
        return;
      } else {
        debugPrint('No cached data available');
        return;
      }
    }

    try {
      final response = await Supabase.instance.client
          .from('students')
          .select(
              '*, student_instruments!left(instruments!inner(name)), sedes!students_sede_id_fkey!left(name)')
          .order('first_name', ascending: true);

      if (response != null) {
        setState(() {
          students = List<Map<String, dynamic>>.from(response);
          filteredStudents = List.from(students);
          debugPrint('Fetched ${students.length} students from Supabase');
          groupStudents();
          fetchFilters();
        });
        await box.put(cacheKey, response);
      } else {
        debugPrint('Error: No students returned from Supabase');
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
    }
  }

  void fetchFilters() {
    setState(() {
      sedes = students
          .map((student) => student['sedes']?['name'] as String?)
          .where((sede) => sede != null)
          .toSet()
          .toList()
          .cast<String>();

      instruments = students
          .expand((student) {
            final instrumentsList =
                student['student_instruments'] as List<dynamic>?;
            if (instrumentsList == null || instrumentsList.isEmpty) {
              return <String>[];
            }
            return instrumentsList
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['instruments'] != null &&
                    e['instruments']['name'] is String)
                .map((e) => e['instruments']['name'] as String);
          })
          .toSet()
          .toList();
      debugPrint('Sedes: $sedes, Instruments: $instruments');
    });
  }

  void groupStudents() {
    groupedStudents.clear();
    letterKeys.clear();
    for (var letter in alphabet) {
      letterKeys[letter] = GlobalKey();
      final studentsForLetter = filteredStudents.where((student) {
        final firstName = student['first_name'] as String?;
        return firstName != null &&
            firstName.isNotEmpty &&
            firstName.toUpperCase().startsWith(letter);
      }).toList();
      if (studentsForLetter.isNotEmpty) {
        groupedStudents[letter] = studentsForLetter;
      }
    }
    debugPrint('Grouped students: ${groupedStudents.keys.join(', ')}');
  }

  void filterStudents(String query) {
    setState(() {
      filteredStudents = students.where((student) {
        final firstName =
            (student['first_name'] as String?)?.toLowerCase() ?? '';
        final matchesQuery =
            query.isEmpty || firstName.contains(query.toLowerCase());
        final matchesSede =
            selectedSede == null || student['sedes']?['name'] == selectedSede;
        final matchesInstrument = selectedInstrument == null ||
            (student['student_instruments'] as List<dynamic>?)?.any(
                  (e) =>
                      e is Map<String, dynamic> &&
                      e['instruments'] != null &&
                      e['instruments']['name'] == selectedInstrument,
                ) ==
                true;
        return matchesQuery && matchesSede && matchesInstrument;
      }).toList();
      debugPrint(
          'Filtered ${filteredStudents.length} students for query: "$query", sede: $selectedSede, instrument: $selectedInstrument');
      groupStudents();
    });
  }

  Future<void> deleteStudent(int studentId) async {
    await Supabase.instance.client.rpc('delete_student_with_relations_int',
        params: {'p_student_id': studentId});

    fetchStudents();
  }

  void showStudentOptions(BuildContext context, Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title:
                  Text('Más información', style: TextStyle(color: Colors.blue)),
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
              child: Text('Cancelar', style: TextStyle(color: Colors.blue)),
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
            '${student['first_name'] ?? 'Sin nombre'} ${student['last_name'] ?? ''}',
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
                    'Instrumento(s): ${student['student_instruments'] != null && (student['student_instruments'] as List).isNotEmpty ? (student['student_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}',
                    style: TextStyle(height: 2),
                  ),
                  Text(
                    'Sede(s): ${student['sedes']?['name'] ?? 'No asignada'}',
                    style: TextStyle(height: 2),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void showFilterDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color.fromARGB(31, 31, 28, 28).withOpacity(0.9)
        : Colors.white.withOpacity(0.9);
    final textColor = isDarkMode ? Colors.white : Colors.blue;
    final iconColor = textColor;

    String? tempSede = selectedSede;
    String? tempInstrument = selectedInstrument;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Sede',
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.location_on, color: iconColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                dropdownColor: backgroundColor,
                value: tempSede,
                iconEnabledColor: iconColor,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Todas las sedes',
                        style: TextStyle(color: textColor)),
                  ),
                  ...sedes.map((sede) => DropdownMenuItem(
                        value: sede,
                        child: Text(sede, style: TextStyle(color: textColor)),
                      )),
                ],
                onChanged: (value) {
                  tempSede = value;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Instrumento',
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.music_note, color: iconColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                dropdownColor: backgroundColor,
                value: tempInstrument,
                iconEnabledColor: iconColor,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('Todos los instrumentos',
                        style: TextStyle(color: textColor, fontSize: 14)),
                  ),
                  ...instruments.map((instrument) => DropdownMenuItem(
                        value: instrument,
                        child: Text(instrument,
                            style: TextStyle(color: textColor)),
                      )),
                ],
                onChanged: (value) {
                  tempInstrument = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  selectedSede = tempSede;
                  selectedInstrument = tempInstrument;
                  filterStudents(_searchController.text);
                });
                Navigator.pop(context);
              },
              child: Text('Aplicar', style: TextStyle(color: textColor)),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _canAddEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final user = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (user != null) return true;
    return false;
  }

  void scrollToLetter(String letter) {
    final key = letterKeys[letter];
    if (key != null && key.currentContext != null) {
      final RenderBox renderBox =
          key.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero).dy;
      _scrollController.animateTo(
        _scrollController.offset + position - 100,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
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
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list, color: Colors.white),
              onPressed: showFilterDialog,
            ),
          ],
        ),
        floatingActionButton: FutureBuilder<bool>(
          future: _canAddEvent(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox();
            }
            if (snapshot.hasData && snapshot.data == true) {
              return FloatingActionButton(
                backgroundColor: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RegisterStudentForm()),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white),
              );
            } else {
              return const SizedBox();
            }
          },
        ),
        drawer: Menu.buildDrawer(context),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: fetchStudents,
              color: Colors.blue,
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron estudiantes',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: groupedStudents.keys.length,
                      itemBuilder: (context, index) {
                        final letter = groupedStudents.keys.elementAt(index);
                        final studentsForLetter = groupedStudents[letter]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              key: letterKeys[letter],
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ...studentsForLetter.map((student) => Column(
                                  children: [
                                    ListTile(
                                      leading: GestureDetector(
                                        onTap: () =>
                                            showStudentDetails(student),
                                        child: CircleAvatar(
                                          backgroundImage: student[
                                                      'profile_image'] !=
                                                  null
                                              ? NetworkImage(
                                                  student['profile_image'])
                                              : AssetImage(
                                                      'assets/images/refmmp.png')
                                                  as ImageProvider,
                                          radius: 25,
                                        ),
                                      ),
                                      title: GestureDetector(
                                        onTap: () =>
                                            showStudentDetails(student),
                                        child: Text(
                                          '${student['first_name'] ?? 'Sin nombre'} ${student['last_name'] ?? ''}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Instrumentos: ${student['student_instruments'] != null && (student['student_instruments'] as List).isNotEmpty ? (student['student_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}'),
                                          Text(
                                              'Sede: ${student['sedes']?['name'] ?? 'No asignado'}'),
                                        ],
                                      ),
                                      trailing: FutureBuilder<bool>(
                                        future: _canAddEvent(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox();
                                          }
                                          if (snapshot.hasData &&
                                              snapshot.data == true) {
                                            return IconButton(
                                              icon: Icon(Icons.more_vert,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  showStudentOptions(
                                                      context, student),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ),
                                    Divider(
                                      thickness: 1,
                                      height: 10,
                                      color: themeProvider.isDarkMode
                                          ? const Color.fromARGB(
                                              255, 34, 34, 34)
                                          : const Color.fromARGB(
                                              255, 236, 234, 234),
                                    ),
                                  ],
                                )),
                          ],
                        );
                      },
                    ),
            ),
            Positioned(
              right: 8,
              top: 45,
              bottom: 40,
              child: Container(
                width: 30,
                child: ListView.builder(
                  itemCount: alphabet.length,
                  itemBuilder: (context, index) {
                    final letter = alphabet[index];
                    return GestureDetector(
                      onTap: groupedStudents.containsKey(letter)
                          ? () => scrollToLetter(letter)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.2),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: groupedStudents.containsKey(letter)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: groupedStudents.containsKey(letter)
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
