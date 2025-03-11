import 'package:flutter/material.dart';
import 'package:refmp/forms/headquartersforms.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class HeadquartersPage extends StatefulWidget {
  const HeadquartersPage({super.key, required this.title});
  final String title;

  @override
  State<HeadquartersPage> createState() => _HeadquartersPageState();
}

class _HeadquartersPageState extends State<HeadquartersPage> {
  Future<List<dynamic>> _fetchData() async {
    // Obtener los datos de Supabase
    final response = await Supabase.instance.client.from("sedes").select();
    return response;
  }

  void _openMap(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el mapa")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: TextStyle(
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
        body: Builder(
          builder: (context) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              color: Colors.blue,
              child: FutureBuilder(
                future: _fetchData(),
                builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                      color: Colors.blue,
                    ));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No hay sedes disponibles",
                          style: TextStyle(color: Colors.blue)),
                    );
                  }

                  // Ordenar alfabéticamente por el campo "name"
                  snapshot.data!.sort(
                      (a, b) => (a["name"] ?? "").compareTo(b["name"] ?? ""));

                  return ListView(
                    children: snapshot.data!.map((doc) {
                      // Asegurar que todos los campos estén presentes
                      final name = doc["name"] ?? "Nombre no disponible";
                      final address =
                          doc["address"] ?? "Dirección no disponible";
                      final description =
                          doc["description"] ?? "Sin descripción";
                      final contactNumber =
                          doc["contact_number"] ?? "No disponible";
                      final ubication = doc["ubication"] ?? "";
                      final photo =
                          doc["photo"] ?? "https://via.placeholder.com/150";

                      return Card(
                        margin: const EdgeInsets.all(10),
                        elevation: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                photo,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(description),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Colors.blue),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _openMap(ubication),
                                          child: Text(
                                            address,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              // decoration:
                                              //     TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone,
                                          color: Colors.blue),
                                      const SizedBox(width: 5),
                                      Text(contactNumber),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blue,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HeadquartersForm()),
            );
          },
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
