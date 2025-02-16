import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstrumentsPage extends StatefulWidget {
  const InstrumentsPage({super.key, required this.title});
  final String title;

  @override
  State<InstrumentsPage> createState() => _InstrumentsPageState();
}

class _InstrumentsPageState extends State<InstrumentsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchInstruments() async {
    final response = await supabase.from('instruments').select('*');
    return response;
  }

  Future<List<Map<String, dynamic>>> fetchStudents(int instrumentId) async {
    final response = await supabase
        .from('student_instruments')
        .select('students(*)')
        .eq('instrument_id', instrumentId);
    return response
        .map((e) => e['students'])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: FutureBuilder(
            future: fetchInstruments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                );
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Error al cargar los datos"));
              }
              final instruments = snapshot.data ?? [];

              return ListView.builder(
                itemCount: instruments.length,
                itemBuilder: (context, index) {
                  final instrument = instruments[index];
                  final description =
                      instrument['description'] ?? "Sin descripción";
                  final shortDescription = description.split(' ').length > 6
                      ? description.split(' ').take(6).join(' ') + '...'
                      : description;

                  return Container(
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: instrument['image'] != null
                              ? SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: Image.network(instrument['image'],
                                      fit: BoxFit.contain),
                                )
                              : const Icon(Icons.image_not_supported, size: 40),
                          title: Text(
                            instrument['name'] ?? "Nombre desconocido",
                            style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          subtitle: Text(shortDescription,
                              style: const TextStyle(fontSize: 16)),
                          trailing: IconButton(
                            icon: const Icon(Icons.info, size: 28),
                            color: Colors.blue,
                            onPressed: () async {
                              final students =
                                  await fetchStudents(instrument['id'] ?? 0);
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return SingleChildScrollView(
                                    child: AlertDialog(
                                      title: Text(
                                        instrument['name'] ??
                                            "Nombre desconocido",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          instrument['image'] != null
                                              ? Image.network(
                                                  instrument['image'],
                                                  fit: BoxFit.contain)
                                              : const Icon(
                                                  Icons.image_not_supported,
                                                  size: 40),
                                          const SizedBox(height: 8),
                                          Text(description,
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          const SizedBox(height: 16),
                                          const Text("Estudiantes",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                  fontSize: 18)),
                                          Column(
                                            children: students.map((student) {
                                              final firstName =
                                                  student['first_name'] ??
                                                      "Nombre";
                                              final lastName =
                                                  student['last_name'] ??
                                                      "no disponible";
                                              final email = student['email'] ??
                                                  "Correo no disponible";
                                              return ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor: Colors.blue,
                                                  backgroundImage: student[
                                                                  'profile_image'] !=
                                                              null &&
                                                          student[
                                                                  'profile_image']
                                                              .isNotEmpty
                                                      ? NetworkImage(student[
                                                              'profile_image'])
                                                          as ImageProvider
                                                      : const AssetImage(
                                                          "assets/images/refmmp.png"),
                                                ),
                                                title: Text(
                                                    '$firstName $lastName',
                                                    style: const TextStyle(
                                                        fontSize: 16)),
                                                subtitle: Text(email,
                                                    style: const TextStyle(
                                                        fontSize: 14)),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
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
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
