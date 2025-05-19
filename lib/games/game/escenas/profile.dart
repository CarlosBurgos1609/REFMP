import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

class ProfilePageGame extends StatefulWidget {
  final String instrumentName;
  const ProfilePageGame({super.key, required this.instrumentName});

  @override
  State<ProfilePageGame> createState() => _ProfilePageGameState();
}

class _ProfilePageGameState extends State<ProfilePageGame> {
  final supabase = Supabase.instance.client;

  String? profileImageUrl;
  String? userName;

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
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

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
            .select('profile_image, first_name, last_name')
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            profileImageUrl = response['profile_image'];
            userName =
                "${response['first_name'] ?? ''} ${response['last_name'] ?? ''}"
                    .trim();
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos del perfil: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            profileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                : const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
            const SizedBox(height: 16),
            Text(
              userName ?? 'Usuario sin nombre',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
