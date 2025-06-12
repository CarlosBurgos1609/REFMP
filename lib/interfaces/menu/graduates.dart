// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart'; // Agregar esta importación
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:refmp/connections/register_connections.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/forms/graduatesForm.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GraduatesPage extends StatefulWidget {
  const GraduatesPage({super.key, required this.title});
  final String title;

  @override
  _GraduatesPageState createState() => _GraduatesPageState();
}

class _GraduatesPageState extends State<GraduatesPage> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  File? profileImage;

  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> graduates = [];
  List<Map<String, dynamic>> filteredGraduates = [];
  Map<String, List<Map<String, dynamic>>> groupedGraduates = {};
  List<String> alphabet =
      List.generate(26, (index) => String.fromCharCode(65 + index));
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> letterKeys = {};
  String? selectedSede;
  String? selectedInstrument;
  List<String> sedes = [];
  List<String> instruments = [];

  @override
  void initState() {
    super.initState();
    fetchGraduates();
    _searchController.addListener(() {
      filterGraduates(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName =
          'graduates/profile_${DateTime.now().millisecondsSinceEpoch}.png';
      await Supabase.instance.client.storage
          .from('graduates')
          .upload(fileName, imageFile);
      return Supabase.instance.client.storage
          .from('graduates')
          .getPublicUrl(fileName);
    } catch (error) {
      debugPrint('Error al subir la imagen: $error');
      return null;
    }
  }

  Future<void> addGraduate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    String? imageUrl;
    if (profileImage != null) {
      imageUrl = await uploadImage(profileImage!);
    }
    await Supabase.instance.client.from('graduates').insert({
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'email': _emailController.text,
      'identification_number': _idNumberController.text,
      'password': _passwordController.text,
      'profile_image': imageUrl,
    });
    Navigator.pop(context);
  }

  Future<void> fetchGraduates() async {
    final box = await Hive.openBox('offline_data');
    const cacheKey = 'graduates_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from('graduates')
            .select(
                '*, graduate_instruments!left(instruments!inner(name)), sedes!graduates_sede_id_fkey!left(name)')
            .order('first_name', ascending: true);

        if (response != null) {
          final data = List<Map<String, dynamic>>.from(response);
          setState(() {
            graduates = data;
            filteredGraduates = List.from(graduates);
            debugPrint('Fetched ${graduates.length} graduates from Supabase');
            groupGraduates();
            fetchFilters();
          });
          await box.put(cacheKey, data); // Guarda en caché
        } else {
          debugPrint('Error: No graduates returned from Supabase');
        }
      } catch (e) {
        debugPrint('Error fetching graduates from Supabase: $e');
        final cachedData = box.get(cacheKey, defaultValue: []);
        setState(() {
          graduates = List<Map<String, dynamic>>.from(
              cachedData.map((item) => Map<String, dynamic>.from(item)));
          filteredGraduates = List.from(graduates);
          debugPrint('Loaded ${graduates.length} graduates from cache');
          groupGraduates();
          fetchFilters();
        });
      }
    } else {
      final cachedData = box.get(cacheKey, defaultValue: []);
      setState(() {
        graduates = List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));
        filteredGraduates = List.from(graduates);
        debugPrint('Loaded ${graduates.length} graduates from cache');
        groupGraduates();
        fetchFilters();
      });
    }
  }

  void fetchFilters() {
    setState(() {
      sedes = graduates
          .map((graduate) => graduate['sedes']?['name'] as String?)
          .where((sede) => sede != null)
          .toSet()
          .toList()
          .cast<String>();

      instruments = graduates
          .expand((graduate) {
            final instrumentsList =
                graduate['graduate_instruments'] as List<dynamic>?;
            if (instrumentsList == null || instrumentsList.isEmpty) {
              return <String>[];
            }
            return instrumentsList
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['instruments'] != null &&
                    e['instruments']['name'] is String)
                .map((e) => e['instruments']['name'] as String);
          })
          .toSet()
          .toList();
      debugPrint('Sedes: $sedes, Instruments: $instruments');
    });
  }

  void groupGraduates() {
    groupedGraduates.clear();
    letterKeys.clear();
    for (var letter in alphabet) {
      letterKeys[letter] = GlobalKey();
      final graduatesForLetter = filteredGraduates.where((graduate) {
        final firstName = graduate['first_name'] as String?;
        return firstName != null &&
            firstName.isNotEmpty &&
            firstName.toUpperCase().startsWith(letter);
      }).toList();
      if (graduatesForLetter.isNotEmpty) {
        groupedGraduates[letter] = graduatesForLetter;
      }
    }
    debugPrint('Grouped graduates: ${groupedGraduates.keys.join(', ')}');
  }

  void filterGraduates(String query) {
    setState(() {
      filteredGraduates = graduates.where((graduate) {
        final firstName =
            (graduate['first_name'] as String?)?.toLowerCase() ?? '';
        final matchesQuery =
            query.isEmpty || firstName.contains(query.toLowerCase());
        final matchesSede =
            selectedSede == null || graduate['sedes']?['name'] == selectedSede;
        final matchesInstrument = selectedInstrument == null ||
            (graduate['graduate_instruments'] as List<dynamic>?)?.any(
                  (e) =>
                      e is Map<String, dynamic> &&
                      e['instruments'] != null &&
                      e['instruments']['name'] == selectedInstrument,
                ) ==
                true;
        return matchesQuery && matchesSede && matchesInstrument;
      }).toList();
      debugPrint(
          'Filtered ${filteredGraduates.length} graduates for query: "$query", sede: $selectedSede, instrument: $selectedInstrument');
      groupGraduates();
    });
  }

  Future<void> deleteGraduate(int graduateId) async {
    try {
      await Supabase.instance.client
          .from('graduates')
          .delete()
          .eq('id', graduateId);
      await fetchGraduates();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Egresado eliminado con éxito')),
      );
    } catch (e) {
      debugPrint('Error deleting graduate: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar egresado: $e')),
      );
    }
  }

  void showGraduateOptions(
      BuildContext context, Map<String, dynamic> graduate) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('Más información',
                  style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                showGraduateDetails(graduate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar egresado',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDeleteConfirmation(graduate['id']);
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteConfirmation(int graduateId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text(
              '¿Estás seguro de que deseas eliminar a este egresado?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                deleteGraduate(graduateId);
                Navigator.pop(context);
              },
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void showGraduateDetails(Map<String, dynamic> graduate) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${graduate['first_name'] ?? 'Sin nombre'} ${graduate['last_name'] ?? ''}',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: graduate['profile_image'] != null &&
                        graduate['profile_image'].isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: graduate['profile_image'],
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(color: Colors.blue),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/images/refmmp.png',
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/images/refmmp.png',
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrumento(s): ${graduate['graduate_instruments'] != null && (graduate['graduate_instruments'] as List).isNotEmpty ? (graduate['graduate_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}',
                    style: const TextStyle(height: 2),
                  ),
                  Text(
                    'Sede(s): ${graduate['sedes']?['name'] ?? 'No asignada'}',
                    style: const TextStyle(height: 2),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void showFilterDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color.fromARGB(31, 31, 28, 28).withOpacity(0.8)
        : Colors.white.withOpacity(0.9);
    final textColor = isDarkMode ? Colors.white : Colors.blue;
    final iconColor = textColor;

    String? tempSede = selectedSede;
    String? tempInstrument = selectedInstrument;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Sede',
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.location_on, color: iconColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                dropdownColor: backgroundColor,
                value: tempSede,
                iconEnabledColor: iconColor,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas', style: TextStyle(color: Colors.blue)),
                  ),
                  ...sedes.map((sede) => DropdownMenuItem(
                        value: sede,
                        child: Text(sede, style: TextStyle(color: textColor)),
                      )),
                ],
                onChanged: (value) {
                  tempSede = value;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Instrumento',
                  labelStyle: TextStyle(color: textColor),
                  prefixIcon: Icon(Icons.music_note, color: iconColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
                dropdownColor: backgroundColor,
                value: tempInstrument,
                iconEnabledColor: iconColor,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todos', style: TextStyle(color: Colors.blue)),
                  ),
                  ...instruments.map((instrument) => DropdownMenuItem(
                        value: instrument,
                        child: Text(instrument,
                            style: TextStyle(color: textColor)),
                      )),
                ],
                onChanged: (value) {
                  tempInstrument = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  selectedSede = tempSede;
                  selectedInstrument = tempInstrument;
                  filterGraduates(_searchController.text);
                });
                Navigator.pop(context);
              },
              child:
                  const Text('Aplicar', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _canAddEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final box = Hive.box('offline_data');
    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final user = await supabase
            .from('users')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (user != null) {
          await box.put('can_add_event_$userId', true);
          return true;
        } else {
          await box.put('can_add_event_$userId', false);
          return false;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return box.get('can_add_event_$userId', defaultValue: false);
      }
    } else {
      return box.get('can_add_event_$userId', defaultValue: false);
    }
  }

  void scrollToLetter(String letter) {
    final key = letterKeys[letter];
    if (key != null && key.currentContext != null) {
      final RenderBox renderBox =
          key.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero).dy;
      _scrollController.animateTo(
        _scrollController.offset + position - 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          title: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar egresado...',
              hintStyle: TextStyle(color: Colors.white),
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Colors.white),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: showFilterDialog,
            ),
          ],
        ),
        floatingActionButton: FutureBuilder<bool>(
          future: _canAddEvent(),
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
                    MaterialPageRoute(
                        builder: (context) => RegisterGraduateForm()),
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
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: fetchGraduates,
              color: Colors.blue,
              child: filteredGraduates.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron egresados',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: groupedGraduates.keys.length,
                      itemBuilder: (context, index) {
                        final letter = groupedGraduates.keys.elementAt(index);
                        final graduatesForLetter = groupedGraduates[letter]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              key: letterKeys[letter],
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ...graduatesForLetter.map((graduate) => Column(
                                  children: [
                                    ListTile(
                                      leading: GestureDetector(
                                        onTap: () =>
                                            showGraduateDetails(graduate),
                                        child: CircleAvatar(
                                          radius: 25,
                                          child: ClipOval(
                                            child: graduate['profile_image'] !=
                                                        null &&
                                                    graduate['profile_image']
                                                        .isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: graduate[
                                                        'profile_image'],
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context,
                                                            url) =>
                                                        const CircularProgressIndicator(
                                                            color: Colors.blue),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/images/refmmp.png',
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Image.asset(
                                                    'assets/images/refmmp.png',
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      title: GestureDetector(
                                        onTap: () =>
                                            showGraduateDetails(graduate),
                                        child: Text(
                                          '${graduate['first_name'] ?? 'Sin nombre'} ${graduate['last_name'] ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Instrumentos: ${graduate['graduate_instruments'] != null && (graduate['graduate_instruments'] as List).isNotEmpty ? (graduate['graduate_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}'),
                                          Text(
                                              'Sede: ${graduate['sedes']?['name'] ?? 'No asignado'}'),
                                        ],
                                      ),
                                      trailing: FutureBuilder<bool>(
                                        future: _canAddEvent(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const SizedBox();
                                          }
                                          if (snapshot.hasData &&
                                              snapshot.data == true) {
                                            return IconButton(
                                              icon: const Icon(Icons.more_vert,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  showGraduateOptions(
                                                      context, graduate),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ),
                                    Divider(
                                      thickness: 1,
                                      height: 10,
                                      color: themeProvider.isDarkMode
                                          ? const Color.fromARGB(
                                              255, 34, 34, 34)
                                          : const Color.fromARGB(
                                              255, 236, 234, 234),
                                    ),
                                  ],
                                )),
                          ],
                        );
                      },
                    ),
            ),
            Positioned(
              right: 8,
              top: 45,
              bottom: 40,
              child: Container(
                width: 30,
                child: ListView.builder(
                  itemCount: alphabet.length,
                  itemBuilder: (context, index) {
                    final letter = alphabet[index];
                    return GestureDetector(
                      onTap: groupedGraduates.containsKey(letter)
                          ? () => scrollToLetter(letter)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.2),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: groupedGraduates.containsKey(letter)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: groupedGraduates.containsKey(letter)
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
