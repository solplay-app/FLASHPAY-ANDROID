import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import 'support_screen.dart';
import 'theme.dart';

const _violetFonce = Color(0xFF3F2A9E);
const _violetBouton1 = Color(0xFF4A2AA8);
const _violetBouton2 = Color(0xFF5A3BC6);
const _bordure = Color(0xFFE3DDF0);

/// Écran 1 : numéro ivoirien (+225) → code SMS [FlashPay] → jeton stocké en local sécurisé.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _numero => _phone.text.replaceAll(RegExp(r'\s'), '');

  Future<void> _send() async {
    if (!RegExp(r'^\d{10}$').hasMatch(_numero)) return toast(context, 'Entrez votre numéro à 10 chiffres');
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).requestOtp(_numero);
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
      final token = await ref.read(repoProvider).verifyOtp(_numero, _code.text);
      await ref.read(authProvider.notifier).login(token);
    } catch (e) {
      if (mounted) {
        toast(context, e);
        setState(() => _busy = false);
      }
    }
  }

  InputDecoration _champ(String label, {String? hint, Widget? prefix, bool flottant = false}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefix: prefix,
        counterText: '',
        floatingLabelBehavior: flottant ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(color: Color(0xFF4527A0), fontWeight: FontWeight.w600),
        labelStyle: const TextStyle(color: Color(0xFF7A748C)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _bordure)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _bordure)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _bordure)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _violetBouton2, width: 1.6)),
      );

  Widget _logo() => Row(children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [brand, Color(0xFF9B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x5522D3EE), blurRadius: 22, spreadRadius: 1)],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 14),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [_violetFonce, _violetBouton2]).createShader(r),
          child: const Text('FlashPay', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white)),
        ),
      ]);

  Widget _bouton() {
    final actif = !_busy && (_codeSent ? _code.text.length == 6 : true);
    return Opacity(
      opacity: actif ? 1 : .55,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_violetBouton1, _violetBouton2]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x554A2AA8), blurRadius: 22, offset: Offset(0, 10))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: actif ? (_codeSent ? _verify : _send) : null,
            child: Center(
              child: _busy
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_codeSent ? 'Valider' : 'Recevoir le code', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFE6E0F5),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFDCD2F2), Color(0xFFEFEBFA), Color(0xFFDDD4F0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 26),
                    decoration: BoxDecoration(
                      color: const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(38),
                      border: Border.all(color: const Color(0xFFC9BDEB), width: 1.2),
                      boxShadow: const [BoxShadow(color: Color(0x30573AB0), blurRadius: 46, offset: Offset(0, 20))],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _logo(),
                      const SizedBox(height: 18),
                      const Text('Envoyez de l’argent entre Wave, Orange, MTN et Moov.', style: TextStyle(fontSize: 17, height: 1.4, color: Color(0xFF3A4152))),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _phone,
                        enabled: !_codeSent,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 18, color: fpInk),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(14)],
                        decoration: _champ(
                          'Numéro de téléphone',
                          hint: '07 00 00 00 00',
                          flottant: true,
                          prefix: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Text('+225', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fpInk)),
                          ),
                        ),
                      ),
                      if (_codeSent) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, color: fpInk, letterSpacing: 2),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _champ('Code reçu par SMS'),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _bouton(),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
                        child: const Text('Besoin d’aide ?', style: TextStyle(fontSize: 17, color: Color(0xFF2E2478))),
                      ),
                      if (_codeSent)
                        TextButton(
                          onPressed: _busy ? null : () => setState(() { _codeSent = false; _code.clear(); }),
                          child: const Text('Changer de numéro', style: TextStyle(fontSize: 17, color: Color(0xFF2E2478))),
                        ),
                      const SizedBox(height: 6),
                      const Text('Connexion sécurisée · OTP par SMS', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, color: Color(0xFF9A96A8))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
