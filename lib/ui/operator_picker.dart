import 'package:flutter/material.dart';
import '../core/models.dart';
import 'theme.dart';

/// Tuile dépliable : replie sur l'opérateur choisi, se déplie pour montrer les 4 réseaux avec leur logo.
class OperatorPicker extends StatefulWidget {
  const OperatorPicker({super.key, required this.value, required this.onChanged, this.startOpen = true, this.onOpen, this.hint = 'Choisir un opérateur'});
  final Op? value;
  final ValueChanged<Op> onChanged;
  final bool startOpen; // déplié dès l'ouverture quand rien n'est choisi
  final VoidCallback? onOpen; // ex. fermer le clavier pour laisser la place à la liste
  final String hint;
  @override
  State<OperatorPicker> createState() => _OperatorPickerState();
}

class _OperatorPickerState extends State<OperatorPicker> {
  late bool _open = widget.value == null && widget.startOpen;

  @override
  void didUpdateWidget(OperatorPicker old) {
    super.didUpdateWidget(old);
    // Réseau détecté (ou effacé) depuis l'extérieur : on replie sur le choix.
    if (old.value != widget.value && widget.value != null) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: v == null ? const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)) : OpLogo(v, size: 44),
          title: Text(v?.label ?? widget.hint, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: AnimatedRotation(turns: _open ? .5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.keyboard_arrow_down)),
          onTap: () {
            if (!_open) widget.onOpen?.call();
            setState(() => _open = !_open);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _open
              ? Column(children: [
                  const Divider(height: 1),
                  for (final o in Op.values)
                    ListTile(
                      selected: o == v,
                      selectedTileColor: o.color.withOpacity(.12),
                      leading: OpLogo(o, size: 40),
                      title: Text(o.label),
                      trailing: o == v ? Icon(Icons.check_circle, color: o.color) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                      onTap: () {
                        setState(() => _open = false);
                        widget.onChanged(o);
                      },
                    ),
                ])
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
