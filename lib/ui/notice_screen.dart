import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../state/providers.dart';

/// Un message envoyé par FlashPay (maintenance, incident, bonus…).
class Notice {
  Notice({required this.id, required this.type, required this.titre, required this.message, required this.date, required this.lu});
  final String id, type, titre, message;
  final DateTime? date;
  final bool lu;

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: '${j['id']}',
        type: '${j['type'] ?? 'INFO'}',
        titre: '${j['titre'] ?? ''}',
        message: '${j['message'] ?? ''}',
        date: DateTime.tryParse('${j['cree_le'] ?? ''}')?.toLocal(),
        lu: j['lu'] == true,
      );
}

class NoticeBox {
  NoticeBox(this.unread, this.items);
  final int unread;
  final List<Notice> items;

  factory NoticeBox.fromJson(Map<String, dynamic> j) => NoticeBox(
        (j['nonLus'] as num?)?.toInt() ?? 0,
        ((j['rows'] as List?) ?? const []).map((e) => Notice.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// Relu régulièrement par l'accueil pour afficher le nombre de messages non lus.
final noticesProvider = FutureProvider.autoDispose<NoticeBox>((ref) async => NoticeBox.fromJson(await ref.read(repoProvider).notices()));

/// Écran « Messages » : liste des messages reçus. À l'ouverture, ils sont marqués comme lus.
class NoticeScreen extends ConsumerStatefulWidget {
  const NoticeScreen({super.key});
  @override
  ConsumerState<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends ConsumerState<NoticeScreen> {
  late Future<NoticeBox> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NoticeBox> _load() async {
    final repo = ref.read(repoProvider);
    final box = NoticeBox.fromJson(await repo.notices());
    if (box.unread > 0) {
      try {
        await repo.readAllNotices(); // la liste affichée garde les marques « Nouveau »
      } catch (_) {/* sans gravité : ils resteront non lus */}
    }
    return box;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<NoticeBox>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Réessayer')),
                ]),
              ),
            );
          }
          final items = snap.data!.items;
          return RefreshIndicator(
            onRefresh: _reload,
            child: items.isEmpty
                ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Aucun message pour le moment.')),
                  ])
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _NoticeCard(items[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard(this.n);
  final Notice n;

  (IconData, Color) _style(BuildContext context) {
    switch (n.type) {
      case 'MAINTENANCE':
        return (Icons.build_circle_outlined, const Color(0xFFF29900));
      case 'INCIDENT':
        return (Icons.warning_amber_rounded, const Color(0xFFD93025));
      case 'BONUS':
        return (Icons.card_giftcard, const Color(0xFF1E8E3E));
      default:
        return (Icons.info_outline, Theme.of(context).colorScheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n.titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                if (!n.lu)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
                    child: Text('Nouveau', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(n.message),
              if (n.date != null) ...[
                const SizedBox(height: 6),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(n.date!), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
