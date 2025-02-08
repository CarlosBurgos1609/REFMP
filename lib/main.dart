// import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:refmp/interfaces/init.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://dmhyuogexgghinvfgoup.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtaHl1b2dleGdnaGludmZnb3VwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4MTI3NDEsImV4cCI6MjA1NDM4ODc0MX0.jRXmFC75jhyOMa1FJ8bw9__cbAua8erwJkYODn_YckM',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Init(),
      debugShowCheckedModeBanner: false,
    );
  }
}
