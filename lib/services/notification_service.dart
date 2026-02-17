import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Handler para notificaciones en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
      '📩 [Background] Notificación recibida: ${message.notification?.title}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static Timer? _pollingTimer;
  static bool _isPollingActive = false;

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // Inicializar notificaciones locales
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(payload);
        }
      },
    );

    // Configurar Firebase Cloud Messaging
    await _initializeFirebaseMessaging(navigatorKey);
  }

  static Future<void> _initializeFirebaseMessaging(
      GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // Solicitar permisos para notificaciones
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permisos de notificaciones concedidos');
      } else {
        debugPrint('⚠️ Permisos de notificaciones denegados');
        return; // Salir si no hay permisos
      }

      // Obtener y guardar el token FCM (con manejo de errores)
      try {
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          debugPrint('🔑 FCM Token: $token');
          await _saveFCMToken(token);
        } else {
          debugPrint('⚠️ No se pudo obtener el token FCM');
        }

        // Escuchar cambios en el token
        _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);
      } catch (e) {
        debugPrint('⚠️ Error obteniendo token FCM: $e');
        debugPrint('ℹ️ La app funcionará sin notificaciones push remotas');
        // No lanzar el error, continuar con la inicialización
      }

      // Handler para notificaciones en segundo plano
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handler para notificaciones cuando la app está abierta
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            '📨 [Foreground] Notificación recibida: ${message.notification?.title}');

        if (message.notification != null) {
          showNotification(
            id: message.hashCode & 0x7FFFFFFF,
            title: message.notification!.title ?? 'Sin título',
            message: message.notification!.body ?? 'Sin mensaje',
            imageUrl: message.notification?.android?.imageUrl,
            payload: message.data['redirect_to'],
          );
        }
      });

      // Handler cuando se toca una notificación y la app estaba cerrada
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notificación tocada (app en segundo plano)');
        final redirectTo = message.data['redirect_to'];
        if (redirectTo != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed(redirectTo);
        }
      });

      // Verificar si la app se abrió desde una notificación
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🚀 App abierta desde notificación');
        final redirectTo = initialMessage.data['redirect_to'];
        if (redirectTo != null) {
          Future.delayed(const Duration(seconds: 1), () {
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushNamed(redirectTo);
            }
          });
        }
      }

      debugPrint('✅ Firebase Messaging inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error inicializando Firebase Messaging: $e');
      debugPrint('ℹ️ La app continuará funcionando con notificaciones locales');
      // No lanzar el error, permitir que la app continúe
    }
  }

  /// Guarda el token FCM en Supabase
  static Future<void> _saveFCMToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Guardar en una tabla de tokens (necesitas crear esta tabla)
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Token FCM guardado en Supabase');
    } catch (e) {
      debugPrint('❌ Error guardando token FCM: $e');
    }
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

  /// Verificar conectividad
  static Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si hay notificaciones nuevas
  static Future<void> _checkForNewNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('⚠️ No hay usuario autenticado para polling');
      return;
    }

    // Verificar conexión antes de intentar cargar
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      debugPrint('📱 Sin conexión, saltando polling de notificaciones');
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

  /// Envía notificaciones push a todos los usuarios después de crear contenido
  static Future<void> sendNotificationToAllUsers(int notificationId) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Obtener la notificación creada
      // ignore: unused_local_variable
      final notification = await supabase
          .from('notifications')
          .select()
          .eq('id', notificationId)
          .single();

      // 2. Obtener todos los tokens FCM activos
      final tokens = await supabase
          .from('fcm_tokens')
          .select('token, user_id')
          .not('token', 'is', null);

      if (tokens.isEmpty) {
        debugPrint('⚠️ No hay tokens FCM para enviar notificaciones');
        return;
      }

      // 3. Crear user_notifications para cada usuario
      final userNotifications = tokens
          .map((t) => {
                'user_id': t['user_id'],
                'notification_id': notificationId,
                'is_read': false,
                'is_deleted': false,
                'created_at': DateTime.now().toIso8601String(),
              })
          .toList();

      await supabase.from('user_notifications').insert(userNotifications);

      debugPrint('✅ Notificación enviada a ${tokens.length} usuarios');
    } catch (e) {
      debugPrint('❌ Error enviando notificaciones a usuarios: $e');
    }
  }
}
