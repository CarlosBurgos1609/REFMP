import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.title});
  final String title;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> userProfile = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Cargar el perfil del usuario desde Firestore
  Future<void> _loadUserProfile() async {
    try {
      // Obtén el UID del usuario autenticado
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String uid = user.uid;

        print("UID del usuario autenticado: $uid"); // Depuración

        // Realiza una consulta en Firestore para obtener los datos del perfil
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users') // O la colección que prefieras
            .doc(uid) // Aquí usamos el UID como documento
            .get();

        if (docSnapshot.exists) {
          setState(() {
            userProfile = docSnapshot.data() as Map<String, dynamic>;
          });
          print("Datos del perfil cargados: ${userProfile}"); // Depuración
        } else {
          setState(() {
            userProfile = {'error': 'Perfil no encontrado'};
          });
        }
      }
    } catch (e) {
      setState(() {
        userProfile = {'error': 'Error al cargar el perfil: ${e.toString()}'};
      });
      print("Error al cargar el perfil: ${e.toString()}"); // Depuración
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
          elevation: 0,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(padding: EdgeInsets.all(6)),
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/refmmp.png',
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.width * 0.5,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (userProfile.isNotEmpty &&
                  !userProfile.containsKey('error')) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blue, // Color de fondo
                      borderRadius:
                          BorderRadius.circular(40), // Bordes redondeados
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Column(
                        children: [
                          // Nombre y apellido
                          Text(
                            '${userProfile['name']} ${userProfile['last_name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Correo electrónico
                          _buildProfileField(
                              'Correo electrónico', userProfile['email']),
                          const SizedBox(height: 16),
                          // Posición
                          _buildProfileField(
                              'Posición', userProfile['position']),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (userProfile.containsKey('error')) ...[
                Text(
                  userProfile['error'],
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              ] else ...[
                // Si aún no se han cargado los datos
                CircularProgressIndicator(color: Colors.blue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Método para construir un campo de perfil (solo lectura)
  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue, // Color de fondo
          borderRadius: BorderRadius.circular(30), // Bordes redondeados
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
