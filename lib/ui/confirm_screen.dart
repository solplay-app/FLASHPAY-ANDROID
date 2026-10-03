import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import '../state/providers.dart';
import 'theme.dart';

/// Écran 4 : ticket de confirmation (montants calculés par le backend), paiement, puis suivi du statut.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.quote, required this.from, required this.to, required this.phone, this.cagnotteCode});
  final String? cagnotteCode;
  final Quote quote;
  final Op from, to;
  final String phone;
  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  // Une seule clé par ticket : si la requête est rejouée (réseau coupé, double clic), le backend ne débite qu'une fois.
  final _key = const Uuid().v4();
  Transfer? _tx;
  bool _busy = false;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return toast(context, 'Lien de paiement invalide');
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView) && mounted) toast(context, 'Impossible d’ouvrir la page de paiement');
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final tx = await ref.read(repoProvider).create(
            net: widget.quote.net, sender: widget.from, receiver: widget.to, phone: widget.phone, idempotencyKey: _key, cagnotteCode: widget.cagnotteCode);
      if (!mounted) return;
      setState(() => _tx = tx);
      if (tx.redirectUrl != null) await _open(tx.redirectUrl!);
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    } catch (e) {
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
        const SizedBox(height: 20),
        if (tx == null)
          FilledButton(
            onPressed: _busy ? null : _pay,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirmer et Payer'),
          )
        else
          _Status(tx: tx, onReopen: tx.redirectUrl == null ? null : () => _open(tx.redirectUrl!), onClose: () => Navigator.popUntil(context, (r) => r.isFirst)),
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
  const _Status({required this.tx, required this.onClose, this.onReopen});
  final Transfer tx;
  final VoidCallback onClose;
  final VoidCallback? onReopen;
  @override
  Widget build(BuildContext context) {
    final msg = switch (tx.etat) {
      'SUCCES' => 'Transfert réussi. Le destinataire a été crédité.',
      'ECHEC' => 'Le paiement n’a pas abouti. Rien n’a été débité.',
      'REMBOURSE' => 'Le transfert a échoué, vous avez été remboursé.',
      _ => 'Validez le paiement dans la page ouverte (ou sur votre téléphone). Nous suivons le statut automatiquement.',
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
