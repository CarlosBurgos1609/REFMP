import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart';

class HeadquartersPage extends StatelessWidget {
  const HeadquartersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sedes'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de sedes'),
      ),
    );
  }
}
