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
  final _recep = TextEditingController(); // numéro qui REÇOIT le prêt (par défaut : celui du compte, modifiable)
  Choix? _choix;
  Op? _op;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.offre;
    if (o.choix.isNotEmpty) _choix = o.choix.last;
    ref.read(meProvider.future).then((m) {
      if (!mounted) return;
      if (_recep.text.isEmpty) _recep.text = m.local;
      if (_op == null) setState(() => _op = detectOp(m.local) ?? Op.wave);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _recep.dispose();
    super.dispose();
  }

  /// Numéro de réception : 10 chiffres ivoiriens (01/05/07), au format +225….
  String? get _recepPhone {
    var d = _recep.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return RegExp(r'^(01|05|07)\d{8}$').hasMatch(d) ? '+225$d' : null;
  }

  Future<void> _accepter() async {
    final c = _choix, op = _op;
    final recep = _recepPhone;
    if (c == null || op == null || recep == null) return;
    final pin = await askPin(context, reason: 'Confirmez le prêt de ${fcfa(c.montant)}');
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).accepterPret(offreId: widget.offre.id, montant: c.montant, op: op, idempotencyKey: _key, pin: pin.pin, telephoneReception: recep);
      ref.invalidate(pretsProvider);
      if (mounted) toast(context, 'Prêt accepté. Le versement arrive sur le numéro choisi.');
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _OffreHeader(offre: o, choix: c, busy: _busy, onPick: (x) => setState(() => _choix = x)),
      if (c != null) ...[
        const SizedBox(height: 16),
        RecapPret(demande: c.montant, recu: c.recuReel, frais: c.frais, total: c.totalDu, dureeJours: o.dureeJours, cartes: true),
        const SizedBox(height: 16),
        _CoutReel(cout: c.cout ?? c.totalDu - c.recuReel, recu: c.recuReel, total: c.totalDu),
      ],
      const SizedBox(height: 16),
      _Section(
        titre: 'Recevoir les fonds',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recevoir sur le numéro de votre compte :', style: TextStyle(color: fpMute, fontSize: 16)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              for (final op in Op.values) _OpTile(op: op, selected: _op == op, onTap: _busy ? null : () => setState(() => _op = op)),
            ],
          ),
          if (mismatch)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Ce réseau ne correspond pas au numéro de votre compte : vérifiez avant de continuer.', style: TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 18),
          const Text('Numéro de réception (par défaut : celui de votre compte)', style: TextStyle(color: fpMute, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _recep,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: fpInk),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFFAF8FF),
              suffixIcon: const Icon(Icons.edit_outlined, color: fpMute),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2DCEF))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2DCEF))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: brand, width: 2)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _busy || c == null || _op == null || _recepPhone == null ? null : _accepter,
        icon: _busy
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.shield_outlined),
        label: const Text('Accepter le prêt', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          backgroundColor: fpDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        o.palierSuivant != null && o.palierSuivant! > (o.choix.isNotEmpty ? o.choix.last.montant : 0)
            ? 'Après ce remboursement, vous pourrez emprunter jusqu’à ${fcfa(o.palierSuivant!)}.'
            : 'Empruntez seulement ce que vous pouvez rembourser à la date prévue.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: fpMute, fontSize: 14),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

/// En-tête violet : titre, conditions de l'offre et choix du montant.
class _OffreHeader extends StatelessWidget {
  const _OffreHeader({required this.offre, required this.choix, required this.busy, required this.onPick});
  final Offre offre;
  final Choix? choix;
  final bool busy;
  final ValueChanged<Choix> onPick;
  @override
  Widget build(BuildContext context) {
    final o = offre;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F2A8C), Color(0xFF6E3FA3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x403B2A6B), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Une offre pour vous', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Jusqu’à ${fcfa(o.montantMax)} · remboursement en ${o.dureeJours} jours'
          '${o.expireLe != null ? ' · valable jusqu’au ${_jour(o.expireLe)}' : ''}',
          style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final x in o.choix) _Pastille(label: fcfa(x.montant), selected: choix?.montant == x.montant, onTap: busy ? null : () => onPick(x)),
        ]),
      ]),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Colors.white : Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.check, color: fpDeep, size: 24)),
              Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: selected ? fpDeep : Colors.white)),
            ]),
          ),
        ),
      );
}

/// Carte blanche avec un petit titre en capitales.
class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.child});
  final String titre;
  final Widget child;
  @override
  Widget build(BuildContext context) => SoftCard(
        color: Colors.white,
        radius: 28,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.8, color: Color(0xFF9A93AE))),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Encart d'information : coût réel du prêt.
