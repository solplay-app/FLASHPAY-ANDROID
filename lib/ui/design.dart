import 'package:flutter/material.dart';
import '../core/models.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Composants visuels communs : fond dégradé, en-tête, cartes douces, barre de navigation.
// ---------------------------------------------------------------------------

/// Ce que l'écran principal met à disposition des onglets (icônes de l'en-tête, changement d'onglet).
class ShellActions extends InheritedWidget {
  const ShellActions({
    super.key,
    required this.unread,
    required this.openMessages,
    required this.openKyc,
    required this.openAccount,
    required this.goTab,
    required super.child,
  });
  final int unread;
  final VoidCallback openMessages, openKyc, openAccount;
  final ValueChanged<int> goTab;

  static ShellActions? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ShellActions>();

  @override
  bool updateShouldNotify(ShellActions old) => unread != old.unread;
}

/// Fond dégradé violet qui s'estompe vers le fond de page.
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child, this.dark = false});
  final Widget child;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF4A1C8F), Color(0xFF4A1C8F), fpPaper, fpPaper]
                : const [Color(0xFFBBA8F8), Color(0xFFE4DBFC), fpPaper, fpPaper],
            stops: dark ? const [0, .18, .5, 1] : const [0, .1, .32, 1],
          ),
        ),
        child: child,
      );
}

/// Logo dans une pastille translucide.
class LogoPill extends StatelessWidget {
  const LogoPill({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(dark ? .14 : .5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [brand, Color(0xFF9B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Flash', style: TextStyle(color: dark ? Colors.white : fpInk)),
              TextSpan(text: 'Pay', style: TextStyle(color: dark ? const Color(0xFFD3C2FF) : brand)),
            ]),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.3),
          ),
        ]),
      );
}

/// En-tête : logo + messages (cloche) + vérification d'identité + compte.
class HeaderBlock extends StatelessWidget {
  const HeaderBlock({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final a = ShellActions.maybeOf(context);
    final fg = dark ? Colors.white : fpInk;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 4),
        child: Row(children: [
          LogoPill(dark: dark),
          const Spacer(),
          if (a != null) ...[
            IconButton(
              tooltip: 'Messages',
              onPressed: a.openMessages,
              icon: Badge(isLabelVisible: a.unread > 0, smallSize: 10, backgroundColor: const Color(0xFF8B5CF6), child: Icon(Icons.notifications_none_rounded, color: fg, size: 30)),
            ),
            IconButton(tooltip: 'Vérification d’identité', onPressed: a.openKyc, icon: Icon(Icons.verified_user_outlined, color: fg, size: 30)),
            IconButton(tooltip: 'Mon compte', onPressed: a.openAccount, icon: Icon(Icons.account_circle_outlined, color: fg, size: 32)),
          ],
        ]),
      ),
    );
  }
}

/// Carte « douce » : relief léger, coins très arrondis.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24, this.onTap, this.color, this.borderColor, this.borderWidth = 1});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF8F6F3),
        borderRadius: r,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(.95), blurRadius: 10, offset: const Offset(-4, -4)),
          const BoxShadow(color: Color(0x243B2A6B), blurRadius: 16, offset: Offset(5, 7)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: r, onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Gros bouton de l'accueil.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.icon, required this.onTap, this.dark = true});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : fpDeep;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: dark
            ? const LinearGradient(colors: [Color(0xFF3A1766), Color(0xFF52258C)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: dark ? null : fpLavender,
        boxShadow: [BoxShadow(color: (dark ? fpDeep : brand).withOpacity(.28), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            height: dark ? 86 : 68,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: dark ? const Color(0xFFDCD3EE) : fg, size: dark ? 40 : 28),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: fg, fontSize: dark ? 22 : 20, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Logo d'un réseau dans un rond blanc (écran de choix du réseau).
class OpCircle extends StatelessWidget {
  const OpCircle(this.op, {super.key, this.size = 84});
  final Op op;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Color(0x1F3B2A6B), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/operators/${op.api}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: op.color,
              alignment: Alignment.center,
              child: Text(op.label[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .4)),
            ),
          ),
        ),
      );
}

/// Pastille de statut (Réussi, Échec, En cours…).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(22)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      );
}

/// Barre de navigation du bas : Accueil · Actions · Transactions · Cagnottes · Compte.
class FlashNavBar extends StatelessWidget {
  const FlashNavBar({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
    (Icons.send_outlined, Icons.send_rounded, 'Actions'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Transactions'),
    (Icons.card_giftcard_outlined, Icons.card_giftcard, 'Cagnottes'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Compte'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF4F1ED),
        elevation: 10,
        shadowColor: const Color(0x333B2A6B),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 74,
            child: Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 3,
                        width: i == index ? 56 : 0,
                        decoration: BoxDecoration(color: fpDeep, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(height: 10),
                      Icon(i == index ? _items[i].$2 : _items[i].$1, size: 28, color: i == index ? fpDeep : const Color(0xFF55506A)),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? fpDeep : const Color(0xFF55506A)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
}
