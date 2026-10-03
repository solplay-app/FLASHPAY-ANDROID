import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';
import '../core/notifications.dart';
import '../state/providers.dart';
import 'cagnotte_screen.dart';
import 'kyc_screen.dart';
import 'support_screen.dart';
import 'theme.dart';
import 'transfer_screen.dart';

/// Écran 2 : tableau de bord.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _poll;
  final Map<String, String> _seen = {};
  bool _notif = false;

  @override
  void initState() {
    super.initState();
    // « Temps réel » : relecture toutes les 10 s tant que l'écran est ouvert.
    Notifier.enabled().then((v) => mounted ? setState(() => _notif = v) : null);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidate(transfersProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(transfersProvider);
    // Notification quand un transfert « en cours » passe à réussi / échec / remboursé.
    ref.listen(transfersProvider, (_, next) {
      next.whenData((items) {
        for (final t in items) {
          if (_seen[t.id] == 'EN_COURS' && t.etat != 'EN_COURS') {
            Notifier.show('FlashPay · ${t.label}', '${fcfa(t.net)} vers ${t.phone} : ${t.label.toLowerCase()}.');
          }
          _seen[t.id] = t.etat;
        }
      });
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlashPay', style: TextStyle(fontWeight: FontWeight.w800, color: brand)),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Icon(_notif ? Icons.notifications_active : Icons.notifications_off_outlined),
            onPressed: _toggleNotifications,
          ),
          IconButton(
            tooltip: 'Support',
            icon: const Icon(Icons.support_agent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          IconButton(
            tooltip: 'Vérification d’identité',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())),
          ),
          IconButton(tooltip: 'Déconnexion', icon: const Icon(Icons.logout), onPressed: () => ref.read(authProvider.notifier).logout()),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(transfersProvider.future),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Transférer des fonds'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
              ref.invalidate(transfersProvider);
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Cagnottes'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CagnotteListScreen())).then((_) => ref.invalidate(transfersProvider)),
          ),
          const SizedBox(height: 24),
          const Text('Dernières transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          list.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
            data: (items) => items.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune transaction pour le moment.')))
                : Column(children: [for (final t in items) _Row(t)]),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.t);
  final Transfer t;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: OpLogo(t.to),
        title: Text('${fcfa(t.net)} → ${t.phone}'),
        subtitle: Text('${t.from.label} → ${t.to.label}${t.createdAt == null ? '' : ' · ${DateFormat('dd/MM HH:mm').format(t.createdAt!)}'}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: t.color.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
          child: Text(t.label, style: TextStyle(color: t.color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );
}
