import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
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
                    Text(
                      "Descripción",
                      style: TextStyle(
                        fontSize: 19,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
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
