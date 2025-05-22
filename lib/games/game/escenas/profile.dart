import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePageGame extends StatefulWidget {
  final String instrumentName;
  const ProfilePageGame({super.key, required this.instrumentName});

  @override
  State<ProfilePageGame> createState() => _ProfilePageGameState();
}

class _ProfilePageGameState extends State<ProfilePageGame>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  String? profileImageUrl;
  String? firstName;
  String? lastName;
  String? fullName;
  String? userName;

  int experiencePoints = 0;

  late TabController _tabController;
  int _selectedIndex = 4;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // evitar recargar la misma página

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LearningPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MusicPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CupPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ObjetsPage(instrumentName: widget.instrumentName),
          ),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfilePageGame(instrumentName: widget.instrumentName),
          ),
        );
        break;
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    debugPrint('Conectividad: $connectivityResult');
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isOnline = await _checkConnectivity();

      if (!isOnline) {
        final box = Hive.box('offline_data');
        const cacheKey = 'user_profile_image';
        final cachedProfileImage = box.get(cacheKey, defaultValue: null);
        if (cachedProfileImage != null) {
          setState(() {
            profileImageUrl = cachedProfileImage;
          });
        }
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents'
      ];

      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('profile_image')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null && response['profile_image'] != null) {
          setState(() {
            profileImageUrl = response['profile_image'];
          });

          final box = Hive.box('offline_data');
          await box.put('user_profile_image', response['profile_image']);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchData();
    fetchUserProfileImage();
  }

  Future<void> fetchData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Obtener imagen de perfil y nombre
      final responseUser = await supabase
          .from('users')
          .select('profile_image, first_name, last_name')
          .eq('user_id', user.id)
          .maybeSingle();

      final responseCup = await supabase
          .from('cup')
          .select('full_name, experience_points')
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        profileImageUrl = responseUser?['profile_image'];
        firstName = responseUser?['first_name'];
        lastName = responseUser?['last_name'];
        userName = '${firstName ?? ''} ${lastName ?? ''}';
        fullName = responseCup?['full_name'] ?? 'Sin nickname';
        experiencePoints = responseCup?['experience_points'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  void _editFullName() async {
    final controller = TextEditingController(text: fullName);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Center(
          child: Text(
            "Editar Nickname",
            style: TextStyle(color: Colors.blue),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Nuevo Nickname"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = supabase.auth.currentUser;
              if (user != null) {
                await supabase.from('cup').update(
                    {'full_name': controller.text}).eq('user_id', user.id);
                setState(() {
                  fullName = controller.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Guardar",
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Column(
      children: [
        const SizedBox(height: 24),
        profileImageUrl != null
            ? ClipOval(
                child: Image.network(
                  profileImageUrl!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              )
            : const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
        const SizedBox(height: 12),
        Text(
          userName ?? 'Usuario sin nombre',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fullName ?? 'Sin nickname',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _editFullName,
              child: const Icon(Icons.edit, size: 18, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Puntos de experiencia: $experiencePoints',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          height: 40,
          thickness: 2,
          color: themeProvider.isDarkMode
              ? const Color.fromARGB(255, 34, 34, 34)
              : const Color.fromARGB(255, 236, 234, 234),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Perfil",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(icon: Icon(Icons.favorite_rounded), text: "Favoritos"),
              Tab(icon: Icon(Icons.shopping_bag_rounded), text: "Objetos"),
              Tab(icon: Icon(Icons.history_rounded), text: "Historial"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                Center(child: Text('🎵 No tienes Canciones favoritas 🎵')),
                Center(child: Text('🎁 No tines Objetos 🎁')),
                Center(child: Text('⌚No tienes Historial de experiencia ⌚')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
