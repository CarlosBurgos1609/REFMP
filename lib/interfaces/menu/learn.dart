import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

// Custom Cache Manager for CachedNetworkImage
class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30), // Cache images for 30 days
      maxNrOfCacheObjects: 100, // Limit number of cached objects
    ),
  );
}

class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.title});
  final String title;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchGames() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'games_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase.from('games').select('*');
        final data = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, data); // Guarda en cache
        // Pre-cache images
        for (var game in data) {
          final imageUrl = game['image'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        return data;
      } catch (e) {
        debugPrint('Error fetching games: $e');
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

  String truncateText(String text, int wordLimit) {
    final words = text.split(' ');
    if (words.length > wordLimit) {
      return '${words.take(wordLimit).join(' ')}...';
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
          centerTitle: true,
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
          child: ListView(children: [
            const SizedBox(height: 10),
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
                              child: game['image']?.isNotEmpty ?? false
                                  ? CachedNetworkImage(
                                      imageUrl: game['image'],
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 180,
                                      placeholder: (context, url) =>
                                          const Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.blue)),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.image_not_supported,
                                              size: 80),
                                    )
                                  : const Icon(Icons.image_not_supported,
                                      size: 80),
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
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LearningPage(
                                              instrumentName: game['name']),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                        Icons.sports_esports_rounded,
                                        color: Colors.white),
                                    label: const Text("Aprende y Juega",
                                        style: TextStyle(color: Colors.white)),
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
          ]),
        ),
      ),
    );
  }
}
