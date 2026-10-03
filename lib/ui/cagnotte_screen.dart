import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../state/providers.dart';
import 'confirm_screen.dart';
import 'operator_picker.dart';
import 'theme.dart';

final _date = DateFormat('dd/MM/yyyy');

/// Liste de mes cagnottes + accès par code.
class CagnotteListScreen extends ConsumerWidget {
  const CagnotteListScreen({super.key});

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
      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CagnotteDetailScreen(cagnotte: c)));
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cagnottesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cagnottes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
        onPressed: () async {
          final c = await Navigator.push<Cagnotte>(context, MaterialPageRoute(builder: (_) => const CreateCagnotteScreen()));
          ref.invalidate(cagnottesProvider);
          if (c != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CagnotteDetailScreen(cagnotte: c)));
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(cagnottesProvider.future),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.pin_outlined),
            label: const Text('Participer avec un code'),
            onPressed: () => _join(context, ref),
          ),
          const SizedBox(height: 16),
          const Text('Mes cagnottes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          list.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
            data: (items) => items.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Créez votre première cagnotte et partagez son code.', textAlign: TextAlign.center)))
                : Column(children: [
                    for (final c in items)
                      Card(
                        child: ListTile(
                          title: Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              LinearProgressIndicator(value: c.progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                              const SizedBox(height: 4),
                              Text('${fcfa(c.collecte)} sur ${fcfa(c.objectif)}${c.open ? '' : ' · terminée'}'),
                            ]),
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CagnotteDetailScreen(cagnotte: c))).then((_) => ref.invalidate(cagnottesProvider)),
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class CreateCagnotteScreen extends ConsumerStatefulWidget {
  const CreateCagnotteScreen({super.key});
  @override
  ConsumerState<CreateCagnotteScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<CreateCagnotteScreen> {
  final _nom = TextEditingController();
  final _goal = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _end;
  Op? _op;
  bool _busy = false;

  String _digits(String s) {
    var d = s.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00225')) d = d.substring(5);
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return d;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _end ?? now.add(const Duration(days: 14)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d != null) setState(() => _end = d);
  }

  Future<void> _submit() async {
    final goal = int.tryParse(_goal.text);
    final phone = _digits(_phone.text);
    if (_nom.text.trim().length < 3) return toast(context, 'Donnez un nom à la cagnotte');
    if (goal == null || goal < 500) return toast(context, 'Objectif minimum : 500 F');
    if (_end == null) return toast(context, 'Choisissez une date de fin');
    if (phone.length != 10) return toast(context, 'Numéro invalide (10 chiffres)');
    final op = _op ?? detectOp(phone);
    if (op == null) return toast(context, 'Choisissez le réseau de réception');
    setState(() => _busy = true);
    try {
      final c = await ref.read(repoProvider).createCagnotte(
          nom: _nom.text.trim(), objectif: goal, dateFin: DateFormat('yyyy-MM-dd').format(_end!), op: op, phone: phone);
      if (mounted) Navigator.pop(context, c);
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Créer une cagnotte')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(controller: _nom, maxLength: 80, decoration: const InputDecoration(labelText: 'Nom de la cagnotte')),
          const SizedBox(height: 8),
          TextField(
            controller: _goal,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            decoration: const InputDecoration(labelText: 'Objectif', suffixText: 'FCFA'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.event),
            label: Text(_end == null ? 'Date de fin' : 'Fin le ${_date.format(_end!)}'),
            onPressed: _pickDate,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => _op = detectOp(_digits(_phone.text))),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(18)],
            decoration: const InputDecoration(labelText: 'Numéro qui reçoit l’argent', prefixText: '+225  '),
          ),
          const SizedBox(height: 12),
          OperatorPicker(value: _op, onChanged: (o) => setState(() => _op = o)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Créer la cagnotte'),
          ),
        ]),
      );
}

class CagnotteDetailScreen extends ConsumerStatefulWidget {
  const CagnotteDetailScreen({super.key, required this.cagnotte});
  final Cagnotte cagnotte;
  @override
  ConsumerState<CagnotteDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<CagnotteDetailScreen> {
  late Cagnotte _c = widget.cagnotte;
  final _amount = TextEditingController();
  Op? _from;
  bool _busy = false;

  Future<void> _refresh() async {
    try {
      final c = await ref.read(repoProvider).cagnotte(_c.code);
      if (mounted) setState(() => _c = c);
    } catch (_) {}
  }

  Future<void> _participate() async {
    final net = int.tryParse(_amount.text);
    if (_from == null) return toast(context, 'Choisissez le réseau qui paie');
    if (net == null || net < 300) return toast(context, 'Montant minimum : 300 F');
    setState(() => _busy = true);
    try {
      final q = await ref.read(repoProvider).quote(net);
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ConfirmScreen(quote: q, from: _from!, to: _c.op, phone: _c.phone, cagnotteCode: _c.code)));
      await _refresh();
    } on ApiError catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clôturer la cagnotte ?'),
        content: const Text('Plus personne ne pourra participer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: () => Navigator.pop(context, true), child: const Text('Clôturer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).closeCagnotte(_c.id);
      await _refresh();
    } catch (e) {
      if (mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: Text(c.nom, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(fcfa(c.collecte), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: brand)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: c.progress, minHeight: 12, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 8),
          Text('${(c.progress * 100).round()} % de ${fcfa(c.objectif)} · ${c.participants} participant${c.participants > 1 ? 's' : ''}'),
          Text(c.open ? 'Fin le ${_date.format(c.dateFin)}' : 'Cagnotte terminée', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3)),
              subtitle: const Text('Partagez ce code pour inviter'),
              trailing: IconButton(
                tooltip: 'Copier',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'Participe à « ${c.nom} » sur FlashPay avec le code ${c.code}'));
                  toast(context, 'Message copié');
                },
              ),
            ),
          ),
          if (c.open) ...[
            const SizedBox(height: 16),
            const Text('Participer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            OperatorPicker(value: _from, onChanged: (o) => setState(() => _from = o)),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              decoration: const InputDecoration(labelText: 'Montant', suffixText: 'FCFA'),
            ),
            Wrap(spacing: 8, children: [
              for (final v in [1000, 5000, 10000]) ActionChip(label: Text(fcfa(v)), onPressed: () => setState(() => _amount.text = '$v')),
            ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _participate,
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Voir le récapitulatif'),
            ),
          ],
          if (c.mine && c.open) TextButton(onPressed: _close, child: const Text('Clôturer la cagnotte')),
        ]),
      ),
    );
  }
}
