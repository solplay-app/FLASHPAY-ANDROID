import 'package:flutter/material.dart';
import '../core/models.dart';
import 'design.dart';
import 'theme.dart';

/// Les 4 réseaux en cartes (2 x 2), logo dans un rond blanc.
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.18,
        padding: const EdgeInsets.only(bottom: 6),
        children: [
          for (final o in Op.values)
            SoftCard(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: o == value ? o.color.withOpacity(.10) : null,
              borderColor: o == value ? o.color : null,
              borderWidth: 2.5,
              onTap: () {
                onOpen?.call();
                onChanged(o);
              },
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                OpCircle(o, size: 78),
                const SizedBox(height: 10),
                Text(o.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: fpInk)),
              ]),
            ),
        ],
      );
}
