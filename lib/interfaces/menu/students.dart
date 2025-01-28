import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
// Firebase
import 'package:refmp/services/firebase_services.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.title});
  final String title;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String searchQuery = ""; // Almacena la búsqueda
  List<dynamic> allStudents = [];
  Map<String, List<Map<String, dynamic>>> groupedStudents = {};
  final FirebaseServices _firebaseServices =
      FirebaseServices(); // Instancia de FirebaseServices

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  // Función para obtener estudiantes
  Future<void> fetchStudents() async {
    final students =
        await _firebaseServices.getStudents(); // Llamada a FirebaseServices
    setState(() {
      allStudents = students;
      groupStudentsByInstrument(students);
    });
  }

  void groupStudentsByInstrument(List students) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var student in students) {
      final instrument1 = student['instrument'] ?? "Sin instrumento";
      final instrument2 = student['instrument2'] ?? "";

      // Agrupar por el primer instrumento
      grouped.putIfAbsent(instrument1, () => []).add(student);

      // Si hay un segundo instrumento, agrupar también por este
      if (instrument2.isNotEmpty) {
        grouped.putIfAbsent(instrument2, () => []).add(student);
      }
    }

    // Ordenar las claves alfabéticamente
    final sortedKeys = grouped.keys.toList()..sort();

    setState(() {
      groupedStudents = {for (var key in sortedKeys) key: grouped[key]!};
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            decoration: const InputDecoration(
              hintText: "Buscar estudiantes...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (query) {
              setState(() {
                searchQuery = query.toLowerCase();
              });
            },
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: allStudents.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
            : ListView(
                children: groupedStudents.keys.map((instrument) {
                  // Filtrar estudiantes según la búsqueda
                  final filteredStudents = groupedStudents[instrument]!
                      .where((student) =>
                          student['name']
                              .toString()
                              .toLowerCase()
                              .contains(searchQuery) ||
                          student['last_name']
                              .toString()
                              .toLowerCase()
                              .contains(searchQuery))
                      .toList();

                  // Si no hay estudiantes que coincidan, no mostrar la sección
                  if (filteredStudents.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título del instrumento
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          instrument,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      ...filteredStudents.map((student) {
                        final name = student['name'] ?? "Sin nombre";
                        final lastName = student['last_name'] ?? "Sin apellido";
                        final email = student['email'] ?? "Sin email";
                        final position = student['position'] ?? "Sin posición";

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 3, horizontal: 16),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundImage: AssetImage(
                                  "assets/images/refmmp.png"), // Imagen por defecto
                            ),
                            title: Text(
                              "$name $lastName",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email),
                                Text(
                                  position,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'info') {
                                  // Mostrar información del estudiante
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                          "Información de $name $lastName"),
                                      content: Text(
                                          "Email: $email\nCargo: $position\nInstrumento: $instrument"),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text(
                                            "Cerrar",
                                            style:
                                                TextStyle(color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'info',
                                  child: Text("Más información del estudiante"),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }
}
