// ignore_for_file: use_build_context_synchronously

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/game/escenas/objects.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CupPage extends StatefulWidget {
  final String instrumentName;
  const CupPage({super.key, required this.instrumentName});

  @override
  State<CupPage> createState() => _CupPageState();
}

class _CupPageState extends State<CupPage> {
  final supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _cupFuture;
  String? profileImageUrl;
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LearningPage(instrumentName: widget.instrumentName),
            ));
        break;
      case 1:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MusicPage(instrumentName: widget.instrumentName),
            ));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CupPage(instrumentName: widget.instrumentName),
            ));
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ObjetsPage(instrumentName: widget.instrumentName),
            ));
        break;
      case 4:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProfilePageGame(instrumentName: widget.instrumentName),
            ));
        break;
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        final box = Hive.box('offline_data');
        final cached = box.get('user_profile_image');
        if (cached != null) {
          setState(() => profileImageUrl = cached);
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
          setState(() => profileImageUrl = response['profile_image']);
          final box = Hive.box('offline_data');
          await box.put('user_profile_image', response['profile_image']);
          break;
        }
      }
    } catch (e) {
      debugPrint('Error al obtener imagen de perfil: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _cupFuture = fetchCupData();
    fetchUserProfileImage();
  }

  Future<List<Map<String, dynamic>>> fetchCupData() async {
    final response = await supabase
        .from('cup')
        .select(
            'user_id, instrument_id, experience_points, user_type, profile_image, full_name')
        .order('experience_points', ascending: false);

    return response
        .map<Map<String, dynamic>>((item) => {
              'name': item['full_name'],
              'profile_image': item['profile_image'],
              'experience_points': item['experience_points'],
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Torneo",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.blue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No hay datos en la copa."));
          }

          final cupList = snapshot.data!;

          return Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.emoji_events_rounded,
                  color: Color.fromARGB(255, 122, 247, 236), size: 150),
              const SizedBox(height: 12),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              const Text("Clasificación",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  color: Colors.blue,
                  onRefresh: () async {
                    final newData = await fetchCupData();
                    setState(() => _cupFuture = Future.value(newData));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: cupList.length,
                    itemBuilder: (context, index) {
                      final item = cupList[index];
                      final String name = item['name'];
                      final String? profileImage = item['profile_image'];
                      final int points = item['experience_points'];

                      final bool isCurrentUser = name.toLowerCase().contains(
                          (user?.userMetadata?['full_name'] ?? '')
                              .toString()
                              .toLowerCase());
                      final borderColor =
                          isCurrentUser ? Colors.blue : Colors.grey;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            color: themeProvider.isDarkMode
                                ? Colors.black54
                                : Colors.white,
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text('${index + 1}',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: index < 3
                                          ? Colors.blue
                                          : Colors.black87)),
                              const SizedBox(width: 5),
                              if (index < 3)
                                Icon(Icons.emoji_events_rounded,
                                    color: index == 0
                                        ? Colors.amber
                                        : index == 1
                                            ? Colors.grey
                                            : const Color(0xFFCD7F32),
                                    size: 30),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: profileImage != null
                                    ? NetworkImage(profileImage)
                                    : null,
                                child: profileImage == null
                                    ? const Icon(Icons.person, size: 32)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Row(
                                      children: [
                                        Text("$points ",
                                            style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Text("XP",
                                            style: TextStyle(
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
