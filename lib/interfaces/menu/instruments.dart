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

class InstrumentsPage extends StatefulWidget {
  const InstrumentsPage({super.key, required this.title});
  final String title;

  @override
  State<InstrumentsPage> createState() => _InstrumentsPageState();
}

class _InstrumentsPageState extends State<InstrumentsPage> {
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

  Future<List<Map<String, dynamic>>> fetchInstruments() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'instruments_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await supabase.from('instruments').select('*');
        final data = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, data); // Guarda en cache
        // Pre-cache images
        for (var instrument in data) {
          final imageUrl = instrument['image'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            await CustomCacheManager.instance.downloadFile(imageUrl);
          }
        }
        return data;
      } catch (e) {
        debugPrint('Error fetching instruments: $e');
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
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  "Aprende y Juega",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
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
                                        cacheManager:
                                            CustomCacheManager.instance,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 180,
                                        placeholder: (context, url) =>
                                            const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.blue)),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                                Icons.image_not_supported,
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
                                            builder: (_) => LearningPage(
                                                instrumentName: game['name']),
                                          ),
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
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "Instrumentos",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
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
                            leading: instrument['image']?.isNotEmpty ?? false
                                ? SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CachedNetworkImage(
                                      imageUrl: instrument['image'],
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(
                                              color: Colors.blue),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.image_not_supported,
                                              size: 40),
                                    ),
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

  Future<void> fetchInstrumentDetails() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'instrument_${widget.instrumentId}';
    final studentsCacheKey = 'students_instrument_${widget.instrumentId}';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final instrumentResponse = await supabase
            .from('instruments')
            .select('*')
            .eq('id', widget.instrumentId)
            .single();
        final studentsResponse = await supabase
            .from('student_instruments')
            .select('students(*)')
            .eq('instrument_id', widget.instrumentId);

        final studentsData = studentsResponse
            .map((e) => e['students'])
            .whereType<Map<String, dynamic>>()
            .toList();

        await box.put(cacheKey, instrumentResponse);
        await box.put(studentsCacheKey, studentsData);

        // Pre-cache images
        if (instrumentResponse['image']?.isNotEmpty ?? false) {
          await CustomCacheManager.instance
              .downloadFile(instrumentResponse['image']);
        }
        for (var student in studentsData) {
          if (student['profile_image']?.isNotEmpty ?? false) {
            await CustomCacheManager.instance
                .downloadFile(student['profile_image']);
          }
        }

        setState(() {
          instrument = instrumentResponse;
          students = studentsData;
        });
      } catch (e) {
        debugPrint('Error fetching instrument details: $e');
        final cachedInstrument = box.get(cacheKey);
        final cachedStudents = box.get(studentsCacheKey, defaultValue: []);
        if (cachedInstrument != null) {
          setState(() {
            instrument = Map<String, dynamic>.from(cachedInstrument);
            students = List<Map<String, dynamic>>.from(
                cachedStudents.map((item) => Map<String, dynamic>.from(item)));
          });
        }
      }
    } else {
      final cachedInstrument = box.get(cacheKey);
      final cachedStudents = box.get(studentsCacheKey, defaultValue: []);
      if (cachedInstrument != null) {
        setState(() {
          instrument = Map<String, dynamic>.from(cachedInstrument);
          students = List<Map<String, dynamic>>.from(
              cachedStudents.map((item) => Map<String, dynamic>.from(item)));
        });
      }
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

  @override
  void initState() {
    super.initState();
    fetchInstrumentDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            instrument?['name'] ?? "Cargando...",
            textAlign: TextAlign.center,
            style: const TextStyle(
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
                      child: instrument?['image']?.isNotEmpty ?? false
                          ? CachedNetworkImage(
                              imageUrl: instrument!['image'],
                              cacheManager: CustomCacheManager.instance,
                              fit: BoxFit.contain,
                              height: 200,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.blue)),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error, size: 200),
                            )
                          : const Icon(Icons.image_not_supported, size: 200),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Descripción",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      instrument?['description'] ?? "Sin descripción",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Estudiantes",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 18),
                      ),
                    ),
                    Column(
                      children: students.map((student) {
                        final firstName = student['first_name'] ?? "Nombre";
                        final lastName =
                            student['last_name'] ?? "No disponible";
                        final email =
                            student['email'] ?? "Correo no disponible";
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: ClipOval(
                              child: student['profile_image']?.isNotEmpty ??
                                      false
                                  ? CachedNetworkImage(
                                      imageUrl: student['profile_image'],
                                      cacheManager: CustomCacheManager.instance,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(
                                              color: Colors.white),
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                              "assets/images/refmmp.png",
                                              fit: BoxFit.cover),
                                    )
                                  : Image.asset("assets/images/refmmp.png",
                                      fit: BoxFit.cover),
                            ),
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
