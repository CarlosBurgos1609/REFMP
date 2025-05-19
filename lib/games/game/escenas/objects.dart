import 'package:flutter/material.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
// import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
// import 'package:refmp/theme/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ObjetsPage extends StatefulWidget {
  final String instrumentName;
  const ObjetsPage({
    Key? key,
    required this.instrumentName,
  });

  @override
  _ObjetsPageState createState() => _ObjetsPageState();
}

class _ObjetsPageState extends State<ObjetsPage> {
  final supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> groupedObjets = {};
  String? profileImageUrl;

  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    fetchObjets();
    fetchUserProfileImage();
  }

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

  Future<void> fetchObjets() async {
    final response = await supabase.from('objets').select();
    final data = response as List;

    // Agrupar por categoría
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in data) {
      final category = item['categoria'] ?? 'GENERAL';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    setState(() {
      groupedObjets = grouped;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Objetos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: groupedObjets.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
              color: Colors.blue,
            ))
          : RefreshIndicator(
              color: Colors.blue,
              onRefresh: fetchObjets,
              child: ListView(
                children: groupedObjets.entries.map((entry) {
                  final category = entry.key;
                  final objets = entry.value;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: objets.length,
                          itemBuilder: (context, index) {
                            final objet = objets[index];
                            return Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image:
                                            NetworkImage(objet['imagen_url']),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  objet['nombre'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      objet['moneda'] == 'coin'
                                          ? Icons.monetization_on
                                          : Icons.diamond,
                                      color: objet['moneda'] == 'coin'
                                          ? Colors.amber
                                          : Colors.blueAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${objet['precio']}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
