// import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
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

  List<Map<String, dynamic>> graduates = [];
  List<Map<String, dynamic>> filteredGraduates = [];

  @override
  void initState() {
    super.initState();
    fetchGraduates();
  }

  Future<void> fetchGraduates() async {
    final response = await Supabase.instance.client
        .from('graduates')
        .select(
            '*, graduate_instruments(instruments(name)), sedes!graduates_sede_id_fkey(name)')
        .order('first_name', ascending: true);

    setState(() {
      graduates = List<Map<String, dynamic>>.from(response);
      filteredGraduates = graduates;
    });
  }

  void filterGraduates(String query) {
    setState(() {
      filteredGraduates = graduates.where((graduate) {
        final firstName = graduate['first_name'].toLowerCase();
        return firstName.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> deleteGraduate(int graduateId) async {
    await Supabase.instance.client
        .from('graduates')
        .delete()
        .eq('id', graduateId);
    fetchGraduates();
  }

  void showGraduateOptions(
      BuildContext context, Map<String, dynamic> graduate) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.info, color: Colors.blue),
              title:
                  Text('Más información', style: TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                showGraduateDetails(graduate);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Eliminar egresado',
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
          title: Text('Eliminar egresado'),
          content:
              Text('¿Estás seguro de que deseas eliminar a este egresado?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar')),
            TextButton(
              onPressed: () {
                deleteGraduate(graduateId);
                Navigator.pop(context);
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
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
            '${graduate['first_name']} ${graduate['last_name']}',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(500),
                child: graduate['profile_image'] != null &&
                        graduate['profile_image'].isNotEmpty
                    ? Image.network(graduate['profile_image'],
                        height: 150, width: 150, fit: BoxFit.cover)
                    : Image.asset('assets/images/refmmp.png', height: 100),
              ),
              SizedBox(height: 40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(graduate['email'],
                      style: TextStyle(color: Colors.blue, height: 2)),
                  Text(
                    'Instrumento(s): ${graduate['graduate_instruments'] != null && graduate['graduate_instruments'].isNotEmpty ? graduate['graduate_instruments'].map((e) => e['instruments']['name']).join(', ') : 'No asignados'}',
                    style: TextStyle(height: 2),
                  ),
                  Text(
                    'Sede(s): ${graduate['sedes']?['name'] ?? 'No asignada'}',
                    style: TextStyle(height: 2),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          decoration: InputDecoration(
            hintText: 'Buscar egresado...',
            hintStyle: TextStyle(color: Colors.white),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: filterGraduates,
        ),
      ),
      drawer: Menu.buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: fetchGraduates,
        color: Colors.blue,
        child: ListView.builder(
          itemCount: filteredGraduates.length,
          itemBuilder: (context, index) {
            final graduate = filteredGraduates[index];
            return Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: graduate['profile_image'] != null &&
                            graduate['profile_image'].isNotEmpty
                        ? Image.network(graduate['profile_image'],
                            height: 50, width: 50, fit: BoxFit.cover)
                        : Image.asset('assets/images/refmmp.png',
                            height: 50, width: 50, fit: BoxFit.cover),
                  ),
                  title: Text(
                    '${graduate['first_name']} ${graduate['last_name']}',
                    style: TextStyle(color: Colors.blue),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(graduate['email']),
                      Text(
                          'Instrumentos: ${graduate['graduate_instruments'] != null && graduate['graduate_instruments'].isNotEmpty ? graduate['graduate_instruments'].map((e) => e['instruments']['name']).join(', ') : 'No asignados'}'),
                      Text(
                          'Sede: ${graduate['sedes']?['name'] ?? 'No asignado'}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () => showGraduateOptions(context, graduate),
                  ),
                ),
                Divider(thickness: 1, color: Colors.blue),
              ],
            );
          },
        ),
      ),
    );
  }
}
