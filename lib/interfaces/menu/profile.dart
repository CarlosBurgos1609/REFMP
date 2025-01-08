import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
//firebase
import 'package:refmp/services/firebase_services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.title});
  final String title;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.blue),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
          ),
          drawer: Menu.buildDrawer(context),
          body: FutureBuilder<List>(
            future: getUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No users found."));
              }

              final users = snapshot.data!;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index] as Map<String, dynamic>;
                  final name =
                      user['name'] as String? ?? "No se encontro ningun nombre";
                  final midle_name = user['midle_name'] as String? ??
                      "No se encontro segundo nombre";
                  final email =
                      user['email'] as String? ?? "No se encontro el email";
                  return Center(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(name),
                        ),
                        ListTile(
                          title: Text(midle_name),
                        ),
                        ListTile(
                          title: Text(email),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ));
  }
}
