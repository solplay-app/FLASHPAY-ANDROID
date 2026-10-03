import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../state/providers.dart';
import 'confirm_screen.dart';
import 'kyc_screen.dart';
import 'operator_picker.dart';
import 'theme.dart';

/// Écran 3 en 4 pages, sans défilement vertical : réseau émetteur → réseau bénéficiaire → numéro → montant.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});
  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  static const _steps = 3;
  final _pages = PageController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  Op? _from, _to;
  bool _toManual = false; // l'utilisateur a corrigé le réseau détecté (ex. Wave)
  String _prefix = '';
  int _page = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int p) {
    FocusScope.of(context).unfocus();
    setState(() => _page = p);
    _pages.animateToPage(p, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _pickSender(Op o) {
    setState(() => _from = o);
    // Choix fait : on passe tout de suite à la page suivante.
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _page == 0) _go(1);
    });
  }

  /// À chaque frappe : réseau du destinataire déduit du préfixe (01 Moov, 05 MTN, 07 Orange).
  /// Une correction manuelle est conservée tant que le préfixe ne change pas.
  void _onPhoneChanged([String? _]) {
    final d = _digits(_phone.text);
    final p = d.length >= 2 ? d.substring(0, 2) : '';
    if (p != _prefix) {
      _prefix = p;
      _toManual = false;
    }
    setState(() {
      if (!_toManual) _to = detectOp(d);
    });
  }

  /// « +225 07 00 00 00 00 », « 0700000000 », « 00225… » → 10 chiffres.
  String _digits(String s) {
    var d = s.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00225')) d = d.substring(5);
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return d;
  }

  Future<void> _pickContact() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) return toast(context, 'Autorisez l’accès aux contacts dans les réglages');
      final c = await FlutterContacts.openExternalPick();
      if (c == null || c.phones.isEmpty) return;
      _phone.text = _digits(c.phones.first.number);
      _onPhoneChanged();
    } catch (_) {
      if (mounted) toast(context, 'Impossible d’ouvrir les contacts');
    }
  }

  void _phoneNext() {
    if (_digits(_phone.text).length != 10) return toast(context, 'Numéro invalide (10 chiffres)');
    if (_to == null) return toast(context, 'Réseau non reconnu : choisissez-le dans la liste');
    _go(2);
  }

  Future<void> _quote() async {
    final net = int.tryParse(_amount.text);
    if (net == null || net < 500) return toast(context, 'Montant minimum : 500 F');
    setState(() => _busy = true);
    try {
      final q = await ref.read(repoProvider).quote(net);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmScreen(quote: q, from: _from!, to: _to!, phone: _digits(_phone.text))));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'KYC_REQUIRED') {
        _kycDialog(e.message);
      } else if (e.code?.startsWith('LIMIT_') ?? false) {
        toast(context, '${e.message} Reste disponible : ${fcfa(e.data?['restant'] ?? 0)}.');
      } else {
        toast(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _kycDialog(String msg) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vérification requise'),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen()));
              },
              child: const Text('Vérifier mon identité'),
            ),
          ],
        ),
      );

  Widget _step(String title, String? subtitle, List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(height: 24),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final limits = ref.watch(limitsProvider).valueOrNull;
    return PopScope(
      canPop: _page == 0,
      onPopInvoked: (didPop) {
        if (!didPop) _go(_page - 1); // retour = page précédente, pas sortie de l'écran
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Transfert · ${_page + 1}/$_steps'),
          leading: BackButton(onPressed: () => _page == 0 ? Navigator.pop(context) : _go(_page - 1)),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(4), child: LinearProgressIndicator(value: (_page + 1) / _steps, minHeight: 4)),
        ),
        body: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(), // on avance uniquement via les choix / boutons
          children: [
            _step('Depuis quel réseau ?', 'Le compte qui sera débité.', [OperatorPicker(value: _from, onChanged: (o) => _pickSender(o))]),
            _step('Numéro du destinataire', 'Le réseau est détecté automatiquement.', [
              TextField(
                controller: _phone,
                onChanged: _onPhoneChanged,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(18)],
                decoration: InputDecoration(
                  labelText: 'Numéro',
                  prefixText: '+225  ',
                  suffixIcon: IconButton(icon: const Icon(Icons.contacts_outlined), onPressed: _pickContact, tooltip: 'Contacts'),
                ),
              ),
              const SizedBox(height: 16),
              OperatorPicker(
                value: _to,
                startOpen: false,
                hint: _prefix.length < 2 ? 'Réseau du destinataire' : 'Réseau non reconnu · choisir',
                onOpen: () => FocusScope.of(context).unfocus(),
                onChanged: (o) => setState(() {
                  _to = o;
                  _toManual = true;
                }),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('01 → Moov · 05 → MTN · 07 → Orange. Pour un compte Wave, choisissez Wave dans la liste.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _phoneNext, child: const Text('Continuer')),
            ]),
            _step('Quel montant ?', 'Ce que le destinataire reçoit.', [
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                autofocus: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                decoration: InputDecoration(
                  labelText: 'Montant',
                  suffixText: 'FCFA',
                  helperText: limits == null ? null : 'Max ${fcfa(limits.perTx)} · reste aujourd’hui ${fcfa(limits.dayLeft)}',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _quote,
                child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Voir le récapitulatif'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
