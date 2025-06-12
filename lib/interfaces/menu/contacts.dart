import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.title});
  final String title;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<List<dynamic>> _fetchHeadquarters() async {
    final box = Hive.box('offline_data');

    if (await isOnline()) {
      try {
        final response = await Supabase.instance.client.from('sedes').select();
        await box.put('sedes', response); // Cachear
        return response;
      } catch (e) {
        debugPrint('Error obteniendo sedes online, usando cache: $e');
        return box.get('sedes', defaultValue: []);
      }
    } else {
      debugPrint('Sin conexión, usando sedes en cache');
      return box.get('sedes', defaultValue: []);
    }
  }

  void _showHeadquarterDetails(BuildContext context, Map sede) {
    showDialog(
      context: context,
      builder: (_) {
        final name = sede["name"] ?? "Nombre no disponible";
        final address = sede["address"] ?? "Dirección no disponible";
        final description = sede["description"] ?? "Sin descripción";
        final contactNumber = sede["contact_number"] ?? "No disponible";
        final photo = sede["photo"] ?? "https://via.placeholder.com/150";

        return AlertDialog(
          contentPadding: const EdgeInsets.all(10),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(photo, height: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              Text(name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
              const SizedBox(height: 5),
              Text(description),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 5),
                  Expanded(child: Text(address)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 5),
                  Text(contactNumber),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                "Cerrar",
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
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
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: FutureBuilder(
          future: _fetchHeadquarters(),
          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.blue));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  "No hay contactos disponibles",
                  style: TextStyle(color: Colors.blue),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final sede = snapshot.data![index];
                final name = sede["name"] ?? "Nombre no disponible";
                final contact = sede["contact_number"] ?? "No disponible";

                return GestureDetector(
                  onTap: () => _showHeadquarterDetails(context, sede),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city,
                            color: Colors.white, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(contact,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
