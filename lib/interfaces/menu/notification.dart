import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.title});
  final String title;

  @override
  State<NotificationPage> createState() => _NotificationPage();
}

class _NotificationPage extends State<NotificationPage> {
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
              ElevatedButton.icon(
                onPressed: () {},
                label: const Text(
                  "Noticicaciones de Intrumentos",
                  style: TextStyle(color: Colors.blue),
                ),
                icon: Icon(
                  Icons.videogame_asset_rounded,
                  color: Colors.blue,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                label: const Text("Notificaciones de eventos",
                    style: TextStyle(color: Colors.blue)),
                icon: Icon(
                  Icons.calendar_month,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(
                child: Center(
                  child: Text(
                    "Pagina de Notificaciones",
                    style: TextStyle(fontSize: 20, color: Colors.blue),
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
