import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../state/jeux_provider.dart';
import 'design.dart';
import 'theme.dart';

const _vert = Color(0xFF1E9E5A);

IconData _iconeJeu(String type) => type == 'ROUE'
    ? Icons.donut_large_rounded
    : type == 'COFFRE'
        ? Icons.card_giftcard_rounded
        : Icons.confirmation_number_outlined;

String _libelleBouton(String type) => type == 'ROUE'
    ? 'Tourner la roue'
    : type == 'COFFRE'
        ? 'Ouvrir mon cadeau'
        : 'Participer gratuitement';

// ---------------------------------------------------------------------------
// Bouton de l'accueil : n'apparaît que s'il y a des jeux, avec le nombre de jeux à jouer.
// ---------------------------------------------------------------------------
class JeuxHomeButton extends ConsumerWidget {
  const JeuxHomeButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeux = ref.watch(jeuxProvider).maybeWhen(data: (l) => l, orElse: () => const <Jeu>[]);
    if (jeux.isEmpty) return const SizedBox.shrink();
    final n = jeux.where((j) => j.aJouer).length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Stack(clipBehavior: Clip.none, children: [
        BigButton(
          label: 'Jeux & cadeaux',
          icon: Icons.card_giftcard_rounded,
          dark: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JeuxScreen())).then((_) => ref.invalidate(jeuxProvider)),
        ),
        if (n > 0)
          Positioned(
            right: 14,
            top: -7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(12)),
              child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste des jeux
// ---------------------------------------------------------------------------
class JeuxScreen extends ConsumerWidget {
  const JeuxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeux = ref.watch(jeuxProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux & cadeaux')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(jeuxProvider.future),
        child: jeux.when(
          loading: () => ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]),
          error: (e, _) => ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 80),
            Text(ApiError.from(e).message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Center(child: FilledButton(onPressed: () => ref.invalidate(jeuxProvider), child: const Text('Réessayer'))),
          ]),
          data: (list) => ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 60, 16, 30),
                child: Column(children: [
                  Icon(Icons.card_giftcard_rounded, size: 64, color: fpMute),
                  SizedBox(height: 12),
                  Text('Aucun jeu pour le moment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fpInk)),
                  SizedBox(height: 6),
                  Text('Revenez bientôt : FlashPay vous offre des jeux et des cadeaux à chaque occasion spéciale.', textAlign: TextAlign.center, style: TextStyle(color: fpMute)),
                ]),
              )
            else
              for (final j in list) _JeuCard(j),
            const SizedBox(height: 8),
            const Text(
              'Participation gratuite et sans obligation de transaction. Un seul essai par personne et par jeu. '
              'Le résultat est déterminé par FlashPay au moment du jeu ; les cadeaux sont remis par FlashPay.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: fpMute),
            ),
          ]),
        ),
      ),
    );
  }
}

class _JeuCard extends ConsumerWidget {
  const _JeuCard(this.j);
  final Jeu j;

  Widget _etat(BuildContext context, WidgetRef ref) {
    if (j.aJouer) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => JouerScreen(jeu: j)));
            ref.invalidate(jeuxProvider);
          },
          icon: Icon(_iconeJeu(j.type)),
          label: Text(_libelleBouton(j.type)),
        ),
      );
    }
    String titre;
    String? detail;
    Color couleur;
    if (j.type == 'TOMBOLA' && !j.tirageFait) {
      titre = 'Participation enregistrée';
      detail = 'Le tirage au sort sera annoncé ici et par notification.';
      couleur = brand;
    } else if (j.gagnant == true) {
      titre = '🎉 Vous avez gagné : ${j.libelle ?? ''}';
      detail = j.remis ? 'Cadeau remis.' : 'Notre équipe vous remettra votre cadeau.';
      couleur = _vert;
    } else {
      titre = 'Pas de cadeau cette fois';
      detail = j.type == 'TOMBOLA' ? 'Vous n’avez pas été tiré au sort. Merci d’avoir participé !' : 'Merci d’avoir joué. Rendez-vous au prochain jeu !';
      couleur = fpMute;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: couleur.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: TextStyle(fontWeight: FontWeight.w800, color: couleur == fpMute ? fpInk : couleur)),
        if (detail != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(detail, style: const TextStyle(fontSize: 12.5, color: fpMute))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fin = j.fin?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        radius: 22,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: fpLavender, borderRadius: BorderRadius.circular(14)),
              child: Icon(_iconeJeu(j.type), color: fpDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(j.titre, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: fpInk)),
                Text(
                  [if (j.occasion.isNotEmpty) j.occasion, if (j.aJouer && fin != null) 'jusqu’au ${DateFormat('dd/MM').format(fin)}'].join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: fpMute),
                ),
              ]),
            ),
          ]),
          if (j.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(j.description, style: const TextStyle(color: fpInk))),
          const SizedBox(height: 12),
          _etat(context, ref),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jouer : roue, coffre ou tombola. Le résultat vient du serveur ; l'animation n'est que visuelle.
// ---------------------------------------------------------------------------
class JouerScreen extends ConsumerStatefulWidget {
  const JouerScreen({super.key, required this.jeu});
  final Jeu jeu;
  @override
  ConsumerState<JouerScreen> createState() => _JouerScreenState();
}

