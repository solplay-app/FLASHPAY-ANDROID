import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:intl/intl.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/updater.dart';
import '../data/me.dart';
import '../state/providers.dart';
import 'cagnotte_screen.dart';
import 'design.dart';
import 'kyc_screen.dart';
import 'notice_screen.dart';
import 'pin_screens.dart';
import 'share_screen.dart';
import 'support_screen.dart';
import 'theme.dart';

const _titleStyle = TextStyle(fontFamily: fpSerif, fontSize: 21, fontWeight: FontWeight.w800, color: fpInk);

void _push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

// ---------------------------------------------------------------------------
// Ligne de transaction
// ---------------------------------------------------------------------------
class TxRow extends StatelessWidget {
  const TxRow(this.t, {super.key});
  final Transfer t;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            OpLogo(t.to, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
                  Text(fcfa(t.net), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fpInk)),
                  Text(t.phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fpInk)),
                ]),
                const SizedBox(height: 1),
                Text('${t.from.label} → ${t.to.label}', style: const TextStyle(fontSize: 12.5, color: fpInk)),
                if (t.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined, size: 14, color: fpMute),
                      const SizedBox(width: 5),
                      Text(DateFormat('dd/MM HH:mm').format(t.createdAt!), style: const TextStyle(fontSize: 11.5, color: fpMute)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(width: 6),
            StatusChip(label: t.label, color: t.color),
          ]),
        ),
      );
}

Widget _txList(AsyncValue<List<Transfer>> list, {int? max}) => list.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
      data: (items) {
        if (items.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune transaction pour le moment.')));
        final shown = max == null ? items : items.take(max).toList();
        return Column(children: [for (final t in shown) TxRow(t)]);
      },
    );

// ---------------------------------------------------------------------------
// Accueil
// ---------------------------------------------------------------------------
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ShellActions.maybeOf(context);
    final list = ref.watch(transfersProvider);
    return UpdateGate(
      child: GradientBackdrop(
      child: Stack(children: [
        Column(children: [
          // Zone fixe : ne bouge pas quand on fait défiler les transactions.
          const HeaderBlock(showClock: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              BigButton(label: 'Transférer des fonds', icon: Icons.bolt_rounded, onTap: () => a?.goTab(1)),
              const SizedBox(height: 10),
              BigButton(label: 'Cagnottes', icon: Icons.groups_outlined, dark: false, onTap: () => a?.goTab(3)),
            ]),
          ),
          // Seule la liste des transactions défile.
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(transfersProvider.future),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 110), children: [
                const Text('Dernières transactions', style: _titleStyle),
                const SizedBox(height: 10),
                _txList(list, max: 8),
              ]),
            ),
          ),
        ]),
        Positioned(
          right: 18,
          bottom: 16,
          child: GestureDetector(
            onTap: () => _push(context, const SupportScreen()),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF4F0FF),
                  boxShadow: [BoxShadow(color: brand.withOpacity(.25), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.headset_mic_outlined, size: 32, color: fpDeep),
              ),
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDCD0FF)),
                  child: const Icon(Icons.chat_bubble_outline, size: 14, color: fpDeep),
                ),
              ),
            ]),
          ),
        ),
      ]),
    ));
  }
}

