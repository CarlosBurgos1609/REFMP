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
    8: 'Configuración',
    9: 'Estudiantes'
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
      case 9:
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const StudentsPage(title: "Estudiantes")));
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
          DrawerHeader(
              padding: const EdgeInsets.fromLTRB(2, 0, 0, 2),
              child: Center(
                child: ListView(
                  children: <Widget>[
                    UserAccountsDrawerHeader(
                        decoration: const BoxDecoration(
                            image: DecorationImage(
                                fit: BoxFit.cover,
                                image: NetworkImage(
                                    "https://upload.wikimedia.org/wikipedia/commons/8/83/San_Juan_de_Pasto_de_noche.jpg"))),
                        accountName: Text(
                          "Carlos Alexander Burgos J.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontWeight: FontWeight.bold),
                        ),
                        accountEmail: Text(
                          "Admin",
                          style: TextStyle(
                              fontSize: 15,
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontWeight: FontWeight.bold),
                        ),
                        currentAccountPicture: GestureDetector(
                          onTap: () => ProfilePage,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Image.asset("assets/images/logofn.png"),
                          ),
                        )),
                  ],
                ),
              )),
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
