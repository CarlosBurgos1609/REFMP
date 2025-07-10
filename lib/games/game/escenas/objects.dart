import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/cup.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:refmp/games/game/escenas/MusicPage.dart';
import 'package:refmp/games/learning.dart';
import 'package:refmp/routes/navigationBar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';

class ObjetsPage extends StatefulWidget {
  final String instrumentName;
  const ObjetsPage({Key? key, required this.instrumentName});

  @override
  _ObjetsPageState createState() => _ObjetsPageState();
}

class _ObjetsPageState extends State<ObjetsPage> {
  final supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> groupedObjets = {};
  String? profileImageUrl;
  int totalCoins = 0;
  List<dynamic> userObjets =
      []; // Lista para almacenar IDs de objetos adquiridos

  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    fetchObjets();
    fetchUserProfileImage();
    fetchTotalCoins();
    fetchUserObjets();
  }

  Future<void> fetchTotalCoins() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await supabase
        .from('users')
        .select('coins')
        .eq('user_id', userId)
        .maybeSingle();
    if (response != null && response['coins'] != null) {
      setState(() {
        totalCoins = response['coins'] ?? 0;
      });
    }
  }

  Future<void> fetchUserObjets() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('users_objets')
          .select('objet_id')
          .eq('user_id', userId);
      setState(() {
        userObjets = response.map((item) => item['objet_id']).toList();
      });
    } catch (e) {
      debugPrint('Error al obtener objetos del usuario: $e');
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
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
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> fetchUserProfileImage() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isOnline = await _checkConnectivity();
      if (!isOnline) {
        final box = Hive.box('offline_data');
        final cachedProfileImage =
            box.get('user_profile_image', defaultValue: null);
        setState(() {
          profileImageUrl = cachedProfileImage ?? 'assets/images/refmmp.png';
        });
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'directors'
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
      if (profileImageUrl == null) {
        setState(() {
          profileImageUrl = 'assets/images/refmmp.png';
        });
      }
    } catch (e) {
      debugPrint('Error al obtener la imagen del perfil: $e');
      setState(() {
        profileImageUrl = 'assets/images/refmmp.png';
      });
    }
  }

  Future<void> fetchObjets() async {
    final response = await supabase.from('objets').select();
    final data = response as List;

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in data) {
      final category = item['category'] ?? 'GENERAL';
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    grouped.forEach((key, value) {
      value.sort((a, b) {
        final aDate =
            a['created_at'] != null ? DateTime.tryParse(a['created_at']) : null;
        final bDate =
            b['created_at'] != null ? DateTime.tryParse(b['created_at']) : null;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
    });

    setState(() {
      groupedObjets = grouped;
    });
  }

  Future<bool> _canAddEvent() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final user = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return user != null;
  }

  Widget _buildCategorySection(
      String title, List<Map<String, dynamic>> items, BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final numberFormat = NumberFormat('#,##0', 'es_ES');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                "| ",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromARGB(255, 100, 100, 100),
              width: 2,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: title.toLowerCase() == 'avatares' ? 0.7 : 0.9,
            ),
            itemCount: items.length > 6 ? 6 : items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final category = title.toLowerCase();
              final isObtained = userObjets.contains(item['id']);
              Widget imageWidget;

              if (category == 'trompetas') {
                imageWidget = Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item['image_url'] ?? 'assets/images/refmmp.png',
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        if (isObtained)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              } else if (category == 'avatares') {
                imageWidget = Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(
                        color: isObtained ? Colors.green : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipOval(
                            child: Image.network(
                              item['image_url'] ?? 'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        if (isObtained)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              } else {
                imageWidget = Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['image_url'] ?? 'assets/images/refmmp.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      if (isObtained)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: imageWidget,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['name'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: themeProvider.isDarkMode
                            ? Color.fromARGB(255, 255, 255, 255)
                            : Color.fromARGB(255, 33, 150, 243),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isObtained) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Obtenido',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ] else ...[
                          Image.asset(
                            'assets/images/coin.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            numberFormat.format(item['price'] ?? 0),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (items.length > 6)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Placeholder(
                        child: Scaffold(
                          appBar: AppBar(
                            title: Text('Todos los ${title.toUpperCase()}'),
                            backgroundColor: Colors.blue,
                          ),
                          body: Center(
                            child: Text('Página de ${title.toUpperCase()}'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  'TODOS L@S ${title.toUpperCase()} (${items.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: RefreshIndicator(
        color: Colors.blue,
        onRefresh: () async {
          await fetchObjets();
          await fetchUserObjets();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400.0,
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
              title: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/images/coin.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalCoins',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16.0),
                title: Text(
                  'Objetos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                background: Image.asset(
                  'assets/images/coin.png',
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/refmmp.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '| Descripción',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Las monedas se utilizan para desbloquear objetos y mejoras. Puedes adquirirlas comprando paquetes en la tienda o ganándolas al completar desafíos y niveles.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 40,
                      thickness: 2,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 34, 34, 34)
                          : const Color.fromARGB(255, 236, 234, 234),
                    ),
                    for (var entry
                        in groupedObjets.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key)))
                      _buildCategorySection(entry.key, entry.value, context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canAddEvent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const SizedBox();
          if (snapshot.hasData && snapshot.data == true) {
            return FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () {},
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox();
        },
      ),
      bottomNavigationBar: CustomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        profileImageUrl: profileImageUrl,
      ),
    );
  }
}
