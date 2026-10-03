import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications locales (changement de statut d'un transfert).
/// Android 13+ : l'autorisation POST_NOTIFICATIONS est demandée à l'exécution via [request].
class Notifier {
  static final _p = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static Future<bool> enabled() async {
    try {
      if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
      if (Platform.isIOS) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    } catch (_) {}
    return false;
  }

  /// Affiche la boîte système d'autorisation (une seule fois si l'utilisateur refuse définitivement).
  static Future<bool> request() async {
    try {
      if (Platform.isAndroid) return await _android?.requestNotificationsPermission() ?? false;
      if (Platform.isIOS) return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (_) {}
    return false;
  }

  static Future<void> show(String title, String body) async {
    if (!await enabled()) return;
    await _p.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('transferts', 'Transferts', channelDescription: 'Statut de vos transferts', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