class _JouerScreenState extends ConsumerState<JouerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));
  Animation<double> _anim = const AlwaysStoppedAnimation<double>(0);
  bool _busy = false;
  JeuResult? _res;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _spin(int index) async {
    final n = widget.jeu.lots.length;
    if (n == 0) return;
    final sweep = 2 * math.pi / n;
    final fin = 2 * math.pi * 6 - (index + 0.5) * sweep; // la case tirée s'arrête sous la flèche (en haut)
    _ctrl.duration = const Duration(milliseconds: 4800);
    _anim = Tween<double>(begin: 0, end: fin).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    await _ctrl.forward(from: 0);
  }

  Future<void> _shake() async {
    _ctrl.duration = const Duration(milliseconds: 1100);
    await _ctrl.forward(from: 0);
  }

  Future<void> _jouer() async {
    if (_busy) return;
    setState(() => _busy = true);
    final JeuResult r;
    try {
      r = await ref.read(jeuxApiProvider).jouer(widget.jeu.id);
    } catch (e) {
      if (mounted) {
        toast(context, e); // ex. « Vous avez déjà joué à ce jeu. »
        ref.invalidate(jeuxProvider);
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted) return;
    if (widget.jeu.type == 'ROUE' && r.index != null) {
      await _spin(r.index!);
    } else if (widget.jeu.type == 'COFFRE') {
      await _shake();
    }
    if (!mounted) return;
    ref.invalidate(jeuxProvider);
    setState(() => _res = r);
  }

  Widget _roue(double w) {
    final lots = widget.jeu.lots;
    return SizedBox(
      width: w,
      height: w + 24,
      child: Stack(alignment: Alignment.topCenter, children: [
        Positioned(
          top: 24,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.rotate(
              angle: _anim.value,
              child: CustomPaint(size: Size.square(w), painter: _WheelPainter(lots.map((l) => l.libelle).toList())),
            ),
          ),
        ),
        const Icon(Icons.arrow_drop_down_rounded, size: 58, color: fpDeep),
      ]),
    );
  }

  Widget _coffre() => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.rotate(angle: math.sin(_ctrl.value * 10 * math.pi) * .18 * (1 - _ctrl.value), child: child),
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fpLavender, boxShadow: [BoxShadow(color: brand.withOpacity(.25), blurRadius: 24, offset: const Offset(0, 10))]),
          child: Icon(_res == null ? Icons.card_giftcard_rounded : (_res!.gagnant ? Icons.celebration_rounded : Icons.sentiment_neutral_rounded), size: 90, color: fpDeep),
        ),
      );

  Widget _resultat(JeuResult r) {
    final String emoji, titre, texte;
    final Color c;
    if (r.participe) {
      emoji = '✅';
      titre = 'Participation enregistrée';
      texte = 'Le tirage au sort aura lieu à la fin du jeu. Vous serez prévenu par notification et le résultat s’affichera dans « Jeux & cadeaux ».';
      c = brand;
    } else if (r.gagnant) {
      emoji = '🎉';
      titre = 'Félicitations !';
      texte = 'Vous avez gagné : ${r.libelle}\nNotre équipe vous remettra votre cadeau.';
      c = _vert;
    } else {
      emoji = '😕';
      titre = 'Pas de chance cette fois';
      texte = 'Merci d’avoir joué. Rendez-vous au prochain jeu !';
      c = fpMute;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.withOpacity(.10), borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 6),
        Text(titre, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: fpInk)),
        const SizedBox(height: 6),
        Text(texte, textAlign: TextAlign.center, style: const TextStyle(color: fpInk, height: 1.35)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jeu;
    final w = math.min(MediaQuery.of(context).size.width - 64, 340.0);
    final aGagner = j.lots.where((l) => l.gagnant).map((l) => l.libelle).toList();
    return Scaffold(
      appBar: AppBar(title: Text(j.titre)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            if (j.description.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(j.description, textAlign: TextAlign.center, style: const TextStyle(color: fpMute))),
            if (j.type == 'ROUE') _roue(w) else if (j.type == 'COFFRE') _coffre() else Icon(_iconeJeu(j.type), size: 110, color: fpDeep),
            const SizedBox(height: 18),
            if (_res == null && j.type != 'ROUE' && aGagner.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text('À gagner : ${aGagner.join(' · ')}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: fpInk)),
              ),
            if (_res != null) ...[
              _resultat(_res!),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terminer'))),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _jouer,
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_iconeJeu(j.type)),
                  label: Text(_busy ? 'Un instant…' : _libelleBouton(j.type)),
                ),
              ),
            const SizedBox(height: 14),
            const Text('Participation gratuite · un seul essai par personne', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: fpMute)),
          ]),
        ),
      ),
    );
  }
}

/// Dessine la roue : une part par lot, la première part commence en haut et tourne dans le sens des aiguilles d'une montre.
class _WheelPainter extends CustomPainter {
  _WheelPainter(this.labels);
  final List<String> labels;
  static const _couleurs = [Color(0xFF6C2BD9), Color(0xFFF5B82E), Color(0xFF3F1C6E), Color(0xFFFF7A59), Color(0xFF9B5CF6), Color(0xFF22B573)];

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final sweep = 2 * math.pi / n;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < n; i++) {
      var couleur = _couleurs[i % _couleurs.length];
      if (n % _couleurs.length == 1 && i == n - 1) couleur = _couleurs[2]; // évite deux parts voisines de même couleur
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true, Paint()..color = couleur);
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 2 + (i + 0.5) * sweep);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: couleur.computeLuminance() > .5 ? fpInk : Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: r * .58);
      tp.paint(canvas, Offset(r * .32, -tp.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = fpDeep);
    canvas.drawCircle(c, r * .11, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * .11, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = fpDeep);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.labels.join('|') != labels.join('|');
}
