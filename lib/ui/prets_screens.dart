import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/pin_service.dart';
import '../core/prets_models.dart';
import '../data/me.dart';
import '../state/prets_provider.dart';
import '../state/providers.dart';
import 'design.dart';
import 'pin_screens.dart';
import 'theme.dart';

String _jour(DateTime? d) => d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _messageErreur(Object e) {
  if (e is ApiError) {
    switch (e.code) {
      case 'PRET_FERME':
        return 'Les prêts sont momentanément fermés.';
      case 'KYC_REQUIRED':
        return 'Votre identité doit d’abord être vérifiée.';
      case 'OFFRE_INVALIDE':
        return 'Cette offre n’est plus disponible.';
      case 'PRET_EN_COURS':
        return 'Vous avez déjà un prêt en cours.';
      case 'PRET_IMPAYE':
        return 'Un prêt précédent reste à régler.';
      case 'MONTANT_INVALIDE':
        return 'Montant non autorisé pour cette offre.';
      case 'REMBOURSEMENT_EN_COURS':
        return 'Un paiement est déjà en cours. Patientez un instant.';
    }
  }
  return e is ApiError ? e.message : 'Une erreur est survenue.';
}

// ---------------------------------------------------------------------------
// Bouton de l'accueil : visible seulement s'il y a une offre pour moi ou un prêt en cours.
// ---------------------------------------------------------------------------
class PretsHomeButton extends ConsumerWidget {
  const PretsHomeButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(pretsProvider).maybeWhen(data: (d) => d, orElse: () => null);
    if (d == null || !d.visible) return const SizedBox.shrink();
    final label = d.pret != null ? 'Mon prêt' : 'Prêt disponible pour vous';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: BigButton(
        label: label,
        icon: Icons.account_balance_wallet_outlined,
        dark: false,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PretsScreen())).then((_) => ref.invalidate(pretsProvider)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran principal
// ---------------------------------------------------------------------------
class PretsScreen extends ConsumerWidget {
  const PretsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(pretsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Petit prêt')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(pretsProvider.future),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(24), children: [Text(_messageErreur(e))]),
          data: (d) => ListView(padding: const EdgeInsets.all(16), children: [
            if (d.pret != null) _PretCard(d.pret!),
            if (d.pret == null && d.ouvert && d.offre != null) _OffreCard(d.offre!),
            if (d.pret == null && d.offre == null)
              const SoftCard(child: Text('Aucune offre de prêt pour le moment. Nous vous prévenons dès qu’une offre est disponible pour vous.')),
            if (d.historique.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text('Historique', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              for (final p in d.historique)
                SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Text(fcfa(p.montant), style: const TextStyle(fontWeight: FontWeight.w700))),
                    StatusChip(label: _libelle(p), color: p.statut == 'REMBOURSE' ? const Color(0xFF1E9E5A) : fpMute),
                  ]),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

String _libelle(Pret p) => switch (p.statut) {
      'REMBOURSE' => 'Remboursé',
      'PERDU' => 'Non remboursé',
      'ANNULE' => 'Annulé',
      'EN_RETARD' => 'En retard',
      'EN_COURS' => 'En cours',
      _ => 'Versement en cours',
    };

// ---------------------------------------------------------------------------
// Offre : choix du montant, du réseau de réception, PIN.
// ---------------------------------------------------------------------------
class _OffreCard extends ConsumerStatefulWidget {
  const _OffreCard(this.offre);
  final Offre offre;
  @override
  ConsumerState<_OffreCard> createState() => _OffreCardState();
}

class _OffreCardState extends ConsumerState<_OffreCard> {
  // Une clé par ouverture : une requête rejouée ne crée jamais deux prêts.
  final _key = const Uuid().v4();
  Choix? _choix;
  Op? _op;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.offre;
    if (o.choix.isNotEmpty) _choix = o.choix.last;
    ref.read(meProvider.future).then((m) {
      if (mounted && _op == null) setState(() => _op = detectOp(m.local) ?? Op.wave);
    }).catchError((_) {});
  }

  Future<void> _accepter() async {
    final c = _choix, op = _op;
    if (c == null || op == null) return;
    final pin = await askPin(context, reason: 'Confirmez le prêt de ${fcfa(c.montant)}');
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).accepterPret(offreId: widget.offre.id, montant: c.montant, op: op, idempotencyKey: _key, pin: pin.pin);
      ref.invalidate(pretsProvider);
      if (mounted) toast(context, 'Prêt accepté. Le versement arrive sur votre compte.');
    } catch (e) {
      if (pin.viaBiometric && e is ApiError && e.code == 'PIN_INVALIDE') await PinService.clearBiometric();
      if (mounted) toast(context, _messageErreur(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offre;
    final c = _choix;
    final me = ref.watch(meProvider).maybeWhen(data: (m) => m, orElse: () => null);
    final mismatch = me != null && _op != null && _op != Op.wave && detectOp(me.local) != _op;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Une offre pour vous', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        Text('Jusqu’à ${fcfa(o.montantMax)} · remboursement en ${o.dureeJours} jours'
            '${o.expireLe != null ? ' · valable jusqu’au ${_jour(o.expireLe)}' : ''}'),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final x in o.choix)
            ChoiceChip(label: Text(fcfa(x.montant)), selected: c?.montant == x.montant, onSelected: _busy ? null : (_) => setState(() => _choix = x)),
        ]),
        if (c != null) ...[
          const SizedBox(height: 14),
          _ligne('Vous recevez', fcfa(c.montant)),
          _ligne('Frais', fcfa(c.frais)),
          const Divider(height: 24),
          _ligne('À rembourser dans ${o.dureeJours} jours', fcfa(c.totalDu), bold: true),
        ],
        const SizedBox(height: 14),
        const Text('Recevoir sur le numéro de votre compte :'),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final op in Op.values) ChoiceChip(label: Text(op.label), selected: _op == op, onSelected: _busy ? null : (_) => setState(() => _op = op)),
        ]),
        if (mismatch)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ce réseau ne correspond pas au numéro de votre compte : vérifiez avant de continuer.', style: TextStyle(color: Colors.orange)),
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy || c == null || _op == null ? null : _accepter,
          child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Accepter le prêt'),
        ),
        const SizedBox(height: 8),
        const Text('Empruntez seulement ce que vous pouvez rembourser à la date prévue.', style: TextStyle(color: fpMute, fontSize: 12)),
      ]),
    );
  }
}

