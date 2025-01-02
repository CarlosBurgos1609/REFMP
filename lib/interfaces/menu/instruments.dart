import 'package:flutter/material.dart';
import 'package:refmp/routes/menu.dart';

class InstrumentsPage extends StatelessWidget {
  const InstrumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intrumentos'),
      ),
      drawer: Menu.buildDrawer(context),
      body: const Center(
        child: Text('Contenido de la página de Intrumentos'),
      ),
    );
  }
}
