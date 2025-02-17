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

class _HomePageState extends State<HomePage> {
  String? profileImageUrl;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();
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
          .maybeSingle(); // Obtiene solo un resultado

      if (response != null && response['profile_image'] != null) {
        setState(() {
          profileImageUrl = response['profile_image'];
        });
        break; // Si encuentra la imagen en una tabla, detiene la búsqueda
      }
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
        body: const Center(
          child: Text(
            "Contenido de la página Principal",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
