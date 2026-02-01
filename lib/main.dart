import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/init.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';
import 'package:refmp/interfaces/menu/instruments.dart';
import 'package:refmp/interfaces/menu/notification.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:refmp/services/notification_service.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Notification Service
  NotificationService.init(navigatorKey);

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('offline_data');
  await Hive.openBox('pending_actions');
  debugPrint(
      'Hive initialized and boxes opened: offline_data, pending_actions');

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://dmhyuogexgghinvfgoup.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtaHl1b2dleGdnaGludmZnb3VwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4MTI3NDEsImV4cCI6MjA1NDM4ODc0MX0.jRXmFC75jhyOMa1FJ8bw9__cbAua8erwJkYODn_YckM',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
      ],
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
      navigatorKey: navigatorKey,
      theme: themeProvider.currentTheme,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          return MaterialPageRoute(
            builder: (context) => const HomePage(
              title: 'Inicio',
            ),
          );
        }
        if (settings.name == '/events') {
          return MaterialPageRoute(
            builder: (context) => const EventsPage(
              title: 'Eventos',
            ),
          );
        }
        if (settings.name == '/instruments') {
          return MaterialPageRoute(
            builder: (context) => const InstrumentsPage(
              title: 'Intrumentos',
            ),
          );
        }
        if (settings.name == '/sedes') {
          return MaterialPageRoute(
            builder: (context) => const HeadquartersPage(
              title: 'Sedes',
            ),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const NotificationPage(
            title: 'Notificaciones',
          ),
        );
      },
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
              title: 'Bienvenid@',
            );
          } else {
            return const Init();
          }
        },
      ),
    );
  }

  Future<AuthState?> _getInitialScreen() async {
    // Iniciar timer y verificar sesión en paralelo
    final startTime = DateTime.now();
    final session = Supabase.instance.client.auth.currentSession;

    // Calcular tiempo transcurrido
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final minimumDelay = 3500; // 3.5 segundos

    // Si tardó menos del tiempo mínimo, esperar la diferencia
    if (elapsed < minimumDelay) {
      await Future.delayed(Duration(milliseconds: minimumDelay - elapsed));
    }

    return AuthState(session: session);
  }
}

class AuthState {
  final Session? session;
  AuthState({required this.session});
}
