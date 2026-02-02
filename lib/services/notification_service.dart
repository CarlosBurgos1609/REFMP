import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Timer? _pollingTimer;
  static bool _isPollingActive = false;

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

  /// Inicia el polling automático cada 30 segundos
  static void startPolling() {
    if (_isPollingActive) {
      debugPrint('⚠️ Polling ya está activo');
      return;
    }

    _isPollingActive = true;
    debugPrint('🔄 Iniciando polling de notificaciones cada 30 segundos');

    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkForNewNotifications();
    });
  }

  /// Detiene el polling automático
  static void stopPolling() {
    _pollingTimer?.cancel();
    _isPollingActive = false;
    debugPrint('⏹️ Polling de notificaciones detenido');
  }

  /// Verifica si hay notificaciones nuevas
  static Future<void> _checkForNewNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('⚠️ No hay usuario autenticado para polling');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('user_notifications')
          .select('*, notifications(*)')
          .eq('user_id', userId)
          .eq('is_read', false)
          .eq('is_deleted', false);

      if (response.isNotEmpty) {
        debugPrint(
            '📥 [Polling] Encontradas ${response.length} notificaciones nuevas');

        for (var notif in response) {
          final notifData = notif['notifications'];
          if (notifData != null) {
            final notificationId = notif['id'].hashCode & 0x7FFFFFFF;

            await showNotification(
              id: notificationId,
              title: notifData['title'] ?? 'No title',
              message: notifData['message'] ?? 'No message',
              icon: notifData['icon'] ?? 'icon',
              imageUrl: notifData['image'],
              payload: notifData['redirect_to'],
            );

            // Marcar como leída
            await Supabase.instance.client
                .from('user_notifications')
                .update({'is_read': true}).eq('id', notif['id']);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error en polling: $e');
    }
  }

  static Future<String?> _downloadAndSaveImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
    return null;
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
    String? bigPicturePath;

    // Descargar imagen si existe
    if (imageUrl != null && imageUrl.isNotEmpty) {
      bigPicturePath = await _downloadAndSaveImage(imageUrl);
    }

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'event_channel',
      'Notificaciones',
      channelDescription:
          'Notificaciones de eventos, sedes, instrumentos y objetos',
      importance: Importance.max,
      priority: Priority.high,
      icon: icon,
      subText: subText,
      largeIcon:
          bigPicturePath != null ? FilePathAndroidBitmap(bigPicturePath) : null,
      styleInformation: bigPicturePath != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(bigPicturePath),
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
