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

  String truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length > wordLimit) {
      return words.take(wordLimit).join(' ') + '...';
    }
    return text;
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
          color: Colors.blue,
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
                  final description = truncateText(
                      instrument['description'] ?? "Sin descripción", 9);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstrumentDetailPage(
                              instrumentId: instrument['id']),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      padding: const EdgeInsets.all(16),
                      child: ListTile(
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
                        subtitle: Text(description,
                            style: const TextStyle(fontSize: 16)),
                      ),
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

class InstrumentDetailPage extends StatefulWidget {
  final int instrumentId;
  const InstrumentDetailPage({super.key, required this.instrumentId});

  @override
  State<InstrumentDetailPage> createState() => _InstrumentDetailPageState();
}

class _InstrumentDetailPageState extends State<InstrumentDetailPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? instrument;
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    fetchInstrumentDetails();
  }

  Future<void> fetchInstrumentDetails() async {
    final instrumentResponse = await supabase
        .from('instruments')
        .select('*')
        .eq('id', widget.instrumentId)
        .single();
    final studentsResponse = await supabase
        .from('student_instruments')
        .select('students(*)')
        .eq('instrument_id', widget.instrumentId);

    setState(() {
      instrument = instrumentResponse;
      students = studentsResponse
          .map((e) => e['students'])
          .whereType<Map<String, dynamic>>()
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            instrument?['name'] ?? "Cargando...",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: instrument == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: instrument?['image'] != null
                          ? Image.network(instrument!['image'],
                              fit: BoxFit.contain)
                          : const Icon(Icons.image_not_supported, size: 100),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      instrument?['description'] ?? "Sin descripción",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        "Estudiantes",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Column(
                      children: students.map((student) {
                        final firstName = student['first_name'] ?? "Nombre";
                        final lastName =
                            student['last_name'] ?? "no disponible";
                        final email =
                            student['email'] ?? "Correo no disponible";
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            backgroundImage: student['profile_image'] != null &&
                                    student['profile_image'].isNotEmpty
                                ? NetworkImage(student['profile_image'])
                                    as ImageProvider
                                : const AssetImage("assets/images/refmmp.png"),
                          ),
                          title: Text('$firstName $lastName',
                              style: const TextStyle(fontSize: 16)),
                          subtitle:
                              Text(email, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
