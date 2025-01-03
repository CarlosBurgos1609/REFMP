import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:refmp/interfaces/init.dart';
// import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Red de Escuelas de Formación Musical de Pasto',
      home: const Init(),
      debugShowCheckedModeBanner: false,
    );
  }
}
