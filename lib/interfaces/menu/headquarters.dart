import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refmp/connections/register_connections.dart';
import 'package:refmp/forms/headquartersforms.dart';
import 'package:refmp/details/headquartersInfo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class HeadquartersPage extends StatefulWidget {
  const HeadquartersPage({super.key, required this.title});
  final String title;

  @override
  State<HeadquartersPage> createState() => _HeadquartersPageState();
}

class _HeadquartersPageState extends State<HeadquartersPage> {
  Future<List<Map<String, dynamic>>> _fetchData() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'sedes_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from("sedes")
            .select()
            .order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, data); // Guarda todos los campos en cache
        return data;
      } catch (e) {
        debugPrint('Error fetching data from Supabase: $e');
        final cachedData = box.get(cacheKey, defaultValue: []);
        return List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));
      }
    } else {
      final cachedData = box.get(cacheKey, defaultValue: []);
      return List<Map<String, dynamic>>.from(
          cachedData.map((item) => Map<String, dynamic>.from(item)));
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Conectividad: $connectivityResult');
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  void _openMap(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el mapa")),
      );
    }
  }

  Future<bool> _canViewHeadquarters() async {
    final box = Hive.box('offline_data');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final user = await supabase
            .from('users')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (user != null) {
          await box.put('can_view_headquarters_$userId', true);
          return true;
        } else {
          await box.put('can_view_headquarters_$userId', false);
          return false;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return box.get('can_view_headquarters_$userId', defaultValue: false);
      }
    } else {
      return box.get('can_view_headquarters_$userId', defaultValue: false);
    }
  }

  String truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length > wordLimit) {
      return '${words.take(wordLimit).join(' ')}...';
    }
    return text;
  }

  String formatPhoneNumber(String number) {
    if (number.length >= 10) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

// Función para copiar el número al portapapeles
  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número copiado al portapapeles')),
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
          centerTitle: true,
        ),
        floatingActionButton: FutureBuilder<bool>(
          future: Future.wait([_canViewHeadquarters(), _checkConnectivity()])
              .then((results) => results[0] && results[1]),
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
                    MaterialPageRoute(builder: (context) => HeadquartersForm()),
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
        body: Builder(
          builder: (context) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              color: Colors.blue,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.blue));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No hay sedes disponibles",
                          style: TextStyle(color: Colors.blue)),
                    );
                  }

                  snapshot.data!.sort(
                      (a, b) => (a["name"] ?? "").compareTo(b["name"] ?? ""));

                  return ListView(
                    children: snapshot.data!.map((doc) {
                      final id = doc["id"]?.toString() ?? "";
                      final name = doc["name"] ?? "Nombre no disponible";
                      final address =
                          doc["address"] ?? "Dirección no disponible";
                      final description = truncateText(
                          doc["description"] ?? "Sin descripción", 16);
                      final contactNumber =
                          doc["contact_number"] ?? "No disponible";
                      final ubication = doc["ubication"] ?? "";
                      final photo =
                          doc["photo"] ?? "https://via.placeholder.com/150";

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HeadquartersInfo(
                                id: id,
                                name: name,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.all(10),
                          elevation: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 200,
                                  child: photo.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: photo,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Center(
                                            child: CircularProgressIndicator(
                                                color: Colors.blue),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Image.asset(
                                            'assets/images/refmmp.png',
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/refmmp.png',
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
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
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor: Colors.blue,
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
                                        const Text("🇨🇴",
                                            style: TextStyle(
                                                fontSize:
                                                    13)), // Bandera de Colombia
                                        const SizedBox(width: 4),
                                        const Text("+57 ",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black)),
                                        Expanded(
                                          child: Text(
                                            formatPhoneNumber(contactNumber),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.black),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy,
                                              size: 20, color: Colors.blue),
                                          onPressed: () =>
                                              _copyPhoneNumber(contactNumber),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
