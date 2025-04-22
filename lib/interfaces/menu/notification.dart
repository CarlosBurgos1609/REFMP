import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';
import 'package:refmp/interfaces/menu/instruments.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/interfaces/menu/students.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/services/notification_service.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.title});

  final String title;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _notificationsEnabled = false;
  List<Map<String, dynamic>> _notifications = [];

  final Map<String, IconData> iconMap = {
    'alarm': Icons.alarm,
    'event': Icons.event,
    'message': Icons.message,
    'music': Icons.music_note,
    'person': Icons.person,
    'school': Icons.school,
    'home': Icons.home,
    'info': Icons.info,
    'star': Icons.star,
    'warning': Icons.warning,
    'notifications': Icons.notifications,
  };

  @override
  void initState() {
    super.initState();
    checkPermissionStatus();
    fetchNotificationHistory();
  }

  Future<void> checkPermissionStatus() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
    });
  }

  Future<void> requestPermission(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    } else {
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  Future<void> fetchAndShowNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final response = await Supabase.instance.client
        .from('user_notifications')
        .select('*, notifications(*)')
        .eq('user_id', userId!)
        .eq('is_read', false);

    final List data = response;

    for (var notif in data) {
      final notifData = notif['notifications'];
      if (notifData != null) {
        await NotificationService.showNotification(
          id: notif['id'],
          title: notifData['title'],
          message: notifData['message'],
          icon: notifData['icon'],
          payload: notifData['redirect_to'],
        );

        await Supabase.instance.client
            .from('user_notifications')
            .update({'is_read': true}).eq('id', notif['id']);
      }
    }

    await fetchNotificationHistory();
  }

  Future<void> fetchNotificationHistory() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final response = await Supabase.instance.client
        .from('user_notifications')
        .select('*, notifications(*)')
        .eq('user_id', userId!)
        .order('created_at', ascending: false);

    setState(() {
      _notifications = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> deleteNotification(int id) async {
    await Supabase.instance.client
        .from('user_notifications')
        .delete()
        .eq('id', id);

    setState(() {
      _notifications.removeWhere((n) => n['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final routeBuilderMap = {
      '/home': () => const HomePage(title: 'Inicio'),
      '/profile': () => const ProfilePage(title: 'Perfil'),
      '/headquarters': () => const HeadquartersPage(title: 'Sedes'),
      '/intrumentos': () => const InstrumentsPage(title: 'Instrumentos'),
      '/events': () => const EventsPage(title: 'Eventos'),
      '/students': () => const StudentsPage(title: 'Estudiantes'),
    };

    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Permitir notificaciones",
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.isDarkMode
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : const Color.fromARGB(255, 33, 150, 243),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: requestPermission,
                    activeColor: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: fetchAndShowNotifications,
                icon: const Icon(
                  Icons.cloud_download,
                  color: Colors.blue,
                ),
                label: const Text(
                  "Verificar nuevas notificaciones",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
              Divider(
                height: 40,
                thickness: 2,
                color: themeProvider.isDarkMode
                    ? const Color.fromARGB(255, 34, 34, 34)
                    : const Color.fromARGB(255, 236, 234, 234),
              ),
              Text(
                "Historial de notificaciones",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? const Color.fromARGB(255, 255, 252, 252)
                      : const Color.fromARGB(255, 33, 150, 243),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(child: Text("No tienes notificaciones"))
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final notifData = notif['notifications'];

                          final iconKey = notifData['icon']?.toString() ?? '';
                          final icon = iconMap[iconKey] ?? Icons.notifications;
                          final imageUrl = notifData['image'];

                          return Dismissible(
                            key: Key(notif['id'].toString()),
                            background: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              deleteNotification(notif['id']);
                            },
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: Icon(icon, color: Colors.blue),
                                title: Text(
                                  notifData['title'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(notifData['message'] ?? ''),
                                trailing: imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          imageUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  final redirect = notifData['redirect_to']
                                      ?.toString()
                                      .trim();

                                  final redirectToIndex = {
                                    '/home': 1,
                                    '/profile': 2,
                                    '/headquarters': 3,
                                    '/intrumentos': 4,
                                    '/events': 5,
                                    '/students': 6,
                                  };

                                  if (redirect != null &&
                                      routeBuilderMap.containsKey(redirect) &&
                                      redirectToIndex.containsKey(redirect)) {
                                    Menu.currentIndexNotifier.value =
                                        redirectToIndex[redirect]!;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            routeBuilderMap[redirect]!(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Ruta de redirección no válida")),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
