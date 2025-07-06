import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:refmp/connections/register_connections.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/edit/edit_teachers.dart';
import 'package:refmp/forms/teacherForm.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key, required this.title});
  final String title;

  @override
  _TeachersPageState createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> filteredTeachers = [];
  Map<String, List<Map<String, dynamic>>> groupedTeachers = {};
  List<String> alphabet =
      List.generate(26, (index) => String.fromCharCode(65 + index));
  final ScrollController _scrollController = ScrollController();
  Map<String, GlobalKey> letterKeys = {};
  String? selectedSede;
  String? selectedInstrument;
  List<String> sedes = [];
  List<String> instruments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing TeachersPage');
    fetchTeachers();
    _searchController.addListener(() {
      filterTeachers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Connectivity result: $connectivityResult');
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      debugPrint('Internet connectivity: $isConnected');
      return isConnected;
    } catch (e) {
      debugPrint('Error checking internet: $e');
      return false;
    }
  }

  Future<void> fetchTeachers() async {
    setState(() {
      _isLoading = true;
    });

    final box = await Hive.openBox('offline_data');
    const cacheKey = 'teachers_data';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      try {
        final response =
            await Supabase.instance.client.from('teachers').select('''
            id, first_name, last_name, email, identification_number, profile_image,
            image_presentation, description,
            teacher_instruments!left(instruments(id, name)),
            teacher_headquarters!left(sedes(id, name))
          ''').order('first_name', ascending: true);

        debugPrint('Supabase response: $response');

        if (response.isEmpty) {
          debugPrint('No teachers found in Supabase');
        } else {
          debugPrint('Fetched ${response.length} teachers from Supabase');
        }

        final data = List<Map<String, dynamic>>.from(response);
        setState(() {
          teachers = data;
          filteredTeachers = List.from(teachers);
          groupTeachers();
          fetchFilters();
          _isLoading = false;
        });
        await box.put(cacheKey, data);
      } catch (e) {
        debugPrint('Error fetching teachers from Supabase: $e');
        final cachedData = box.get(cacheKey, defaultValue: []);
        setState(() {
          teachers = List<Map<String, dynamic>>.from(
              cachedData.map((item) => Map<String, dynamic>.from(item)));
          filteredTeachers = List.from(teachers);
          debugPrint('Loaded ${teachers.length} teachers from cache');
          groupTeachers();
          fetchFilters();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar profesores: $e')),
        );
      }
    } else {
      final cachedData = box.get(cacheKey, defaultValue: []);
      setState(() {
        teachers = List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));
        filteredTeachers = List.from(teachers);
        debugPrint('Loaded ${teachers.length} teachers from cache (offline)');
        groupTeachers();
        fetchFilters();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Modo offline: datos cargados desde caché')),
      );
    }
  }

  void fetchFilters() {
    setState(() {
      sedes = teachers
          .expand((teacher) {
            final sedesList = teacher['teacher_headquarters'] as List<dynamic>?;
            if (sedesList == null || sedesList.isEmpty) {
              return <String>[];
            }
            return sedesList
                .where((e) =>
                    e is Map<String, dynamic> &&
                    e['sedes'] != null &&
                    e['sedes']['name'] is String)
                .map((e) => e['sedes']['name'] as String);
          })
          .toSet()
          .toList();
      instruments = teachers
          .expand((teacher) {
            final instrumentsList =
                teacher['teacher_instruments'] as List<dynamic>?;
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
      debugPrint('Available sedes: $sedes, instruments: $instruments');
    });
  }

  void groupTeachers() {
    groupedTeachers.clear();
    letterKeys.clear();
    for (var letter in alphabet) {
      letterKeys[letter] = GlobalKey();
      final teachersForLetter = filteredTeachers.where((teacher) {
        final firstName = teacher['first_name'] as String?;
        return firstName != null &&
            firstName.isNotEmpty &&
            firstName.toUpperCase().startsWith(letter);
      }).toList();
      if (teachersForLetter.isNotEmpty) {
        groupedTeachers[letter] = teachersForLetter;
      }
    }
    debugPrint('Grouped teachers: ${groupedTeachers.keys.join(', ')}');
  }

  void filterTeachers(String query) {
    setState(() {
      filteredTeachers = teachers.where((teacher) {
        final firstName =
            (teacher['first_name'] as String?)?.toLowerCase() ?? '';
        final matchesQuery =
            query.isEmpty || firstName.contains(query.toLowerCase());
        final matchesSede = selectedSede == null ||
            (teacher['teacher_headquarters'] as List<dynamic>?)?.any(
                  (e) =>
                      e is Map<String, dynamic> &&
                      e['sedes'] != null &&
                      e['sedes']['name'] == selectedSede,
                ) ==
                true;
        final matchesInstrument = selectedInstrument == null ||
            (teacher['teacher_instruments'] as List<dynamic>?)?.any(
                  (e) =>
                      e is Map<String, dynamic> &&
                      e['instruments'] != null &&
                      e['instruments']['name'] == selectedInstrument,
                ) ==
                true;
        return matchesQuery && matchesSede && matchesInstrument;
      }).toList();
      debugPrint(
          'Filtered ${filteredTeachers.length} teachers for query: "$query", sede: $selectedSede, instrument: $selectedInstrument');
      groupTeachers();
    });
  }

  Future<void> deleteTeacher(int teacherId) async {
    try {
      await Supabase.instance.client
          .from('teachers')
          .delete()
          .eq('id', teacherId);
      await fetchTeachers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profesor eliminado con éxito')),
      );
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar profesor: $e')),
      );
    }
  }

  void showTeacherOptions(BuildContext context, Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info_rounded, color: Colors.blue),
              title: const Text('Más información',
                  style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                showTeacherDetails(teacher);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Editar profesor',
                  style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTeacherScreen(teacher: teacher),
                  ),
                ).then((_) => fetchTeachers()); // Refresh after editing
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Eliminar profesor',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDeleteConfirmation(teacher['id']);
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteConfirmation(int teacherId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text(
              '¿Estás seguro de que deseas eliminar a este profesor?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                deleteTeacher(teacherId);
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

  void showTeacherDetails(Map<String, dynamic> teacher) {
    final sedesList = teacher['teacher_headquarters'] as List<dynamic>?;
    final sedesNames = sedesList != null && sedesList.isNotEmpty
        ? sedesList
            .where((e) =>
                e is Map<String, dynamic> &&
                e['sedes'] != null &&
                e['sedes']['name'] is String)
            .map((e) => e['sedes']['name'] as String)
            .join(', ')
        : 'No asignada';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${teacher['first_name'] ?? 'Sin nombre'} ${teacher['last_name'] ?? ''}',
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
                child: teacher['profile_image'] != null &&
                        teacher['profile_image'].isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: teacher['profile_image'],
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
                    'Instrumento(s): ${teacher['teacher_instruments'] != null && (teacher['teacher_instruments'] as List).isNotEmpty ? (teacher['teacher_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}',
                    style: const TextStyle(height: 2),
                  ),
                  Text(
                    'Sede(s): $sedesNames',
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
                    child: Text('Todas las sedes',
                        style: TextStyle(color: Colors.blue)),
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
                    child: Text('Todos los instrumentos',
                        style: TextStyle(color: Colors.blue, fontSize: 13)),
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
                  filterTeachers(_searchController.text);
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

  Future<bool> _canAddTeacher() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user logged in');
      return false;
    }

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
          debugPrint('User has permission to add/edit');
          return true;
        } else {
          await box.put('can_add_event_$userId', false);
          debugPrint('User does not have permission');
          return false;
        }
      } catch (e) {
        debugPrint('Error checking permissions: $e');
        return box.get('can_add_event_$userId', defaultValue: false);
      }
    } else {
      debugPrint('Offline mode: checking cached permission');
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
              hintText: 'Buscar profesor...',
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
          future: _canAddTeacher(),
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
                        builder: (context) => RegisterTeacherForm()),
                  ).then((_) => fetchTeachers()); // Refresh after adding
                },
                child: const Icon(Icons.add, color: Colors.white),
              );
            } else {
              return const SizedBox();
            }
          },
        ),
        drawer: Menu.buildDrawer(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: fetchTeachers,
                    color: Colors.blue,
                    child: filteredTeachers.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron profesores',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: groupedTeachers.keys.length,
                            itemBuilder: (context, index) {
                              final letter =
                                  groupedTeachers.keys.elementAt(index);
                              final teachersForLetter =
                                  groupedTeachers[letter]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    key: letterKeys[letter],
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      letter,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  ...teachersForLetter.map((teacher) => Column(
                                        children: [
                                          ListTile(
                                            leading: GestureDetector(
                                              onTap: () =>
                                                  showTeacherDetails(teacher),
                                              child: CircleAvatar(
                                                radius: 25,
                                                child: ClipOval(
                                                  child: teacher['profile_image'] !=
                                                              null &&
                                                          teacher['profile_image']
                                                              .isNotEmpty
                                                      ? CachedNetworkImage(
                                                          imageUrl: teacher[
                                                              'profile_image'],
                                                          width: 50,
                                                          height: 50,
                                                          fit: BoxFit.cover,
                                                          placeholder: (context,
                                                                  url) =>
                                                              const CircularProgressIndicator(
                                                                  color: Colors
                                                                      .blue),
                                                          errorWidget: (context,
                                                                  url, error) =>
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
                                                  showTeacherDetails(teacher),
                                              child: Text(
                                                '${teacher['first_name'] ?? 'Sin nombre'} ${teacher['last_name'] ?? ''}',
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
                                                  'Instrumentos: ${teacher['teacher_instruments'] != null && (teacher['teacher_instruments'] as List).isNotEmpty ? (teacher['teacher_instruments'] as List).map((e) => e['instruments']?['name'] ?? 'No asignado').join(', ') : 'No asignados'}',
                                                ),
                                                Text(
                                                  'Sede(s): ${(teacher['teacher_headquarters'] as List<dynamic>?)?.isNotEmpty == true ? (teacher['teacher_headquarters'] as List<dynamic>).map((e) => e['sedes']?['name'] ?? 'No asignado').join(', ') : 'No asignado'}',
                                                ),
                                              ],
                                            ),
                                            trailing: FutureBuilder<bool>(
                                              future: _canAddTeacher(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const SizedBox();
                                                }
                                                if (snapshot.hasData &&
                                                    snapshot.data == true) {
                                                  return IconButton(
                                                    icon: const Icon(
                                                        Icons.more_vert,
                                                        color: Colors.blue),
                                                    onPressed: () =>
                                                        showTeacherOptions(
                                                            context, teacher),
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
                            onTap: groupedTeachers.containsKey(letter)
                                ? () => scrollToLetter(letter)
                                : null,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2.2),
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      groupedTeachers.containsKey(letter)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: groupedTeachers.containsKey(letter)
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
