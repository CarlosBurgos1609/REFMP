import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/edit/edit_profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hive/hive.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.title});
  final String title;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> userProfile = {};
  String profileImageUrl = '';
  bool isLoading = true;
  String?
      userTable; // Aquí guardamos la tabla en la que está registrado el usuario

  final List<String> userTables = [
    'users',
    'students',
    'graduates',
    'teachers',
    'advisors',
    'parents'
  ];

  @override
  void initState() {
    super.initState();
    _findUserTable();
  }

  // 🔹 Buscar en qué tabla está registrado el usuario
  Future<void> _findUserTable() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      isLoading = true;
    });

    final box = Hive.box('offline_data');
    const cacheKey = 'user_profile';

    final isOnline = await _checkConnectivity();

    if (isOnline) {
      // Si hay conexión a internet, obtener datos de Supabase
      for (String table in userTables) {
        final response = await supabase
            .from(table)
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          // Guardar datos en cache
          await box.put(cacheKey, {
            'first_name': response['first_name'] ?? '',
            'last_name': response['last_name'] ?? '',
            'identification_number': response['identification_number'] ?? '',
            'charge': response['charge'] ?? '',
            'email': response['email'] ?? '',
            'profile_image': response['profile_image'] ?? '',
          });

          setState(() {
            userTable = table;
            userProfile = {
              'first_name': response['first_name'] ?? '',
              'last_name': response['last_name'] ?? '',
              'identification_number': response['identification_number'] ?? '',
              'charge': response['charge'] ?? '',
              'email': response['email'] ?? '',
              'profile_image': response['profile_image'] ?? '',
            };
            profileImageUrl = response['profile_image'] ?? '';
          });
          break;
        }
      }
    } else {
      // Si no hay conexión, recuperar los datos desde el cache
      final cachedProfile = box.get(cacheKey, defaultValue: null);

      if (cachedProfile != null) {
        setState(() {
          userProfile = cachedProfile;
          profileImageUrl = cachedProfile['profile_image'] ?? '';
          userTable = 'offline'; // Indicar que los datos provienen del cache
        });
      }
    }

    setState(() {
      isLoading = false;
    });
  }

// Método para verificar la conectividad a internet
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint('Conectividad: $connectivityResult');
    return connectivityResult != ConnectivityResult.none;
  }

  // 🔹 Subir imagen desde la galería
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      await _uploadProfileImage(file);
    }
  }

  // 🔹 Subir imagen a Supabase Storage y actualizar en la tabla correcta
  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || userTable == null) return;

      final fileName = 'profile_${user.id}.png';
      final storagePath = 'profile_pictures/$fileName';

      await supabase.storage.from('profiles').upload(storagePath, imageFile);

      final publicUrl =
          supabase.storage.from('profiles').getPublicUrl(storagePath);

      // Actualizar URL en la base de datos
      await supabase
          .from(userTable!)
          .update({'profile_image': publicUrl}).eq('user_id', user.id);

      setState(() {
        profileImageUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir imagen: ${e.toString()}')),
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
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          backgroundColor: Colors.blue,
          centerTitle: true,
        ),
        drawer: Menu.buildDrawer(context),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : userTable == null
                ? const Center(
                    child: Text('Usuario no registrado en ninguna tabla',
                        style: TextStyle(fontSize: 18, color: Colors.red)))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 🔹 Mostrar la tabla donde está el usuario
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.blue,
                            backgroundImage: profileImageUrl.isNotEmpty
                                ? NetworkImage(profileImageUrl) as ImageProvider
                                : const AssetImage('assets/images/refmmp.png'),
                            child: const Align(
                              alignment: Alignment.bottomRight,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child:
                                    Icon(Icons.camera_alt, color: Colors.blue),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildProfileField(
                            'Nombres', userProfile['first_name']),
                        _buildProfileField(
                            'Apellidos', userProfile['last_name']),
                        _buildProfileField('Identificación',
                            userProfile['identification_number']),
                        _buildProfileField('Cargo', userProfile['charge']),
                        _buildProfileField('Correo', userProfile['email']),
                      ],
                    ),
                  ),
        floatingActionButton: userTable == null
            ? null
            : FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        userProfile: userProfile,
                        userTable: userTable!,
                      ),
                    ),
                  );
                  // Refrescar datos al volver
                  _findUserTable();
                },
                backgroundColor: Colors.blue,
                child: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'Editar perfil',
              ),
      ),
    );
  }

  // 🔹 Método para mostrar campos del perfil
  Widget _buildProfileField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                value?.toString() ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
