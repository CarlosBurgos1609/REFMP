import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.title});
  final String title;

  @override
  State<ContactsPage> createState() => _ContactsPage();
}

class _ContactsPage extends State<ContactsPage> {
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ElevatedButton(onPressed: () {}, child: const Text("disable")),
              ElevatedButton.icon(
                onPressed: () {},
                label: const Text("data"),
                icon: Icon(Icons.message),
              ),
              const SizedBox(
                child: Center(
                  child: Text(
                    "Pagina de contactos",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
