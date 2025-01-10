import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
//firebase
import 'package:refmp/services/firebase_services.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.title});
  final String title;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
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
                return const Center(
                    child: CircularProgressIndicator(
                  color: Colors.blue,
                ));
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
                  final last_name =
                      user['last_name'] as String? ?? "No se encontro Apellido";
                  final email =
                      user['email'] as String? ?? "No se encontro el email";
                  return Center(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(name),
                        ),
                        ListTile(
                          title: Text(last_name),
                          textColor: Colors.blue,
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
