import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/models.dart';

const brand = Color(0xFF6C2BD9);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: brand),
  scaffoldBackgroundColor: const Color(0xFFF7F5FC),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3DDF0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3DDF0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: brand, width: 2)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
);

/// Logo FlashPay : pastille dégradée avec éclair + nom.
class FlashPayLogo extends StatelessWidget {
  const FlashPayLogo({super.key, this.size = 36, this.showName = true});
  final double size;
  final bool showName;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [brand, Color(0xFF9B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(size * .3),
          ),
          child: Icon(Icons.bolt_rounded, color: Colors.white, size: size * .64),
        ),
        if (showName) ...[
          SizedBox(width: size * .28),
          Text.rich(
            TextSpan(children: const [
              TextSpan(text: 'Flash', style: TextStyle(color: Color(0xFF1B1530))),
              TextSpan(text: 'Pay', style: TextStyle(color: brand)),
            ]),
            style: TextStyle(fontSize: size * .62, fontWeight: FontWeight.w800, letterSpacing: -.3),
          ),
        ],
      ]);
}

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
