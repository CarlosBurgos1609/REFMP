import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  static const List<Widget> _widgetOptions = <Widget>[
    Text(
      'Home',
      style: TextStyle(color: Colors.blue),
    ),
    Text(
      'Index 1: Perfil',
      style: optionStyle,
    ),
    Text(
      'Index 2: Sedes',
      style: optionStyle,
    ),
    Text(
      'Index 3: Notificaciones',
      style: optionStyle,
    ),
    Text(
      'Index 4: Intrumento',
      style: optionStyle,
    ),
    Text(
      'Index 5: Eventos',
      style: optionStyle,
    ),
    Text(
      'Index 6: contactos',
      style: optionStyle,
    ),
    Text(
      'Index 7: Ubicaciones',
      style: optionStyle,
    ),
    Text(
      'Index 8: Configuraciones',
      style: optionStyle,
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
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
      body: Center(
        child: _widgetOptions[_selectedIndex],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
                padding: EdgeInsets.fromLTRB(12, 0, 0, 12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text(
                  "Inicio",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                )),
            ListTile(
              leading: const Icon(
                Icons.account_circle_rounded,
                color: Colors.blue,
              ),
              title: const Text('Perfil',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 1,
              onTap: () {
                // Update the state of the app
                _onItemTapped(1);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.home,
                color: Colors.blue,
              ),
              title: const Text(
                'Inicio',
                style: TextStyle(color: Colors.blue),
              ),
              selected: _selectedIndex == 0,
              onTap: () {
                // Update the state of the app
                _onItemTapped(0);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.business_rounded,
                color: Colors.blue,
              ),
              title: const Text('Sedes',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 2,
              onTap: () {
                // Update the state of the app
                _onItemTapped(2);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.circle_notifications,
                color: Colors.blue,
              ),
              title: const Text('Notificaciones',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 3,
              onTap: () {
                // Update the state of the app
                _onItemTapped(3);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.piano_rounded,
                color: Colors.blue,
              ),
              title: const Text('Instrumento',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 4,
              onTap: () {
                // Update the state of the app
                _onItemTapped(4);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.blue,
              ),
              title: const Text('Eventos',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 5,
              onTap: () {
                // Update the state of the app
                _onItemTapped(5);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.contacts_rounded,
                color: Colors.blue,
              ),
              title: const Text('Contactos',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 6,
              onTap: () {
                // Update the state of the app
                _onItemTapped(6);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.map_outlined,
                color: Colors.blue,
              ),
              title: const Text('Ubicaciones',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 7,
              onTap: () {
                // Update the state of the app
                _onItemTapped(7);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings,
                color: Colors.blue,
              ),
              title: const Text('Configuración',
                  style: TextStyle(
                    color: Colors.blue,
                  )),
              selected: _selectedIndex == 8,
              onTap: () {
                // Update the state of the app
                _onItemTapped(8);
                // Then close the drawer
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
