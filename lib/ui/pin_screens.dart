import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/pin_service.dart';
import '../data/me.dart';
import '../data/repository.dart';
import '../state/providers.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Clavier + points du code PIN
// ---------------------------------------------------------------------------

/// Saisie du PIN : points + clavier numérique maison (pas de clavier Android, rien n'est mémorisé par le clavier).
/// Quand les [kPinLength] chiffres sont saisis, appelle [onComplete] puis efface la saisie.
class PinEntry extends StatefulWidget {
  const PinEntry({super.key, required this.title, required this.onComplete, this.subtitle, this.error, this.footer});
  final String title;
  final String? subtitle;
  final String? error;
  final Widget? footer;
  final Future<void> Function(String pin) onComplete;
  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  String _v = '';
  bool _busy = false;

  Future<void> _add(String d) async {
    if (_busy || _v.length >= kPinLength) return;
    setState(() => _v += d);
    if (_v.length == kPinLength) {
      final pin = _v;
      setState(() => _busy = true);
      try {
        await widget.onComplete(pin);
      } catch (e) {
        debugPrint('PinEntry : $e');
      } finally {
        if (mounted) {
          setState(() {
            _v = '';
            _busy = false;
          });
        }
      }
    }
  }

  void _del() {
    if (_busy || _v.isEmpty) return;
    setState(() => _v = _v.substring(0, _v.length - 1));
  }

  Widget _key(String d) => SizedBox(
        width: 84,
        height: 64,
        child: TextButton(
          onPressed: _busy ? null : () => _add(d),
          style: TextButton.styleFrom(foregroundColor: fpInk, shape: const CircleBorder()),
          child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _row(List<String> digits) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final d in digits) _key(d)]);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: fpInk)),
      if (widget.subtitle != null) ...[
        const SizedBox(height: 6),
        Text(widget.subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: fpMute)),
      ],
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < kPinLength; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _v.length ? brand : Colors.transparent,
              border: Border.all(color: i < _v.length ? brand : fpMute, width: 1.6),
            ),
          ),
      ]),
      SizedBox(
        height: 40,
        child: Center(
          child: widget.error == null
              ? (_busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null)
              : Text(widget.error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w600)),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(children: [
          _row(['1', '2', '3']),
          _row(['4', '5', '6']),
          _row(['7', '8', '9']),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            const SizedBox(width: 84, height: 64),
            _key('0'),
            SizedBox(
              width: 84,
              height: 64,
              child: IconButton(onPressed: _busy ? null : _del, icon: const Icon(Icons.backspace_outlined), color: fpInk),
            ),
          ]),
        ]),
      ),
      if (widget.footer != null) ...[const SizedBox(height: 8), widget.footer!],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Création du PIN en deux saisies (nouveau + confirmation)
// ---------------------------------------------------------------------------

class NewPinFlow extends StatefulWidget {
  const NewPinFlow({super.key, required this.title, required this.onSubmit, this.subtitle});
  final String title;
  final String? subtitle;

  /// Reçoit le PIN confirmé. Renvoie null si tout va bien, sinon le message d'erreur à afficher.
  final Future<String?> Function(String pin) onSubmit;
  @override
  State<NewPinFlow> createState() => _NewPinFlowState();
}

class _NewPinFlowState extends State<NewPinFlow> {
  String? _first;
  String? _error;

