import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';

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
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    fetchUserProfileImage();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(70, 60, 70, 0),
                  ),
                  const Icon(Icons.location_city, size: 30, color: Colors.blue),
                  const SizedBox(height: 30),
                  const Text(
                    "Sedes",
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SlideTransition(
                position: _animation,
                child: FutureBuilder(
                  future: Supabase.instance.client.from("sedes").select(),
                  builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.blue));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text("No hay sedes disponibles",
                              style: TextStyle(color: Colors.blue)));
                    }

                    snapshot.data!.sort(
                        (a, b) => (a["name"] ?? "").compareTo(b["name"] ?? ""));

                    return ListView(
                      children: snapshot.data!.map((doc) {
                        final name = doc["name"] ?? "Nombre no disponible";
                        return Card(
                          margin: const EdgeInsets.all(10),
                          elevation: 5,
                          child: ListTile(
                            leading:
                                const Icon(Icons.business, color: Colors.blue),
                            title: Text(name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HeadquartersPage(title: "Sedes")),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
