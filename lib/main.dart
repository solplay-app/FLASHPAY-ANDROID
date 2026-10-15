import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'core/notifications.dart';
import 'state/providers.dart';
import 'ui/app_lock.dart';
import 'ui/auth_screen.dart';
import 'ui/cgu_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase (App Check + notifications push ; le KYC est sur Cloudinary). Nécessite google-services.json / GoogleService-Info.plist.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: const bool.fromEnvironment('dart.vm.product') ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider: const bool.fromEnvironment('dart.vm.product') ? AppleProvider.deviceCheck : AppleProvider.debug,
    );
  } catch (e) {
    debugPrint('Firebase non configuré : $e');
  }
  await Notifier.init();
  runApp(const ProviderScope(child: FlashPayApp()));
}

class FlashPayApp extends ConsumerWidget {
  const FlashPayApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'FlashPay',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: appTheme,
      home: auth.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const AuthScreen(),
        // Session ouverte : CguGate interroge /me et bloque sur les CGU de la bêta tant
        // qu'elles ne sont pas acceptées ; sinon PinGate → AppLock → écran d'accueil.
        data: (s) => s == null ? const AuthScreen() : const CguGate(),
      ),
    );
  }
}
