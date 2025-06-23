import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:refmp/interfaces/instrumentsDetails.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';

class HeadquartersInfo extends StatefulWidget {
  final String id;
  final String name;

  const HeadquartersInfo({
    super.key,
    required this.id,
    required this.name,
  });

  @override
  State<HeadquartersInfo> createState() => _HeadquartersInfoState();
}

class _HeadquartersInfoState extends State<HeadquartersInfo> {
  LatLng? _sedeLocation;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final data = await _fetchSedeData();
    final address = data['address'] ?? '';
    if (address.isNotEmpty) {
      try {
        debugPrint('Processing address: $address');
        final locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          setState(() {
            _sedeLocation =
                LatLng(locations.first.latitude, locations.first.longitude);
            _locationError = null;
          });
          debugPrint(
              'Geocoded location: ${locations.first.latitude}, ${locations.first.longitude}');
        } else {
          setState(() {
            _locationError = 'No se pudo geolocalizar la dirección: $address';
          });
          debugPrint(_locationError!);
        }
      } catch (e) {
        setState(() {
          _locationError = 'Error procesando la ubicación: $e';
        });
        debugPrint(_locationError!);
      }
    } else {
      setState(() {
        _locationError = 'El campo address está vacío o no disponible';
      });
      debugPrint(_locationError!);
    }
  }

  Future<Map<String, dynamic>> _fetchSedeData() async {
    final box = Hive.box('offline_data');
    const cacheKey = 'sedes_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from("sedes")
            .select()
            .eq('id', widget.id)
            .maybeSingle();
        if (response != null) {
          final data = Map<String, dynamic>.from(response);
          final cachedData = box.get(cacheKey, defaultValue: []);
          final updatedData = List<Map<String, dynamic>>.from(cachedData);
          final index =
              updatedData.indexWhere((item) => item['id'] == widget.id);
          if (index != -1) {
            updatedData[index] = data;
          } else {
            updatedData.add(data);
          }
          await box.put(cacheKey, updatedData);
          return data;
        }
      } catch (e) {
        debugPrint('Error fetching sede data from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    final sedeData = List<Map<String, dynamic>>.from(cachedData)
        .firstWhere((item) => item['id'] == widget.id, orElse: () => {});
    return sedeData.isNotEmpty ? sedeData : {'name': widget.name};
  }

  Future<List<Map<String, dynamic>>> _fetchInstruments() async {
    final box = Hive.box('offline_data');
    final cacheKey = 'sede_instruments_${widget.id}';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response =
            await Supabase.instance.client.from('sede_instruments').select('''
              instruments (
                id,
                name,
                image
              )
            ''').eq('sede_id', widget.id);
        final data = List<Map<String, dynamic>>.from(response)
            .map((item) => {
                  'id': item['instruments']['id'] ?? 0, // Default to 0 if null
                  'name':
                      item['instruments']['name'] ?? 'Instrumento desconocido',
                  'image': item['instruments']['image'] ?? '',
                })
            .toList();
        await box.put(cacheKey, data);
        return data;
      } catch (e) {
        debugPrint('Error fetching instruments from Supabase: $e');
      }
    }

    final cachedData = box.get(cacheKey, defaultValue: []);
    return List<Map<String, dynamic>>.from(
        cachedData.map((item) => Map<String, dynamic>.from(item)));
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
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  void _openMap(String address) async {
    final uri = Uri.parse('https://maps.google.com/?q=$address');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el mapa")),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: Colors.blue,
            flexibleSpace: FutureBuilder<Map<String, dynamic>>(
              future: _fetchSedeData(),
              builder: (context, snapshot) {
                final photo = snapshot.data?['photo'] ??
                    'https://via.placeholder.com/150';
                return FlexibleSpaceBar(
                  title: Text(
                    widget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16.0),
                  background: photo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photo,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/refmmp.png',
                          fit: BoxFit.cover,
                        ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchSedeData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.blue));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "No se encontraron datos de la sede",
                      style: TextStyle(color: Colors.blue),
                    ),
                  );
                }

                final data = snapshot.data!;
                // ignore: unused_local_variable
                final name = data['name'] ?? widget.name;
                final typeHeadquarters =
                    data['type_headquarters'] ?? 'No disponible';
                final description = data['description'] ?? 'Sin descripción';
                final address = data['address'] ?? 'Dirección no disponible';
                final contactNumber = data['contact_number'] ?? 'No disponible';

                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de sede:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(typeHeadquarters),
                      const SizedBox(height: 20),
                      const Text(
                        'Descripción:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(description),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openMap(address),
                              child: Text(
                                address,
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_sedeLocation != null) ...[
                        const Text(
                          'Ubicación (Coordenadas):',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Lat: ${_sedeLocation!.latitude}, Long: ${_sedeLocation!.longitude}',
                          style: const TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 20),
                      ] else if (_locationError != null) ...[
                        Text(
                          _locationError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const Text(
                          'Cargando ubicación...',
                          style: TextStyle(color: Colors.blue),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text(
                        'Número de contacto:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(contactNumber),
                      const SizedBox(height: 20),
                      const Text(
                        'Instrumentos:',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchInstruments(),
                        builder: (context, instrumentSnapshot) {
                          if (instrumentSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator(
                                color: Colors.blue);
                          }
                          if (!instrumentSnapshot.hasData ||
                              instrumentSnapshot.data!.isEmpty) {
                            return const Text(
                                'No hay instrumentos disponibles');
                          }

                          return Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children:
                                instrumentSnapshot.data!.map((instrument) {
                              final instrumentName = instrument['name'] ??
                                  'Instrumento desconocido';
                              final instrumentImage = instrument['image'] ?? '';
                              final instrumentId = instrument['id'] as int? ??
                                  0; // Default to 0 if null

                              return GestureDetector(
                                onTap: () {
                                  if (instrumentId != 0) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            InstrumentDetailPage(
                                                instrumentId: instrumentId),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "ID de instrumento no válido")),
                                    );
                                  }
                                },
                                child: Chip(
                                  avatar: instrumentImage.isNotEmpty
                                      ? CircleAvatar(
                                          backgroundImage:
                                              NetworkImage(instrumentImage),
                                          radius: 12,
                                        )
                                      : null,
                                  label: Text(
                                    instrumentName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.blue.shade100,
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 200), // Espacio para scroll
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
