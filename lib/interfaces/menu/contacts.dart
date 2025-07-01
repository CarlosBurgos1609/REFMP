import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

// Custom Cache Manager for CachedNetworkImage
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 100,
    ),
  );
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.title});
  final String title;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchHeadquarters() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'sedes_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase
            .from('sedes')
            .select('id, name, contact_number, address, ubication, photo')
            .order('name', ascending: true);
        final data = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, data);
        for (var sede in data) {
          final imageUrl = sede['photo'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        return data;
      } catch (e) {
        debugPrint('Error fetching sedes: $e');
        final cachedData = box.get(cacheKey, defaultValue: []);
        return List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));
      }
    } else {
      debugPrint('Offline mode: Using cached sedes data');
      final cachedData = box.get(cacheKey, defaultValue: []);
      return List<Map<String, dynamic>>.from(
          cachedData.map((item) => Map<String, dynamic>.from(item)));
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking internet: $e');
      return false;
    }
  }

  String formatPhoneNumber(String number) {
    if (number.length >= 10) {
      return '${number.substring(0, 3)} ${number.substring(3)}';
    }
    return number;
  }

  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Número copiado al portapapeles')),
    );
  }

  void _launchGoogleMaps(String? ubication) async {
    if (ubication == null || ubication.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
      return;
    }
    final uri = Uri.parse(ubication);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
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
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: Colors.blue,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchHeadquarters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    "No hay contactos disponibles",
                    style: TextStyle(color: Colors.blue),
                  ),
                );
              }

              final sedes = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: sedes.length,
                itemBuilder: (context, index) {
                  final sede = sedes[index];
                  final name = sede['name'] ?? 'Nombre no disponible';
                  final contactNumber =
                      sede['contact_number'] ?? 'No disponible';
                  final address = sede['address'] ?? 'Dirección no disponible';
                  final ubication = sede['ubication'] ?? '';
                  final photo =
                      sede['photo'] ?? 'https://via.placeholder.com/150';

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name above image
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        // Image
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: double.infinity,
                              height: 150,
                              child: CachedNetworkImage(
                                imageUrl: photo,
                                cacheManager: CustomCacheManager.instance,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blue),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Contact info below image
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '| Número de contacto',
                                style: TextStyle(color: Colors.blue),
                              ),
                              Row(
                                children: [
                                  const Text("🇨🇴"),
                                  const SizedBox(width: 4),
                                  const Text("+57 "),
                                  Expanded(
                                    child: Text(
                                      formatPhoneNumber(contactNumber),
                                      style: const TextStyle(fontSize: 16),
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
                              const SizedBox(height: 4),
                              Text(
                                '| Dirección',
                                style: TextStyle(color: Colors.blue),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _launchGoogleMaps(ubication),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.blue, size: 20),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.blue,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