// ---------------------------------------------------------------------------
// Transactions
// ---------------------------------------------------------------------------
class TransactionsTab extends ConsumerWidget {
  const TransactionsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(transfersProvider);
    return GradientBackdrop(
      child: Column(children: [
        const HeaderBlock(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(transfersProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
              const Text('Transactions', style: _titleStyle),
              const SizedBox(height: 12),
              _txList(list),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Cagnottes
// ---------------------------------------------------------------------------
class CagnotteTab extends ConsumerWidget {
  const CagnotteTab({super.key});

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Participer avec un code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(8)],
          decoration: const InputDecoration(labelText: 'Code à 8 caractères'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
    if (code == null || code.length != 8 || !context.mounted) return;
    try {
      final c = await ref.read(repoProvider).cagnotte(code);
      if (context.mounted) _push(context, CagnotteDetailScreen(cagnotte: c));
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final c = await Navigator.push<Cagnotte>(context, MaterialPageRoute(builder: (_) => const CreateCagnotteScreen()));
    ref.invalidate(cagnottesProvider);
    if (c != null && context.mounted) _push(context, CagnotteDetailScreen(cagnotte: c));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cagnottesProvider);
    return GradientBackdrop(
      child: Column(children: [
        const HeaderBlock(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(cagnottesProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
              const Text('Cagnottes', style: _titleStyle),
              const SizedBox(height: 14),
              BigButton(label: 'Créer une cagnotte', icon: Icons.add_circle_outline, onTap: () => _create(context, ref)),
              const SizedBox(height: 12),
              BigButton(label: 'Participer avec un code', icon: Icons.pin_outlined, dark: false, onTap: () => _join(context, ref)),
              const SizedBox(height: 24),
              const Text('Mes cagnottes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: fpInk)),
              const SizedBox(height: 10),
              list.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
                data: (items) => items.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Créez votre première cagnotte et partagez son code.', textAlign: TextAlign.center)))
                    : Column(children: [
                        for (final c in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: SoftCard(
                              radius: 22,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CagnotteDetailScreen(cagnotte: c))).then((_) => ref.invalidate(cagnottesProvider)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: fpInk)),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(value: c.progress, minHeight: 8, borderRadius: BorderRadius.circular(4), color: fpDeep, backgroundColor: const Color(0xFFE2DCF2)),
                                const SizedBox(height: 8),
                                Text('${fcfa(c.collecte)} sur ${fcfa(c.objectif)}${c.open ? '' : ' · terminée'}', style: const TextStyle(color: fpMute)),
                              ]),
                            ),
                          ),
                      ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Compte
// ---------------------------------------------------------------------------
class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});
  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  bool _notif = false;

  @override
  void initState() {
    super.initState();
    Notifier.enabled().then((v) => mounted ? setState(() => _notif = v) : null);
  }

  Future<void> _toggleNotifications() async {
    if (await Notifier.enabled()) {
      if (mounted) toast(context, 'Notifications activées. Pour les couper : Réglages > Applications > FlashPay > Notifications.');
      return;
    }
    final ok = await Notifier.request();
    if (!mounted) return;
    setState(() => _notif = ok);
    toast(context, ok ? 'Notifications activées.' : 'Refusées. Activez-les dans Réglages > Applications > FlashPay > Notifications.');
  }

  static const _kyc = {
    'VALIDE': ('Identité vérifiée', Color(0xFF1E8E3E)),
    'EN_ATTENTE': ('Vérification en cours', Color(0xFFF29900)),
    'REJETE': ('Dossier refusé', Color(0xFFD93025)),
  };

  Widget _item(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap, Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          radius: 20,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: color ?? fpDeep, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color ?? fpInk)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(color: fpMute, fontSize: 13)),
              ]),
            ),
            trailing ?? (onTap == null ? const SizedBox.shrink() : const Icon(Icons.chevron_right, color: fpMute)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).valueOrNull;
    final unread = ref.watch(noticesProvider).maybeWhen(data: (b) => b.unread, orElse: () => 0);
    final kyc = me == null ? null : _kyc[me.kyc];
    return GradientBackdrop(
      child: Column(children: [
        const HeaderBlock(),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
            const Text('Mon compte', style: _titleStyle),
            const SizedBox(height: 14),
            SoftCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const CircleAvatar(radius: 28, backgroundColor: Color(0xFFDCD0FF), child: Icon(Icons.person, size: 32, color: fpDeep)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me == null ? '…' : me.phone, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fpInk)),
                    const SizedBox(height: 4),
                    Text(kyc?.$1 ?? 'Identité non vérifiée', style: TextStyle(fontWeight: FontWeight.w600, color: kyc?.$2 ?? fpMute)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            _item(Icons.verified_user_outlined, 'Vérification d’identité', subtitle: 'Nécessaire pour les montants élevés', onTap: () => _push(context, const KycScreen())),
            _item(Icons.lock_outline, 'Sécurité', subtitle: 'Code PIN et empreinte digitale', onTap: () => _push(context, const SecurityScreen())),
            _item(
              Icons.mail_outline,
              'Messages',
              subtitle: 'Informations, maintenance, bonus',
              trailing: unread > 0 ? Badge(label: Text('$unread'), child: const Icon(Icons.chevron_right, color: fpMute)) : null,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen())).then((_) => ref.invalidate(noticesProvider)),
            ),
            _item(
              _notif ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              'Notifications du téléphone',
              subtitle: _notif ? 'Activées' : 'Désactivées : touchez pour activer',
              onTap: _toggleNotifications,
            ),
            _item(Icons.system_update_outlined, 'Mise à jour', subtitle: 'Version installée : $kBuildName', onTap: () => Updater.check(context, manual: true)),
            _item(Icons.qr_code_2, 'Partager l’application', subtitle: 'QR code pour installer FlashPay', onTap: () => _push(context, const ShareAppScreen())),
            _item(Icons.support_agent, 'Support', onTap: () => _push(context, const SupportScreen())),
            const SizedBox(height: 6),
            _item(Icons.logout, 'Se déconnecter', color: const Color(0xFFD93025), onTap: () => ref.read(authProvider.notifier).logout()),
          ]),
        ),
      ]),
    );
  }
}
