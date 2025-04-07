import 'package:flutter/material.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/menu/settings.dart';
import 'package:refmp/interfaces/menu/contacts.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';
import 'package:refmp/interfaces/menu/instruments.dart';
import 'package:refmp/interfaces/menu/locations.dart';
import 'package:refmp/interfaces/menu/notification.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/interfaces/menu/students.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Menu {
  static const Map<int, String> _titles = {
    0: 'Inicio',
    1: 'Perfil',
    2: 'Sedes',
    4: 'Instrumentos',
    5: 'Eventos',
    7: 'Ubicaciones',
    9: 'Estudiantes',
    3: 'Notificaciones',
    6: 'Contactos',
    8: 'Configuración',
    10: 'Egresados'
  };

  static IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.account_circle_rounded;
      case 2:
        return Icons.business_rounded;
      case 3:
        return Icons.circle_notifications;
      case 4:
        return Icons.piano_rounded;
      case 5:
        return Icons.calendar_month_rounded;
      case 6:
        return Icons.contacts_rounded;
      case 7:
        return Icons.map_outlined;
      case 8:
        return Icons.settings;
      case 9:
        return Icons.supervised_user_circle;
      case 10:
        return Icons.supervised_user_circle_sharp;
      default:
        return Icons.error;
    }
  }

  // Usamos ValueNotifier para manejar el índice actual de la página
  static ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);

  static void _navigateToPage(BuildContext context, int index) {
    final routes = {
      0: MaterialPageRoute(
          settings: const RouteSettings(name: 'Inicio'),
          builder: (context) => const HomePage(title: "Inicio")),
      1: MaterialPageRoute(
          settings: const RouteSettings(name: 'Perfil'),
          builder: (context) => const ProfilePage(title: "Perfil")),
      2: MaterialPageRoute(
          settings: const RouteSettings(name: 'Sedes'),
          builder: (context) => const HeadquartersPage(title: "Sedes")),
      3: MaterialPageRoute(
          settings: const RouteSettings(name: 'Notificaciones'),
          builder: (context) =>
              const NotificationPage(title: "Notificaciones")),
      4: MaterialPageRoute(
          settings: const RouteSettings(name: 'Instrumentos'),
          builder: (context) => const InstrumentsPage(
                title: "Instrumentos",
              )),
      5: MaterialPageRoute(
          settings: const RouteSettings(name: 'Eventos'),
          builder: (context) => const EventsPage(title: "Eventos")),
      6: MaterialPageRoute(
          settings: const RouteSettings(name: 'Contactos'),
          builder: (context) => const ContactsPage(title: "Contactos")),
      7: MaterialPageRoute(
          settings: const RouteSettings(name: 'Ubicaciones'),
          builder: (context) => const LocationsPage(title: "Ubicaciones")),
      8: MaterialPageRoute(
          settings: const RouteSettings(name: 'Configuración'),
          builder: (context) => const SettingsPage(title: "Configuración")),
      9: MaterialPageRoute(
          settings: const RouteSettings(name: 'Estudiantes'),
          builder: (context) => const StudentsPage(title: "Estudiantes")),
      10: MaterialPageRoute(
          settings: const RouteSettings(name: 'Egresados'),
          builder: (context) => const SettingsPage(title: "Egresados")),
    };

    // Actualiza el índice de la página actual
    currentIndexNotifier.value = index;

    Navigator.pushReplacement(context, routes[index]!);
  }

  static Future<Map<String, dynamic>?> _loadUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents'
      ];
      for (final table in tables) {
        final response = await supabase
            .from(table)
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (response != null) {
          return response;
        }
      }
    }
    return null;
  }

  static ValueListenableBuilder<int> buildDrawer(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentIndexNotifier,
      builder: (context, currentIndex, _) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(color: Colors.blue),
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage("assets/images/pasto.png"),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FutureBuilder(
                      future: _loadUserProfile(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: Colors.blue,
                          ));
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return UserAccountsDrawerHeader(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            accountName: Text(
                              "Sin Conexion a internet",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            currentAccountPicture: GestureDetector(
                              onTap: () {
                                currentIndexNotifier.value = 1;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfilePage(title: "Perfil"),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundColor: Colors.blue,
                                backgroundImage: const AssetImage(
                                    "assets/images/refmmp.png"),
                              ),
                            ),
                            accountEmail: null,
                          );
                        }

                        final userProfile =
                            snapshot.data as Map<String, dynamic>;

                        return UserAccountsDrawerHeader(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          accountName: Text(
                            "${userProfile['first_name'] ?? 'Usuario'} ${userProfile['last_name'] ?? ''}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          accountEmail: Text(
                            userProfile['charge'] ?? "No tiene Cargo",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          currentAccountPicture: GestureDetector(
                            onTap: () {
                              currentIndexNotifier.value = 1;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfilePage(title: "Perfil"),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.blue,
                              backgroundImage: userProfile['profile_image'] !=
                                          null &&
                                      userProfile['profile_image'].isNotEmpty
                                  ? NetworkImage(userProfile['profile_image'])
                                      as ImageProvider
                                  : const AssetImage(
                                      "assets/images/refmmp.png"),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              ...[0, 1, 2, 4, 5, 7].map((index) {
                return ListTile(
                  leading: Icon(Menu._getIcon(index),
                      color: currentIndex == index ? Colors.blue : Colors.grey),
                  title: Text(
                    _titles[index]!,
                    style: TextStyle(
                      color: currentIndex == index ? Colors.blue : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Menu._navigateToPage(context, index);
                  },
                );
              }),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  "Usuarios",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Estudiantes
              ...[9, 10].map((index) {
                return ListTile(
                  leading: Icon(Menu._getIcon(index),
                      color: currentIndex == index ? Colors.blue : Colors.grey),
                  title: Text(
                    _titles[index]!,
                    style: TextStyle(
                      color: currentIndex == index ? Colors.blue : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Menu._navigateToPage(context, index);
                  },
                );
              }),
              const Divider(),
              // Notificaciones, eventos y configuración
              ...[3, 6, 8].map((index) {
                return ListTile(
                  leading: Icon(Menu._getIcon(index),
                      color: currentIndex == index ? Colors.blue : Colors.grey),
                  title: Text(
                    _titles[index]!,
                    style: TextStyle(
                      color: currentIndex == index ? Colors.blue : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Menu._navigateToPage(context, index);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