Widget _ligne(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(a)),
        Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );

// ---------------------------------------------------------------------------
// Prêt en cours : échéance, remboursement (PIN, page de paiement, suivi).
// ---------------------------------------------------------------------------
class _PretCard extends ConsumerStatefulWidget {
  const _PretCard(this.pret);
  final Pret pret;
  @override
  ConsumerState<_PretCard> createState() => _PretCardState();
}

class _PretCardState extends ConsumerState<_PretCard> {
  final _payer = TextEditingController();
  String _key = const Uuid().v4(); // renouvelée seulement après un échec : un double clic ne paie jamais deux fois
  Op _op = Op.wave;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      final p = widget.pret;
      if (p.versementEnCours || (p.remboursement?.enCours ?? false)) ref.invalidate(pretsProvider);
    });
    ref.read(meProvider.future).then((m) {
      if (!mounted) return;
      if (_payer.text.isEmpty) _payer.text = m.local;
      setState(() => _op = detectOp(m.local) ?? Op.wave);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _payer.dispose();
    super.dispose();
  }

  String? get _payerPhone {
    var d = _payer.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return RegExp(r'^(01|05|07)\d{8}$').hasMatch(d) ? '+225$d' : null;
  }

  Future<void> _ouvrir(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return toast(context, 'Lien de paiement invalide');
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView) && mounted) toast(context, 'Impossible d’ouvrir la page de paiement');
  }

  Future<void> _rembourser() async {
    final payer = _payerPhone;
    if (payer == null) return toast(context, 'Numéro à débiter invalide (10 chiffres, commençant par 01, 05 ou 07)');
    final p = widget.pret;
    final pin = await askPin(context, reason: 'Confirmez le remboursement de ${fcfa(p.totalDu)}');
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(repoProvider).rembourserPret(id: p.id, op: _op, payerPhone: payer, idempotencyKey: _key, pin: pin.pin);
      ref.invalidate(pretsProvider);
      if (!mounted) return;
      final url = r.remboursement?.payinUrl;
      if (url != null) {
        await _ouvrir(url);
      } else if (_op == Op.mtn || _op == Op.moov) {
        toast(context, 'Confirmez le paiement sur votre téléphone (code reçu par USSD).');
      }
    } catch (e) {
      _key = const Uuid().v4();
      if (pin.viaBiometric && e is ApiError && e.code == 'PIN_INVALIDE') await PinService.clearBiometric();
      if (mounted) toast(context, _messageErreur(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pret;
    final retard = p.enRetard;
    final enCours = p.remboursement?.enCours ?? false;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Mon prêt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          StatusChip(label: _libelle(p), color: retard ? Colors.red : const Color(0xFF1E9E5A)),
        ]),
        const SizedBox(height: 12),
        _ligne('Montant reçu', fcfa(p.montant)),
        _ligne('Frais', fcfa(p.frais)),
        _ligne('Total à rembourser', fcfa(p.totalDu), bold: true),
        if (p.echeanceLe != null) _ligne('Date limite', _jour(p.echeanceLe)),
        if (p.versementEnCours)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Le versement est en cours. Cela prend quelques instants ; l’écran se met à jour tout seul.'),
          )
        else if (p.peutRembourser) ...[
          if (retard)
            const Padding(padding: EdgeInsets.only(top: 12), child: Text('Votre prêt est arrivé à échéance. Remboursez dès que possible, merci.', style: TextStyle(color: Colors.red)))
          else if (p.joursRestants != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(p.joursRestants! <= 1 ? 'Dernier jour pour rembourser.' : '${p.joursRestants} jours restants.')),
          const Divider(height: 28),
          const Text('Rembourser avec :'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final op in Op.values) ChoiceChip(label: Text(op.label), selected: _op == op, onSelected: _busy || enCours ? null : (_) => setState(() => _op = op)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _payer,
            enabled: !_busy && !enCours,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Numéro à débiter'),
          ),
          const SizedBox(height: 14),
          if (enCours)
            Row(children: [
              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Paiement en attente de confirmation…')),
              if (p.remboursement?.payinUrl != null) TextButton(onPressed: () => _ouvrir(p.remboursement!.payinUrl!), child: const Text('Rouvrir')),
            ])
          else
            FilledButton(
              onPressed: _busy ? null : _rembourser,
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Rembourser ${fcfa(p.totalDu)}'),
            ),
          if (p.remboursement != null && !enCours && (p.remboursement!.statut == 'ECHEC' || p.remboursement!.statut == 'EXPIRE'))
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Le dernier paiement n’a pas abouti. Rien n’a été débité.', style: TextStyle(color: fpMute))),
        ],
      ]),
    );
  }
}