  Future<void> _done(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'Les deux codes ne correspondent pas. Recommencez.';
      });
      return;
    }
    final err = await widget.onSubmit(pin);
    if (err != null && mounted) {
      setState(() {
        _first = null;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PinEntry(
        title: _first == null ? widget.title : 'Confirmez votre code PIN',
        subtitle: _first == null ? (widget.subtitle ?? '$kPinLength chiffres, faciles à retenir mais pas évidents.') : 'Saisissez-le une seconde fois.',
        error: _error,
        onComplete: _done,
      );
}

/// Écran obligatoire à la première connexion : pas de PIN = pas de transaction possible.
class PinSetupScreen extends ConsumerWidget {
  const PinSetupScreen({super.key, this.onDone});
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const FlashPayLogo(size: 30),
            actions: [TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Se déconnecter'))],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: NewPinFlow(
                  title: 'Créez votre code PIN',
                  subtitle: 'Il sera demandé avant chaque transaction, pour protéger votre argent.',
                  onSubmit: (pin) async {
                    try {
                      await ref.read(repoProvider).setPin(pin);
                    } catch (e) {
                      final err = ApiError.from(e);
                      if (err.code != 'PIN_EXISTE') return err.message;
                    }
                    if (context.mounted && await PinService.biometricAvailable()) {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Utiliser l’empreinte digitale ?'),
                          content: const Text('Vous pourrez confirmer vos transactions avec votre empreinte au lieu de saisir le code.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Plus tard')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Activer')),
                          ],
                        ),
                      );
                      if (yes == true) await PinService.enableBiometric(pin);
                    }
                    onDone?.call();
                    return null;
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

/// Barrière : tant que le compte n'a pas de PIN, on n'affiche pas l'application.
class PinGate extends ConsumerStatefulWidget {
  const PinGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PinGate> createState() => _PinGateState();
}

class _PinGateState extends ConsumerState<PinGate> {
  late Future<PinStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = ref.read(repoProvider).pinStatus();
  }

  void _reload() => setState(() => _status = ref.read(repoProvider).pinStatus());

  @override
  Widget build(BuildContext context) => FutureBuilder<PinStatus>(
        future: _status,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            final msg = snap.error is ApiError ? (snap.error as ApiError).message : 'Connexion impossible. Vérifiez votre réseau.';
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_off, size: 56, color: fpMute),
                    const SizedBox(height: 12),
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _reload, child: const Text('Réessayer')),
                    TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Se déconnecter')),
                  ]),
                ),
              ),
            );
          }
          if (snap.data!.defini) return widget.child;
          return PinSetupScreen(onDone: _reload);
        },
      );
}

// ---------------------------------------------------------------------------
// Demande du PIN (ou de l'empreinte) avant une transaction
// ---------------------------------------------------------------------------

class PinResult {
  PinResult(this.pin, this.viaBiometric);
  final String pin;
  final bool viaBiometric;
}

/// Empreinte d'abord (si activée), sinon feuille de saisie du PIN. Renvoie null si l'utilisateur annule.
Future<PinResult?> askPin(BuildContext context, {required String reason, bool allowBiometric = true}) async {
  if (allowBiometric) {
    final pin = await PinService.unlockWithBiometric(reason);
    if (pin != null) return PinResult(pin, true);
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<PinResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: fpPaper,
    builder: (_) => _PinSheet(reason: reason, allowBiometric: allowBiometric),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.reason, required this.allowBiometric});
  final String reason;
  final bool allowBiometric;
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    if (widget.allowBiometric) {
      PinService.biometricEnabled().then((v) {
        if (mounted) setState(() => _bio = v);
      });
    }
  }

  Future<void> _retryBio() async {
    final pin = await PinService.unlockWithBiometric(widget.reason);
    if (pin != null && mounted) Navigator.pop(context, PinResult(pin, true));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: PinEntry(
            title: 'Code PIN',
            subtitle: widget.reason,
            onComplete: (pin) async => Navigator.pop(context, PinResult(pin, false)),
            footer: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => const PinResetScreen()));
                },
                child: const Text('Code oublié ?'),
              ),
              if (_bio) TextButton.icon(onPressed: _retryBio, icon: const Icon(Icons.fingerprint), label: const Text('Empreinte')),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Réglages : changer le PIN, empreinte, PIN oublié
