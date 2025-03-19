import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/games/trumpet.dart';
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

  Future<List<Map<String, dynamic>>> fetchGames() async {
    final response = await supabase.from('games').select('*');
    return response;
  }

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
          child: ListView(
            children: [
              FutureBuilder(
                future: fetchGames(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error al cargar los juegos"));
                  }
                  final games = snapshot.data ?? [];

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      final description = truncateText(
                          game['description'] ?? "Sin descripción", 20);

                      return Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                                child: Image.network(
                                  game['image'] ?? '',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 180,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported,
                                          size: 80),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Text(
                                      game['name'] ?? "Nombre desconocido",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const TrumpetPage()),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.sports_esports_rounded,
                                          color: Colors.white),
                                      label: const Text("Aprende y Juega",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(height: 20, thickness: 2, color: Colors.blue),
              FutureBuilder(
                future: fetchInstruments(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text("Error al cargar los datos"));
                  }
                  final instruments = snapshot.data ?? [];

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                                : const Icon(Icons.image_not_supported,
                                    size: 40),
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
            ],
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
          padding: const EdgeInsets.all(19.0),
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
                          : const Icon(Icons.image_not_supported, size: 200),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Descipción",
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      instrument?['description'] ?? "Sin descripción",
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 20),
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
