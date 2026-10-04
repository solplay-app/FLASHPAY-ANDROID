import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../data/repository.dart';
import 'notifications.dart';

/// Notifications push (Firebase Cloud Messaging).
/// App fermée ou en arrière-plan : Android affiche la notification tout seul.
/// App ouverte : on relit simplement les données, la notification locale prend le relais (pas de doublon).
class Push {
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _msg;

  static Future<void> start(Repo repo, {required void Function() onMessage}) async {
    try {
      if (!await Notifier.enabled()) await Notifier.request(); // Android 13+ : demande d'autorisation
      final fm = FirebaseMessaging.instance;
      final token = await fm.getToken();
      if (token != null) await repo.registerPush(token);
      await _refresh?.cancel();
      _refresh = fm.onTokenRefresh.listen((t) => unawaited(repo.registerPush(t).catchError((_) {})));
      await _msg?.cancel();
      _msg = FirebaseMessaging.onMessage.listen((_) => onMessage());
    } catch (e) {
      debugPrint('Push non disponible : $e'); // Firebase non configuré, ou réseau absent : l'app continue normalement
    }
  }

  /// À la déconnexion : le jeton est supprimé sur le téléphone ; le serveur nettoie l'ancien au prochain envoi.
  static Future<void> stop() async {
    try {
      await _refresh?.cancel();
      await _msg?.cancel();
      _refresh = null;
      _msg = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
