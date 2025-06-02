import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher'); // usa el ícono existente
    const initSettings = InitializationSettings(android: androidInit);

    flutterLocalNotificationsPlugin.initialize(
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
    required String title,
    required String message,
    String icon = '@mipmap/ic_launcher', // usa el ícono existente
    String? imageUrl,
    String? payload,
    String subText = 'Red de Escuelas de Formación Musical de Pasto',
  }) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'event_channel',
      'Eventos',
      channelDescription: 'Notificaciones de eventos musicales',
      importance: Importance.max,
      priority: Priority.high,
      icon: icon,
      subText: subText,
      styleInformation: imageUrl != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(imageUrl),
              contentTitle: title,
              summaryText: message,
              htmlFormatContent: true,
              htmlFormatTitle: true,
            )
          : BigTextStyleInformation(
              message,
              contentTitle: title,
              summaryText: subText,
              htmlFormatContent: true,
              htmlFormatBigText: true,
            ),
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      message,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
