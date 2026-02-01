import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/edit/edit_profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
  String? userTable;

  final List<String> userTables = [
    'users',
    'students',
    'graduates',
    'teachers',
    'advisors',
    'parents',
    'guests'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    final box = Hive.box('offline_data');
    const cacheKey = 'user_profile';

    // Load cached data immediately
    final cachedProfile = box.get(cacheKey);
    if (cachedProfile != null) {
      final cachedProfileTyped = Map<String, dynamic>.from(cachedProfile);
      setState(() {
        userProfile = cachedProfileTyped;
        profileImageUrl = cachedProfileTyped['profile_image'] ?? '';
        userTable = 'offline';
      });
    }

    // Check connectivity and fetch online data if available
    final isOnline = await _checkConnectivity();
    if (isOnline) {
      try {
        for (String table in userTables) {
          final response = await supabase
              .from(table)
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

          if (response != null) {
            // ignore: unnecessary_cast
            final responseMap = response as Map<String, dynamic>;
            final imageUrl = responseMap['profile_image'] ?? '';
            // Pre-cache the profile image
            if (imageUrl.isNotEmpty) {
              await CustomCacheManager.instance.downloadFile(imageUrl);
            }
            await box.put(cacheKey, {
              'first_name': responseMap['first_name'] ?? '',
              'last_name': responseMap['last_name'] ?? '',
              'identification_number':
                  responseMap['identification_number'] ?? '',
              'charge': responseMap['charge'] ?? '',
              'email': responseMap['email'] ?? '',
              'profile_image': imageUrl,
            });

            setState(() {
              userTable = table;
              userProfile = {
                'first_name': responseMap['first_name'] ?? '',
                'last_name': responseMap['last_name'] ?? '',
                'identification_number':
                    responseMap['identification_number'] ?? '',
                'charge': responseMap['charge'] ?? '',
                'email': responseMap['email'] ?? '',
                'profile_image': imageUrl,
              };
              profileImageUrl = imageUrl;
            });
            break;
          }
        }
      } catch (e) {
        debugPrint('Error fetching data from Supabase: $e');
        // Fallback to cached data if online fetch fails
        if (cachedProfile != null) {
          final cachedProfileTyped = Map<String, dynamic>.from(cachedProfile);
          setState(() {
            userProfile = cachedProfileTyped;
            profileImageUrl = cachedProfileTyped['profile_image'] ?? '';
            userTable = 'offline';
          });
        }
      }
    }

    setState(() {
      isLoading = false;
    });
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      await _uploadProfileImage(file);
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || userTable == null || userTable == 'offline') return;

      final fileName = 'profile_${user.id}.png';
      final storagePath = 'profile_pictures/$fileName';

      await supabase.storage.from('profiles').upload(storagePath, imageFile);

      final publicUrl =
          supabase.storage.from('profiles').getPublicUrl(storagePath);

      await supabase
          .from(userTable!)
          .update({'profile_image': publicUrl}).eq('user_id', user.id);

      // Update cache
      final box = Hive.box('offline_data');
      final cachedProfile = box.get('user_profile') ?? {};
      cachedProfile['profile_image'] = publicUrl;
      await box.put('user_profile', cachedProfile);

      // Pre-cache the new image
      await CustomCacheManager.instance.downloadFile(publicUrl);

      setState(() {
        profileImageUrl = publicUrl;
        userProfile['profile_image'] = publicUrl;
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
                        GestureDetector(
                          onTap: userTable == 'guests' ? null : _pickImage,
                          child: CircleAvatar(
                            radius: 80,
                            backgroundColor: Colors.blue,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipOval(
                                  child: SizedBox.expand(
                                    child: profileImageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: profileImageUrl,
                                            cacheManager:
                                                CustomCacheManager.instance,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Image.asset(
                                              'assets/images/refmmp.png',
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Image.asset(
                                            'assets/images/refmmp.png',
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                if (userTable != 'guests')
                                  const Align(
                                    alignment: Alignment.bottomRight,
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.camera_alt,
                                          color: Colors.blue),
                                    ),
                                  ),
                              ],
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
        floatingActionButton:
            userTable == null || userTable == 'offline' || userTable == 'guests'
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
                      await _loadProfileData();
                    },
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Editar perfil',
                  ),
      ),
    );
  }

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
