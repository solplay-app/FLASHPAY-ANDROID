import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../data/me.dart';
import '../state/providers.dart';
import 'confirm_screen.dart';
import 'design.dart';
import 'kyc_screen.dart';
import 'operator_picker.dart';
import 'theme.dart';

/// Onglet « Actions » : transfert en 3 pages.
///  1. Compte à débiter (numéro modifiable) + réseau émetteur
///  2. Numéro du destinataire + son réseau
///  3. Montant
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});
  @override
  ConsumerState<TransferScreen> createState() => TransferScreenState();
}

class TransferScreenState extends ConsumerState<TransferScreen> {
  static const _steps = 3;
  static final _payerRe = RegExp(r'^(01|05|07)\d{8}$');
  final _pages = PageController();
  final _payerCtl = TextEditingController();
  final _payerFocus = FocusNode();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  Op? _from, _to;
  String _payer = ''; // numéro à débiter validé, au format +225…
  String? _defaultLocal; // numéro du compte FlashPay (10 chiffres)
  bool _payerEdited = false;
  bool _toManual = false; // l'utilisateur a corrigé le réseau détecté (ex. Wave)
  String _prefix = '';
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Le numéro du compte est proposé par défaut ; il reste modifiable.
    ref.read(meProvider.future).then((m) {
      if (!mounted) return;
      setState(() {
        _defaultLocal = m.local;
        if (!_payerEdited) _payerCtl.text = m.local;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _pages.dispose();
    _payerCtl.dispose();
    _payerFocus.dispose();
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Appelé par l'écran principal pour le bouton retour : true si la page a reculé.
  bool goBack() {
    if (_page > 0) {
      _go(_page - 1);
      return true;
    }
    return false;
  }

  void _back() {
    if (!goBack()) ShellActions.maybeOf(context)?.goTab(0);
  }

  void _go(int p) {
    FocusScope.of(context).unfocus();
    setState(() => _page = p);
    _pages.animateToPage(p, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _reset() {
    _phone.clear();
    _amount.clear();
    setState(() {
      _from = null;
      _to = null;
      _toManual = false;
      _prefix = '';
      _page = 0;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
    ref.invalidate(transfersProvider);
    ShellActions.maybeOf(context)?.goTab(0);
  }

  /// « +225 07 00 00 00 00 », « 0700000000 », « 00225… » → 10 chiffres.
  String _digits(String s) {
    var d = s.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00225')) d = d.substring(5);
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return d;
  }

  bool get _payerModified => _defaultLocal != null && _digits(_payerCtl.text) != _defaultLocal;

  /// Choix du réseau à débiter : on vérifie le numéro, puis on passe à la page suivante.
  Future<void> _pickSender(Op o) async {
    final d = _digits(_payerCtl.text);
    if (!_payerRe.hasMatch(d)) {
      toast(context, 'Numéro de compte invalide (10 chiffres, commençant par 01, 05 ou 07)');
      _payerFocus.requestFocus();
      return;
    }
    final det = detectOp(d);
    if (det != null && det != o && o.api != 'wave') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vérifiez le numéro'),
          content: Text('Le numéro $d ressemble à un numéro ${det.label}, mais vous avez choisi ${o.label}. '
              'Le numéro à débiter doit être celui de votre compte ${o.label}. Continuer quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Modifier')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _from = o;
      _payer = '+225$d';
    });
    FocusScope.of(context).unfocus();
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
    if (net == null || net < 300) return toast(context, 'Montant minimum : 300 F');
    setState(() => _busy = true);
    try {
      final q = await ref.read(repoProvider).quote(net);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConfirmScreen(quote: q, from: _from!, to: _to!, phone: _digits(_phone.text), payerPhone: _payer)),
      );
      if (mounted) _reset(); // retour du ticket : on repart d'un transfert vierge
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

  Widget _step(String title, List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: SoftCard(
          radius: 30,
          padding: const EdgeInsets.all(18),
          color: Colors.white.withOpacity(.88),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: Color(0xFF2E2D52))),
            const SizedBox(height: 18),
            ...children,
          ]),
        ),
      );

  InputDecoration _field({String? label, String? prefix, Widget? suffix, String? helper}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        suffixIcon: suffix,
        helperText: helper,
        filled: true,
        fillColor: const Color(0xFFECE9E4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB9B4C4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFB9B4C4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: brand, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final limits = ref.watch(limitsProvider).valueOrNull;
    return GradientBackdrop(
      dark: true,
      child: Column(children: [
        const HeaderBlock(dark: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 16, 12),
          child: Row(children: [
            IconButton(tooltip: 'Retour', onPressed: _back, icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28)),
            const SizedBox(width: 6),
            Text('Transfert · ${_page + 1}/$_steps', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w500)),
          ]),
        ),
        LinearProgressIndicator(
          value: (_page + 1) / _steps,
          minHeight: 4,
          backgroundColor: const Color(0xFFB8A6E6),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF2A0F55)),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(), // on avance uniquement via les choix / boutons
            children: [
              _step('Depuis quel réseau ?', [
                SoftCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_payerModified ? 'Numéro à débiter (modifié)' : 'Numéro de compte (par défaut)',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: fpInk)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _payerCtl,
                      focusNode: _payerFocus,
                      onChanged: (_) => setState(() => _payerEdited = true),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(18)],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      decoration: _field(
                        prefix: '+225 ',
                        suffix: IconButton(tooltip: 'Modifier le numéro', icon: const Icon(Icons.edit, color: Color(0xFF55506A)), onPressed: _payerFocus.requestFocus),
                      ),
                    ),
                    if (_payerModified)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            _payerCtl.text = _defaultLocal!;
                            _payerEdited = false;
                          }),
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Remettre mon numéro'),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                OperatorPicker(value: _from, onChanged: (o) => _pickSender(o)),
              ]),
              _step('Numéro du destinataire', [
                TextField(
                  controller: _phone,
                  onChanged: _onPhoneChanged,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(18)],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  decoration: _field(
                    label: 'Numéro',
                    prefix: '+225  ',
                    suffix: IconButton(icon: const Icon(Icons.contacts_outlined), onPressed: _pickContact, tooltip: 'Contacts'),
                  ),
                ),
                const SizedBox(height: 16),
                OperatorPicker(
                  value: _to,
                  onOpen: () => FocusScope.of(context).unfocus(),
                  onChanged: (o) => setState(() {
                    _to = o;
                    _toManual = true;
                  }),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _phoneNext, child: const Text('Continuer')),
              ]),
              _step('Quel montant ?', [
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: _field(
                    label: 'Montant',
                    helper: limits == null ? null : 'Max ${fcfa(limits.perTx)} · reste aujourd’hui ${fcfa(limits.dayLeft)}',
                  ).copyWith(suffixText: 'FCFA'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _quote,
                  child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Voir le récapitulatif'),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
