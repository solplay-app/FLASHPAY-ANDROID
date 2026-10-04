import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import '../core/models.dart';
import '../core/notifications.dart';
import '../core/push.dart';
import '../data/me.dart';
import '../state/providers.dart';
import 'design.dart';
import 'kyc_screen.dart';
import 'notice_screen.dart';
import 'tabs.dart';
import 'theme.dart';
import 'transfer_screen.dart';

/// Écran principal : 5 onglets (Accueil · Actions · Transactions · Cagnottes · Compte).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _poll;
  Timer? _pollNotices;
  final Map<String, String> _seen = {};
  final Set<String> _noticeSeen = {};
  bool _noticeInit = false; // la 1re lecture ne déclenche pas de notification
  int _unread = 0;
  int _tab = 0;
  final _transferKey = GlobalKey<TransferScreenState>();

  @override
  void initState() {
    super.initState();
    // « Temps réel » : relecture régulière tant que l'application est ouverte.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => ref.invalidate(transfersProvider));
    _pollNotices = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(noticesProvider));
    // Push : enregistre le téléphone ; à la réception (app ouverte) on relit tout de suite, la notification locale s'affiche alors.
    Push.start(ref.read(repoProvider), onMessage: () {
      ref.invalidate(transfersProvider);
      ref.invalidate(noticesProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pollNotices?.cancel();
    super.dispose();
  }

  void _goTab(int i) => setState(() => _tab = i);

  Future<void> _openMessages() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen()));
    if (mounted) ref.invalidate(noticesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(meProvider); // garde le compte en mémoire tant que l'écran est ouvert
    // Messages de FlashPay : nombre de non lus (on garde la dernière valeur pendant un rechargement).
    _unread = ref.watch(noticesProvider).maybeWhen(data: (b) => b.unread, orElse: () => _unread);
    // Nouveau message reçu pendant que l'app est ouverte → notification sur le téléphone.
    ref.listen(noticesProvider, (_, next) {
      next.whenData((box) {
        for (final n in box.items) {
          if (!n.lu && _noticeSeen.add(n.id) && _noticeInit) {
            Notifier.show('FlashPay · ${n.titre}', n.message);
          }
        }
        _noticeInit = true;
      });
    });
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

    return ShellActions(
      unread: _unread,
      openMessages: _openMessages,
      openKyc: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())),
      openAccount: () => _goTab(4),
      goTab: _goTab,
      child: PopScope(
        // Retour : recule dans le transfert, sinon revient à l'accueil, sinon quitte l'application.
        canPop: _tab == 0,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_tab == 1 && (_transferKey.currentState?.goBack() ?? false)) return;
          _goTab(0);
        },
        child: Scaffold(
          backgroundColor: fpPaper,
          body: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              const HomeTab(),
              TransferScreen(key: _transferKey),
              const TransactionsTab(),
              const CagnotteTab(),
              const AccountTab(),
            ],
          ),
          bottomNavigationBar: FlashNavBar(index: _tab, onChanged: _goTab),
        ),
      ),
    );
  }
}
