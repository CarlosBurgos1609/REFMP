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
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.title});

  final String title;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _notificationsEnabled = false;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

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
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await checkPermissionStatus();
      await fetchNotificationHistory();
      _subscribeToNotifications();
    } catch (e, stackTrace) {
      debugPrint('Error in initialization: $e\n$stackTrace');
    }
  }

  Future<void> checkPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      setState(() {
        _notificationsEnabled = status.isGranted;
      });
    } catch (e, stackTrace) {
      debugPrint('Error checking permission status: $e\n$stackTrace');
    }
  }

  Future<void> requestPermission(bool value) async {
    try {
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
    } catch (e, stackTrace) {
      debugPrint('Error requesting permission: $e\n$stackTrace');
    }
  }

  void _subscribeToNotifications() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No authenticated user found for subscription');
      return;
    }

    try {
      _subscription = Supabase.instance.client
          .from('user_notifications:user_id=eq.$userId&is_deleted=eq.false')
          .stream(primaryKey: ['id']).listen(
        (List<Map<String, dynamic>> data) {
          try {
            if (data.isNotEmpty) {
              final newNotif = data.first;
              final notifData = newNotif['notifications'];
              if (notifData != null && newNotif['is_read'] == false) {
                // Convert UUID to int for notification ID
                final notificationId = newNotif['id'].hashCode & 0x7FFFFFFF;
                NotificationService.showNotification(
                  id: notificationId,
                  title: notifData['title'] ?? 'No title',
                  message: notifData['message'] ?? 'No message',
                  icon: notifData['icon'] ?? 'icon',
                  payload: notifData['redirect_to'],
                );

                // Mark as read
                Supabase.instance.client
                    .from('user_notifications')
                    .update({'is_read': true}).eq('id', newNotif['id']);

                // Refresh notification history
                fetchNotificationHistory();
              }
            }
          } catch (e, stackTrace) {
            debugPrint('Error in subscription callback: $e\n$stackTrace');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('Subscription error: $error\n$stackTrace');
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Error setting up subscription: $e\n$stackTrace');
    }
  }

  Future<void> fetchAndShowNotifications() async {
    final box = await _getHiveBox();
    const cacheKey = 'user_notifications';
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('No authenticated user found for fetching notifications');
      return;
    }

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from('user_notifications')
            .select('*, notifications(*)')
            .eq('user_id', userId)
            .eq('is_read', false)
            .eq('is_deleted', false);

        final List data = response;
        await box.put(cacheKey, data); // Save to cache

        for (var notif in data) {
          final notifData = notif['notifications'];
          if (notifData != null) {
            final notificationId = notif['id'].hashCode & 0x7FFFFFFF;
            await NotificationService.showNotification(
              id: notificationId,
              title: notifData['title'] ?? 'No title',
              message: notifData['message'] ?? 'No message',
              icon: notifData['icon'] ?? 'icon',
              payload: notifData['redirect_to'],
            );

            await Supabase.instance.client
                .from('user_notifications')
                .update({'is_read': true}).eq('id', notif['id']);
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error fetching notifications: $e\n$stackTrace');
        // Use cached data if fetching fails
        await _showCachedNotifications(box, cacheKey);
      }
    } else {
      // Offline: use cached notifications
      await _showCachedNotifications(box, cacheKey);
    }

    // Refresh notification history
    await fetchNotificationHistory();
  }

  Future<void> _showCachedNotifications(Box box, String cacheKey) async {
    try {
      final cachedData = box.get(cacheKey, defaultValue: []);
      for (var notif in cachedData) {
        final notifData = notif['notifications'];
        if (notifData != null && notif['is_deleted'] == false) {
          // Convert UUID to int for notification ID
          final notificationId = notif['id'].hashCode & 0x7FFFFFFF;
          await NotificationService.showNotification(
            id: notificationId,
            title: notifData['title'] ?? 'No title',
            message: notifData['message'] ?? 'No message',
            icon: notifData['icon'] ?? 'icon',
            payload: notifData['redirect_to'],
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error showing cached notifications: $e\n$stackTrace');
    }
  }

  Future<void> fetchNotificationHistory() async {
    final box = await _getHiveBox();
    const cacheKey = 'notification_history';
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('No authenticated user found for fetching history');
      return;
    }

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    if (isOnline) {
      try {
        final response = await Supabase.instance.client
            .from('user_notifications')
            .select('*, notifications(*)')
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('created_at', ascending: false);

        final history = List<Map<String, dynamic>>.from(response);
        await box.put(cacheKey, history); // Save to cache

        setState(() {
          _notifications = history;
        });
      } catch (e, stackTrace) {
        debugPrint('Error fetching notification history: $e\n$stackTrace');
        // Use cached history if fetching fails
        _loadCachedHistory(box, cacheKey);
      }
    } else {
      // Offline: use cached history
      _loadCachedHistory(box, cacheKey);
    }
  }

  void _loadCachedHistory(Box box, String cacheKey) {
    try {
      final cachedHistory = box.get(cacheKey, defaultValue: []);
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(
            cachedHistory.where((n) => n['is_deleted'] == false));
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading cached history: $e\n$stackTrace');
    }
  }

  Future<Box> _getHiveBox() async {
    try {
      return Hive.box('offline_data');
    } catch (e, stackTrace) {
      debugPrint('Error opening Hive box: $e\n$stackTrace');
      return await Hive.openBox('offline_data');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await Supabase.instance.client
          .from('user_notifications')
          .update({'is_deleted': true}).eq('id', id);

      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
    } catch (e, stackTrace) {
      debugPrint('Error deleting notification: $e\n$stackTrace');
    }
  }

  @override
  void dispose() {
    try {
      _subscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint('Error cancelling subscription: $e\n$stackTrace');
    }
    super.dispose();
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
              fontSize: 23,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
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
              const SizedBox(height: 10),
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
