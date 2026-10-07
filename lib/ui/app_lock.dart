import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/pin_service.dart';
import '../state/providers.dart';
import 'pin_screens.dart';
import 'theme.dart';

/// Temps passé hors de l'application au-delà duquel elle se verrouille.
const kLockDelay = Duration(minutes: 10);

/// Clé du navigateur principal : permet d'afficher l'écran de verrouillage PAR-DESSUS tout
/// (pages ouvertes, fenêtres, etc.) sans perdre l'endroit où l'utilisateur se trouvait.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Verrouille l'application :
///  - à chaque ouverture (démarrage à froid) ;
///  - quand l'utilisateur revient après plus de [kLockDelay] passées hors de l'application.
/// Placé DANS la barrière PIN : il n'est actif que si le compte a déjà un code PIN.
class AppLock extends ConsumerStatefulWidget {
  const AppLock({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AppLock> createState() => _AppLockState();
}

class _AppLockState extends ConsumerState<AppLock> with WidgetsBindingObserver {
  DateTime? _leftAt;
  Route<void>? _lockRoute;
  bool _cover = true; // cache l'application tant que l'écran de verrouillage n'est pas affiché (démarrage)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final skip = PinService.skipNextLock; // connexion ou création du PIN à l'instant : pas de verrou
    PinService.skipNextLock = false;
    if (skip) _cover = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!skip) _lock();
      setState(() => _cover = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _lockRoute;
    _lockRoute = null;
    if (route != null) {
      // Ex. déconnexion depuis l'écran de verrouillage : on retire l'écran une fois l'arbre mis à jour.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) rootNavigatorKey.currentState?.removeRoute(route);
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left == null) return;
      final away = DateTime.now().difference(left);
      // Horloge remise en arrière (durée négative) : on verrouille par prudence.
      if (away >= kLockDelay || away.isNegative) _lock();
    }
  }

  void _lock() {
    if (_lockRoute != null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    final route = MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => LockScreen(onUnlocked: _unlock));
    _lockRoute = route;
    nav.push(route);
  }

  void _unlock() {
    final route = _lockRoute;
    _lockRoute = null;
    if (route != null && route.isActive) rootNavigatorKey.currentState?.removeRoute(route);
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_cover) const Positioned.fill(child: ColoredBox(color: fpPaper)),
      ]);
}

/// Écran « FlashPay verrouillé » : empreinte (si activée) ou code PIN.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _bio = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final on = await PinService.biometricEnabled();
    if (!mounted) return;
    setState(() => _bio = on);
    if (on) await _tryBio();
  }

  Future<void> _tryBio() async {
    final pin = await PinService.unlockWithBiometric('Déverrouillez FlashPay');
    if (pin != null && mounted) widget.onUnlocked();
  }

  Future<void> _verify(String pin) async {
    if (mounted) setState(() => _error = null);
    try {
      await ref.read(repoProvider).verifyPin(pin); // le serveur vérifie toujours le PIN saisi
      if (mounted) widget.onUnlocked();
    } catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e).message);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter avec un code SMS.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false, // le bouton « retour » ne contourne pas le verrou
        child: Scaffold(
          backgroundColor: fpPaper,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 44, color: fpDeep),
                  const SizedBox(height: 10),
                  PinEntry(
                    title: 'FlashPay verrouillé',
                    subtitle: 'Entrez votre code PIN pour continuer',
                    error: _error,
                    onComplete: _verify,
                    footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PinResetScreen())),
                        child: const Text('Code oublié ?'),
                      ),
                      if (_bio) TextButton.icon(onPressed: _tryBio, icon: const Icon(Icons.fingerprint), label: const Text('Empreinte')),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _logout, child: const Text('Se déconnecter')),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Opération sensible sans transfert d'argent (créer / clôturer une cagnotte…) :
/// empreinte ou PIN, puis le serveur vérifie le PIN. true = autorisé.
Future<bool> confirmSensitive(BuildContext context, WidgetRef ref, String reason) async {
  final r = await askPin(context, reason: reason);
  if (r == null || !context.mounted) return false;
  try {
    await ref.read(repoProvider).verifyPin(r.pin);
    return true;
  } catch (e) {
    if (r.viaBiometric && e is ApiError && e.code == 'PIN_INVALIDE') await PinService.clearBiometric();
    if (context.mounted) toast(context, ApiError.from(e));
    return false;
  }
}
