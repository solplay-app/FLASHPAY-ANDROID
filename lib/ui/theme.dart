import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';

const brand = Color(0xFF6C2BD9);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: brand),
  inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  ),
);

void toast(BuildContext c, Object e) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e is ApiError ? e.message : e.toString())));

/// Logo de l'opérateur (assets/operators/<id>.png). Pastille colorée avec l'initiale tant que le fichier manque.
class OpLogo extends StatelessWidget {
  const OpLogo(this.op, {super.key, this.size = 40});
  final Op op;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/operators/${op.api}.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: op.color,
            alignment: Alignment.center,
            child: Text(op.label[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .45)),
          ),
        ),
      );
}