// ---------------------------------------------------------------------------

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _available = false, _enabled = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await PinService.biometricAvailable();
    final e = await PinService.biometricEnabled();
    if (mounted) {
      setState(() {
        _available = a;
        _enabled = e;
        _loaded = true;
      });
    }
  }

  Future<void> _toggleBio(bool on) async {
    if (!on) {
      await PinService.clearBiometric();
      return _load();
    }
    final r = await askPin(context, reason: 'Entrez votre code PIN pour activer l’empreinte', allowBiometric: false);
    if (r == null || !mounted) return;
    try {
      await ref.read(repoProvider).verifyPin(r.pin);
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e));
      return;
    }
    final ok = await PinService.enableBiometric(r.pin);
    if (!ok && mounted) toast(context, 'Empreinte non confirmée. Réessayez.');
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sécurité')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.pin_outlined, color: fpDeep),
              title: const Text('Changer mon code PIN', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinChangeScreen())),
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: fpDeep),
              title: const Text('Empreinte digitale', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_loaded && !_available ? 'Aucune empreinte enregistrée sur ce téléphone' : 'Confirmer les transactions avec l’empreinte'),
              value: _enabled,
              onChanged: (_loaded && _available) ? _toggleBio : null,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: fpDeep),
              title: const Text('Code PIN oublié', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Le définir à nouveau avec un code SMS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PinResetScreen())),
            ),
          ),
        ]),
      );
}

class PinChangeScreen extends ConsumerStatefulWidget {
  const PinChangeScreen({super.key});
  @override
  ConsumerState<PinChangeScreen> createState() => _PinChangeScreenState();
}

class _PinChangeScreenState extends ConsumerState<PinChangeScreen> {
  String? _old;
  String? _error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Changer mon code PIN')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _old == null
                  ? PinEntry(
                      title: 'Code PIN actuel',
                      error: _error,
                      onComplete: (pin) async {
                        try {
                          await ref.read(repoProvider).verifyPin(pin);
                          if (mounted) setState(() => _old = pin);
                        } catch (e) {
                          if (mounted) setState(() => _error = ApiError.from(e).message);
                        }
                      },
                    )
                  : NewPinFlow(
                      title: 'Nouveau code PIN',
                      onSubmit: (nouveau) async {
                        try {
                          await ref.read(repoProvider).changePin(_old!, nouveau);
                        } catch (e) {
                          return ApiError.from(e).message;
                        }
                        await PinService.updateBiometricPin(nouveau);
                        if (mounted) {
                          toast(context, 'Code PIN modifié');
                          Navigator.pop(context);
                        }
                        return null;
                      },
                    ),
            ),
          ),
        ),
      );
}

/// PIN oublié : code SMS envoyé au numéro du compte, puis nouveau PIN.
class PinResetScreen extends ConsumerStatefulWidget {
  const PinResetScreen({super.key});
  @override
  ConsumerState<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends ConsumerState<PinResetScreen> {
  final _code = TextEditingController();
  int _step = 0; // 0 = envoyer le SMS, 1 = saisir le code SMS, 2 = nouveau PIN
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendSms() async {
    setState(() => _busy = true);
    try {
      final me = await ref.read(meProvider.future);
      await ref.read(repoProvider).requestOtp(me.local);
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) toast(context, ApiError.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Code PIN oublié')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: switch (_step) {
                0 => Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.sms_outlined, size: 56, color: fpDeep),
                    const SizedBox(height: 12),
                    const Text('Nous allons envoyer un code SMS au numéro de votre compte pour vous permettre de choisir un nouveau code PIN.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _sendSms,
                      child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Recevoir le code SMS'),
                    ),
                  ]),
                1 => Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'Code reçu par SMS', counterText: ''),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: RegExp(r'^\d{6}$').hasMatch(_code.text) ? () => setState(() => _step = 2) : null, child: const Text('Continuer')),
                  ]),
                _ => NewPinFlow(
                    title: 'Nouveau code PIN',
                    onSubmit: (nouveau) async {
                      try {
                        await ref.read(repoProvider).resetPin(_code.text, nouveau);
                      } catch (e) {
                        final err = ApiError.from(e);
                        if (err.code == 'OTP_INVALIDE' && mounted) setState(() => _step = 1); // mauvais code SMS : on le ressaisit
                        return err.message;
                      }
                      await PinService.updateBiometricPin(nouveau);
                      if (mounted) {
                        toast(context, 'Nouveau code PIN enregistré');
                        Navigator.pop(context);
                      }
                      return null;
                    },
                  ),
              },
            ),
          ),
        ),
      );
}
