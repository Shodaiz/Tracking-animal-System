import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'local_db_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'dzcheptel_channel',
      'DZcheptel Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );

    // Sauvegarder dans la base locale
    await LocalDbService.addNotification(title, body);
  }

  static Future<void> showSyncComplete(int count) async {
    await show(
      title: '✅ Synchronisation terminée',
      body: '$count action(s) synchronisée(s) avec succès',
      id: 1,
    );
  }

  static Future<void> showAnimalAlert(String rfid, String message) async {
    await show(
      title: '⚠️ Alerte Animal',
      body: 'Animal $rfid : $message',
      id: 2,
    );
  }
}