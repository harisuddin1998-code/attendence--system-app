import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android does not show a system notification for an FCM message on its own while the app is in
/// the foreground - it only does that automatically when the app is backgrounded or closed. This
/// service catches foreground messages and shows a heads-up notification for them too, so
/// "you've been marked present" always appears the same way (like a WhatsApp message) no matter
/// whether the app is open or not.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    "attendance_channel",
    "Attendance alerts",
    description: "Notifies you when a teacher marks your attendance.",
    importance: Importance.max,
  );

  Future<void> init() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings("@mipmap/ic_launcher")),
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: "@mipmap/ic_launcher",
        ),
      ),
    );
  }
}
