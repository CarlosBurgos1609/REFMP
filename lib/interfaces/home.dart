import 'package:flutter/material.dart';
import 'package:refmp/interfaces/menu/settings.dart';
import 'package:refmp/interfaces/menu/contacts.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';
import 'package:refmp/interfaces/menu/instruments.dart';
import 'package:refmp/interfaces/menu/locations.dart';
import 'package:refmp/interfaces/menu/notification.dart';
import 'package:refmp/interfaces/menu/profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, String> _titles = {
    0: 'Inicio',
    1: 'Perfil',
    2: 'Sedes',
    3: 'Notificaciones',
    4: 'Instrumento',
    5: 'Eventos',
    6: 'Contactos',
    7: 'Ubicaciones',
    8: 'Configuración'
  };

  void _navigateToPage(BuildContext context, int index) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HeadquartersPage()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationPage()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InstrumentsPage()),
        );
        break;
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EventsPage()),
        );
        break;
      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactsPage()),
        );
        break;
      case 7:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LocationsPage()),
        );
        break;
      case 8:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              icon: const Icon(
                Icons.menu,
                color: Colors.blue,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              padding: const EdgeInsets.fromLTRB(12, 0, 0, 12),
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/refmmp.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Nombre del perfil",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
            ...List.generate(_titles.length, (index) {
              return ListTile(
                leading: Icon(
                  _getIcon(index),
                  color: Colors.blue,
                ),
                title: Text(
                  _titles[index]!,
                  style: const TextStyle(color: Colors.blue),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToPage(context, index);
                },
              );
            })
          ],
        ),
      ),
    );
  }

  IconData _getIcon(int index) {
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
      default:
        return Icons.error;
    }
  }
}
