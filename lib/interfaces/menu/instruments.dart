import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';

class InstrumentsPage extends StatefulWidget {
  const InstrumentsPage({super.key, required this.title});
  final String title;

  @override
  State<InstrumentsPage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<InstrumentsPage> {
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
        body: const Center(
          child: Text(
            "Contenido de la página Intrumentos",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
