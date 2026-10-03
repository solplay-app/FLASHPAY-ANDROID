import 'package:flutter/material.dart';
import '../core/models.dart';
import 'theme.dart';

/// Les 4 réseaux en tuiles arrondies (2 x 2) avec leur logo.
class OperatorPicker extends StatelessWidget {
  const OperatorPicker({super.key, required this.value, required this.onChanged, this.onOpen});
  final Op? value;
  final ValueChanged<Op> onChanged;
  final VoidCallback? onOpen; // ex. fermer le clavier avant le choix

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          for (final o in Op.values)
            _Tile(
              op: o,
              selected: o == value,
              onTap: () {
                onOpen?.call();
                onChanged(o);
              },
            ),
        ],
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.op, required this.selected, required this.onTap});
  final Op op;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? op.color.withOpacity(.10) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: selected ? op.color : const Color(0xFFE3DDF0), width: selected ? 2.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(selected ? .08 : .04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              OpLogo(op, size: 52),
              const SizedBox(height: 10),
              Text(op.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      );
}
