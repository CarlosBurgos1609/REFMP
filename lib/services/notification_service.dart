import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    const androidInit = AndroidInitializationSettings('image');
    const initSettings = InitializationSettings(android: androidInit);

    _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(payload);
        }
      },
    );
  }

  static Future<void> showNotification({
    required int id,
    required String title, // Campo `name` desde Supabase
    required String message, // Campo `message` desde Supabase
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'default_channel_id',
      'Notificaciones',
      channelDescription: 'Canal para mostrar notificaciones',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'image',
      styleInformation: BigTextStyleInformation(
        '<font color="#757575">$message</font>', // Texto del mensaje en gris
        htmlFormatTitle: true,
        htmlFormatBigText: true,
        htmlFormatContent: true,
        contentTitle: '$title.', // Título en azul y negrita
        summaryText: 'Red de Escuelas de Formación Musical',
      ),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      '', // Título vacío para que lo tome desde `styleInformation`
      '',
      notificationDetails,
      payload: payload,
    );
  }
}
