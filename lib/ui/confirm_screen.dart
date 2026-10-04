import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/pin_service.dart';
import '../data/me.dart';
import '../state/providers.dart';
import 'pin_screens.dart';
import 'theme.dart';

/// Écran 4 : ticket de confirmation (montants calculés par le backend), paiement, puis suivi du statut.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.quote, required this.from, required this.to, required this.phone, this.cagnotteCode, this.payerPhone});
  final String? cagnotteCode;
  final String? payerPhone; // numéro à débiter choisi à l'étape 1 (reste modifiable ici)
  final Quote quote;
  final Op from, to;
  final String phone;
  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  // Une seule clé par ticket : si la requête est rejouée (réseau coupé, double clic), le backend ne débite qu'une fois.
  final _key = const Uuid().v4();
  final _payer = TextEditingController();
  Transfer? _tx;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final p = widget.payerPhone;
    if (p != null && p.isNotEmpty) {
      _payer.text = p.replaceFirst('+225', '');
    } else {
      // Cagnotte : on propose le numéro du compte.
      ref.read(meProvider.future).then((m) {
        if (mounted && _payer.text.isEmpty) _payer.text = m.local;
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _payer.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return toast(context, 'Lien de paiement invalide');
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView) && mounted) toast(context, 'Impossible d’ouvrir la page de paiement');
  }

  /// « 07 00 00 00 00 », « +225 07… » → +225 + 10 chiffres (préfixe 01, 05 ou 07), sinon null.
  String? get _payerPhone {
    var d = _payer.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return RegExp(r'^(01|05|07)\d{8}$').hasMatch(d) ? '+225$d' : null;
  }

  Future<void> _pay() async {
    final payer = _payerPhone;
    if (payer == null) return toast(context, 'Numéro à débiter invalide (10 chiffres, commençant par 01, 05 ou 07)');
    // Code PIN (ou empreinte) obligatoire avant toute transaction ; le serveur le revérifie.
    final pin = await askPin(context, reason: 'Confirmez le transfert de ${fcfa(widget.quote.total)}');
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final tx = await ref.read(repoProvider).create(
            net: widget.quote.net, sender: widget.from, receiver: widget.to, phone: widget.phone, payerPhone: payer, idempotencyKey: _key, cagnotteCode: widget.cagnotteCode, pin: pin.pin);
      if (!mounted) return;
      setState(() => _tx = tx);
      if (tx.redirectUrl != null) await _open(tx.redirectUrl!);
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    } catch (e) {
      // Le PIN mémorisé par l'empreinte n'est plus le bon (changé ailleurs) : on désactive l'empreinte.
      if (pin.viaBiometric && e is ApiError && e.code == 'PIN_INVALIDE') await PinService.clearBiometric();
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_tx == null) return;
    try {
      final t = await ref.read(repoProvider).transfer(_tx!.id);
      if (!mounted) return;
      setState(() => _tx = t);
      if (t.done) _poll?.cancel();
    } catch (_) {/* on réessaie au prochain tour */}
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final tx = _tx;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation'), automaticallyImplyLeading: tx == null),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _line('De', widget.from.label),
              _line('Vers', '${widget.to.label} · ${widget.phone}'),
              const Divider(height: 28),
              _line('Montant souhaité', fcfa(q.net)),
              _line('Frais de service (6 %)', fcfa(q.fee)),
              const Divider(height: 28),
              _line('Total qui sera retiré', fcfa(q.total), bold: true),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _payer,
          enabled: tx == null,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(18)],
          decoration: const InputDecoration(labelText: 'Numéro à débiter', prefixText: '+225  '),
        ),
        const SizedBox(height: 20),
        if (tx == null)
          FilledButton(
            onPressed: _busy ? null : _pay,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirmer et Payer'),
          )
        else
          _Status(tx: tx, ussd: widget.from == Op.mtn || widget.from == Op.moov, onReopen: tx.redirectUrl == null ? null : () => _open(tx.redirectUrl!), onClose: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ]),
    );
  }

  Widget _line(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 18 : 14))),
        ]),
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.tx, required this.onClose, this.onReopen, this.ussd = false});
  final Transfer tx;
  final bool ussd; // MTN / Moov : confirmation par code sur le téléphone, pas de page
  final VoidCallback onClose;
  final VoidCallback? onReopen;
  @override
  Widget build(BuildContext context) {
    final msg = switch (tx.etat) {
      'SUCCES' => 'Transfert réussi. Le destinataire a été crédité.',
      'ECHEC' => 'Le paiement n’a pas abouti. Rien n’a été débité.',
      'REMBOURSE' => 'Le transfert a échoué, vous avez été remboursé.',
      _ => ussd
          ? 'Validez la demande de code reçue sur votre téléphone. Nous suivons le statut automatiquement.'
          : 'Validez le paiement dans la page ouverte (ou sur votre téléphone). Nous suivons le statut automatiquement.',
    };
    return Column(children: [
      Icon(tx.done ? (tx.etat == 'SUCCES' ? Icons.check_circle : Icons.cancel) : Icons.hourglass_top, size: 64, color: tx.color),
      const SizedBox(height: 8),
      Text(tx.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tx.color)),
      const SizedBox(height: 8),
      Text(msg, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      if (!tx.done && onReopen != null) OutlinedButton(onPressed: onReopen, child: const Text('Rouvrir la page de paiement')),
      if (tx.done) FilledButton(onPressed: onClose, child: const Text('Terminer')),
    ]);
  }
}