class _CoutReel extends StatelessWidget {
  const _CoutReel({required this.cout, required this.recu, required this.total});
  final int cout, recu, total;
  @override
  Widget build(BuildContext context) {
    const gras = TextStyle(fontWeight: FontWeight.w800);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF6E8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF3DFB8))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.info_outline, color: _ambre, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(style: const TextStyle(color: Color(0xFF7A4B0B), fontSize: 16, height: 1.4), children: [
              const TextSpan(text: 'Coût réel du prêt : '),
              TextSpan(text: fcfa(cout), style: gras),
              const TextSpan(text: ' (vous recevez '),
              TextSpan(text: fcfa(recu), style: gras),
              const TextSpan(text: ' et rendez '),
              TextSpan(text: fcfa(total), style: gras),
              const TextSpan(text: ').'),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Un réseau mobile money : son logo (assets/operators), son nom, coche si choisi.
class _OpTile extends StatelessWidget {
  const _OpTile({required this.op, required this.selected, required this.onTap});
  final Op op;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1EBFB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? brand : const Color(0xFFE2DCEF), width: selected ? 1.8 : 1.2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                OpCircle(op, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(op.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: fpInk))),
                if (selected) const Icon(Icons.check, color: brand, size: 24),
              ]),
            ),
          ),
        ),
      );
}

/// « 1,5 % », « 5 % », « 6,6 % » : pourcentage de [part] sur [base], une décimale au plus (virgule française).
String _pct(int part, int base) {
  if (base <= 0) return '0 %';
  final v = (part * 1000 / base).round() / 10;
  final t = v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');
  return '$t %';
}

const _ambre = Color(0xFFB7791F);
const _sepRecap = Divider(height: 1, color: Color(0xFFE7E3EC));

/// Tableau récapitulatif d'un prêt : demande, frais de dossier, montant reçu, capital à rendre, intérêt, total.
/// Tous les montants viennent du serveur ; seuls les pourcentages sont calculés ici.
/// [cartes] : deux cartes séparées (écran d'offre) ; sinon un bloc simple à placer dans une carte existante.
class RecapPret extends StatelessWidget {
  const RecapPret({super.key, required this.demande, required this.recu, required this.frais, required this.total, this.dureeJours, this.cartes = false});
  final int demande, recu, frais, total;
  final int? dureeJours;
  final bool cartes;

  @override
  Widget build(BuildContext context) {
    final fraisDossier = demande - recu;
    final detail = Column(children: [
      _LigneRecap('Demande de prêt', fcfa(demande)),
      if (fraisDossier > 0) ...[
        _sepRecap,
        _LigneRecap('Frais de dossier (${_pct(fraisDossier, demande)})', '− ${fcfa(fraisDossier)}', couleur: _ambre),
      ],
      const SizedBox(height: 12),
      _Encart(label: 'Montant reçu', valeur: fcfa(recu), fond: const Color(0xFFEAF7F0), bord: const Color(0xFFCDEBDB), texte: const Color(0xFF0F7A47)),
    ]);
    final remboursement = Column(children: [
      _LigneRecap('Remboursement du capital', fcfa(demande)),
      _sepRecap,
      _LigneRecap('Intérêt (${_pct(frais, demande)})', '+ ${fcfa(frais)}', couleur: _ambre),
      const SizedBox(height: 12),
      _Encart(
        label: dureeJours == null ? 'Total à rembourser' : 'Total à rembourser dans $dureeJours jours',
        valeur: fcfa(total),
        fond: const Color(0xFFF1EBFB),
        bord: const Color(0xFFDCCFF5),
        texte: fpDeep,
        grand: true,
      ),
    ]);
    if (cartes) {
      return Column(children: [
        _Section(titre: 'Détail du prêt', child: detail),
        const SizedBox(height: 16),
        _Section(titre: 'Remboursement', child: remboursement),
      ]);
    }
    return Column(children: [detail, const Divider(height: 28), remboursement]);
  }
}

class _LigneRecap extends StatelessWidget {
  const _LigneRecap(this.label, this.valeur, {this.couleur});
  final String label, valeur;
  final Color? couleur;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 17, color: fpMute))),
          const SizedBox(width: 12),
          Text(valeur, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: couleur ?? fpInk)),
        ]),
      );
}

/// Ligne mise en valeur (montant reçu en vert, total en violet).
class _Encart extends StatelessWidget {
  const _Encart({required this.label, required this.valeur, required this.fond, required this.bord, required this.texte, this.grand = false});
  final String label, valeur;
  final Color fond, bord, texte;
  final bool grand;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(16), border: Border.all(color: bord)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: texte))),
          const SizedBox(width: 12),
          Text(valeur, style: TextStyle(fontSize: grand ? 30 : 26, fontWeight: FontWeight.w800, color: texte)),
        ]),
      );
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
        RecapPret(demande: p.montant, recu: p.recuReel, frais: p.frais, total: p.totalDu, dureeJours: p.dureeJours),
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
