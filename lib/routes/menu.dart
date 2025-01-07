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

class Menu {
  static const Map<int, String> _titles = {
    0: 'Inicio',
    1: 'Perfil',
    3: 'Notificaciones',
    2: 'Sedes',
    4: 'Instrumentos',
    5: 'Eventos',
    6: 'Contactos',
    7: 'Ubicaciones',
    8: 'Configuración'
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
      default:
        return Icons.error;
    }
  }

  static void _navigateToPage(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const HomePage(title: "Inicio")));
      case 1:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const ProfilePage(title: "Perfil")));
        break;
      case 2:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const HeadquartersPage(title: "Sedes")));
        break;
      case 3:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const NotificationPage(title: "Notificaciones")));
        break;
      case 4:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const InstrumentsPage(
                      title: "Instrumentos",
                    )));
        break;
      case 5:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const EventsPage(title: "Eventos")));
        break;
      case 6:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const ContactsPage(title: "Contactos")));
        break;
      case 7:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const LocationsPage(title: "Ubicaciones")));
        break;
      case 8:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const SettingsPage(title: "Configuración")));
        break;
      default:
        break;
    }
  }

  static Drawer buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            padding: EdgeInsets.fromLTRB(12, 0, 0, 12),
            decoration: BoxDecoration(color: Colors.blue),
            child: Row(
              children: [
                ClipOval(
                  child: Image(
                      image: AssetImage('assets/images/refmmp.png'),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover),
                ),
                SizedBox(width: 12),
                Center(
                    child: Column(
                  children: [
                    Text("Nombre del perfil",
                        style: TextStyle(
                            fontSize: 18,
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.bold)),
                    Column(children: [
                      Text(
                        "Admin",
                        style: TextStyle(
                            fontSize: 15,
                            backgroundColor: Colors.amber,
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.bold),
                      ),
                    ])
                  ],
                ))
              ],
            ),
          ),
          ...List.generate(_titles.length, (index) {
            return ListTile(
              leading: Icon(Menu._getIcon(index), color: Colors.blue),
              title: Text(_titles[index]!,
                  style: const TextStyle(color: Colors.blue)),
              onTap: () {
                Navigator.pop(context);
                Menu._navigateToPage(context, index);
              },
            );
          }),
        ],
      ),
    );
  }
}
