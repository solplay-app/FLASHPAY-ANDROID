import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'support_screen.dart';
import 'theme.dart';

/// Écran 1 : numéro ivoirien → code SMS [FlashPay] → jeton stocké en local sécurisé.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false, _busy = false;

  Future<void> _send() async {
    final p = _phone.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(p)) return toast(context, 'Entrez votre numéro à 10 chiffres');
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).requestOtp(p);
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final token = await ref.read(repoProvider).verifyOtp(_phone.text.replaceAll(RegExp(r'\s'), ''), _code.text);
      await ref.read(authProvider.notifier).login(token);
    } catch (e) {
      if (mounted) {
        toast(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 48),
            const Text('FlashPay', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: brand)),
            const SizedBox(height: 8),
            const Text('Envoyez de l’argent entre Wave, Orange, MTN et Moov.'),
            const SizedBox(height: 40),
            TextField(
              controller: _phone,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(14)],
              decoration: const InputDecoration(labelText: 'Numéro de téléphone', prefixText: '+225  ', hintText: '07 00 00 00 00'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Code reçu par SMS', counterText: ''),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? (_code.text.length == 6 ? _verify : null) : _send),
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_codeSent ? 'Valider' : 'Recevoir le code'),
            ),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())), child: const Text('Besoin d’aide ?')),
            if (_codeSent) TextButton(onPressed: _busy ? null : () => setState(() { _codeSent = false; _code.clear(); }), child: const Text('Changer de numéro')),
          ]),
        ),
      );

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }
}
