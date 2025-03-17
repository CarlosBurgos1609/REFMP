import 'dart:async';
import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? profileImageUrl;
  final supabase = Supabase.instance.client;
  late final PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  List<dynamic> sedes = [];

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
    fetchSedes();
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (sedes.isNotEmpty) {
        if (_currentPage < sedes.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> fetchUserProfileImage() async {
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
          .select('profile_image')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && response['profile_image'] != null) {
        setState(() {
          profileImageUrl = response['profile_image'];
        });
        break;
      }
    }
  }

  Future<void> fetchSedes() async {
    final response = await supabase.from('sedes').select();
    if (mounted) {
      setState(() {
        sedes = response;
      });
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
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          centerTitle: true,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          actions: [
            GestureDetector(
              onTap: () {
                Menu.currentIndexNotifier.value = 1;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(title: "Perfil"),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: ClipOval(
                  child: profileImageUrl != null
                      ? Image.network(
                          profileImageUrl!,
                          fit: BoxFit.cover,
                          width: 35,
                          height: 35,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              "assets/images/refmmp.png",
                              fit: BoxFit.cover,
                              width: 35,
                              height: 35,
                            );
                          },
                        )
                      : Image.asset(
                          "assets/images/refmmp.png",
                          fit: BoxFit.cover,
                          width: 45,
                          height: 45,
                        ),
                ),
              ),
            ),
          ],
        ),
        drawer: Menu.buildDrawer(context),
        body: sedes.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
            : PageView.builder(
                controller: _pageController,
                itemCount: sedes.length,
                itemBuilder: (context, index) {
                  final sede = sedes[index];
                  final name = sede["name"] ?? "Nombre no disponible";
                  final address = sede["address"] ?? "Dirección no disponible";
                  final description =
                      sede["description"] ?? "Descripción no disponible";
                  final photo = sede["photo"];

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              child: photo != null
                                  ? Image.network(
                                      photo,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Image.asset(
                                          "assets/images/refmmp.png",
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                  : Image.asset(
                                      "assets/images/refmmp.png",
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Dirección: $address",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Descripción: $description",
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
