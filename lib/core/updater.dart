import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Numéro et nom de la version installée (donnés par la compilation GitHub).
const kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
const kBuildName = String.fromEnvironment('BUILD_NAME', defaultValue: 'dev');

const _repo = 'solplay-app/FLASHPAY-ANDROID';

/// Lien de téléchargement UNIQUE : pointe toujours vers la dernière version.
const kApkUrl = 'https://github.com/$_repo/releases/latest/download/flashpay.apk';
const _versionUrl = 'https://github.com/$_repo/releases/latest/download/version.json';

class AppVersion {
  AppVersion(this.code, this.name, this.notes);
  final int code;
  final String name, notes;
}

class Updater {
  static bool _checkedAtLaunch = false;

  /// Lit la dernière version publiée (null si impossible : pas de réseau, etc.).
  static Future<AppVersion?> latest() async {
    try {
      final r = await Dio()
          .get<String>(_versionUrl, options: Options(responseType: ResponseType.plain, headers: {'Cache-Control': 'no-cache'}))
          .timeout(const Duration(seconds: 15));
      final j = jsonDecode(r.data ?? '') as Map<String, dynamic>;
      return AppVersion(int.parse('${j['versionCode']}'), '${j['versionName']}', '${j['notes'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  /// Au lancement de l'application : propose la mise à jour s'il y en a une (une seule fois).
  static Future<void> checkOnLaunch(BuildContext context) async {
    if (_checkedAtLaunch) return;
    _checkedAtLaunch = true;
    final v = await latest();
    if (v == null || v.code <= kBuildNumber || !context.mounted) return;
    await _ask(context, v);
  }

  /// Depuis Compte > Mise à jour.
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Recherche de mise à jour…'), duration: Duration(seconds: 2)));
    final v = await latest();
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (v == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Impossible de vérifier. Vérifiez votre connexion.')));
    } else if (v.code <= kBuildNumber) {
      messenger.showSnackBar(SnackBar(content: Text('Vous avez la dernière version ($kBuildName).')));
    } else {
      await _ask(context, v);
    }
  }

  static Future<void> _ask(BuildContext context, AppVersion v) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle version disponible'),
        content: Text('Version ${v.name}${v.notes.isEmpty ? '' : '\n\n${v.notes}'}\n\nVos données sont conservées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) await _install(context);
  }

  /// Télécharge l'APK puis ouvre l'installation Android (la nouvelle version remplace l'ancienne).
  static Future<void> _install(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<int?>(null);
    var closed = false;
    void close() {
      if (!closed) {
        closed = true;
        nav.pop();
      }
    }

    Future<void> fallback() async {
      close();
      messenger.showSnackBar(const SnackBar(content: Text('Téléchargement dans le navigateur…')));
      await launchUrl(Uri.parse(kApkUrl), mode: LaunchMode.externalApplication);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Téléchargement'),
          content: ValueListenableBuilder<int?>(
            valueListenable: progress,
            builder: (_, p, __) => Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: p == null ? null : p / 100),
              const SizedBox(height: 12),
              Text(p == null ? 'Préparation…' : '$p %'),
            ]),
          ),
        ),
      ),
    );

    try {
      OtaUpdate().execute(kApkUrl, destinationFilename: 'flashpay.apk').listen(
        (e) {
          final s = e.status.name;
          if (s == 'DOWNLOADING') {
            progress.value = int.tryParse('${e.value}');
          } else if (s == 'INSTALLING') {
            close(); // l'écran d'installation d'Android s'ouvre : toucher « Installer »
          } else if (s.contains('ERROR') || s == 'CANCELED') {
            fallback();
          }
        },
        onError: (_) => fallback(),
      );
    } catch (_) {
      await fallback();
    }
  }
}

/// À placer autour de l'accueil : vérifie les mises à jour au lancement de l'application.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updater.checkOnLaunch(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
