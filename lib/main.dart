import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/init.dart';

import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://dmhyuogexgghinvfgoup.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtaHl1b2dleGdnaGludmZnb3VwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4MTI3NDEsImV4cCI6MjA1NDM4ODc0MX0.jRXmFC75jhyOMa1FJ8bw9__cbAua8erwJkYODn_YckM',
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      theme: themeProvider.currentTheme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<AuthState?>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data?.session != null) {
            return const HomePage(
              title: 'Bienvenido',
            );
          } else {
            return const Init();
          }
        },
      ),
    );
  }

  Future<AuthState?> _getInitialScreen() async {
    final session = Supabase.instance.client.auth.currentSession;
    return AuthState(session: session);
  }
}

class AuthState {
  final Session? session;
  AuthState({required this.session});
}
