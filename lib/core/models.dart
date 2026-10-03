import 'package:flutter/material.dart';

enum Op {
  wave('wave', 'Wave', Color(0xFF1DC8FF)),
  orange('orange', 'Orange Money', Color(0xFFFF7900)),
  mtn('mtn', 'MTN MoMo', Color(0xFFFFCC00)),
  moov('moov', 'Moov Money', Color(0xFF0072CE));

  const Op(this.api, this.label, this.color);
  final String api;
  final String label;
  final Color color;
  static Op from(String v) => Op.values.firstWhere((o) => o.api == v, orElse: () => Op.wave);
}

/// Réseau déduit du préfixe du numéro (10 chiffres, sans +225) : 01 Moov · 05 MTN · 07 Orange.
/// Wave n'a pas de préfixe propre (un compte Wave est lié à un numéro de n'importe quel réseau) : il se choisit à la main.
Op? detectOp(String digits) {
  if (digits.length < 2) return null;
  return switch (digits.substring(0, 2)) {
    '01' => Op.moov,
    '05' => Op.mtn,
    '07' => Op.orange,
    _ => null,
  };
}

String fcfa(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('\u202F');
    b.write(s[i]);
  }
  return '$b F';
}

class Quote {
  Quote(this.net, this.fee, this.total);
  final int net, fee, total;
  factory Quote.fromJson(Map<String, dynamic> j) =>
      Quote(j['montantSouhaite'] as int, j['fraisService'] as int, j['montantTotalDebite'] as int);
}

class Transfer {
  Transfer({required this.id, required this.statut, required this.etat, required this.from, required this.to,
      required this.phone, required this.net, required this.fee, required this.total, this.redirectUrl, this.createdAt});
  final String id, statut, etat, phone;
  final Op from, to;
  final int net, fee, total;
  final String? redirectUrl;
  final DateTime? createdAt;

  factory Transfer.fromJson(Map<String, dynamic> j) => Transfer(
        id: j['id'],
        statut: j['statut'],
        etat: j['etat'],
        from: Op.from(j['operateurEmetteur']),
        to: Op.from(j['operateurDestinataire']),
        phone: j['telephoneDestinataire'],
        net: j['montantNet'],
        fee: j['fraisService'],
        total: j['montantTotalDebite'],
        redirectUrl: j['redirectUrl'],
        createdAt: DateTime.tryParse(j['creeLe'] ?? '')?.toLocal(),
      );

  bool get done => etat != 'EN_COURS';

  /// Vert = succès, orange = en cours, rouge = échec (remboursé : gris).
  Color get color => switch (etat) {
        'SUCCES' => const Color(0xFF1B9E4B),
        'ECHEC' => const Color(0xFFD93025),
        'REMBOURSE' => const Color(0xFF5F6B7A),
        _ => const Color(0xFFF29900),
      };
  String get label => switch (etat) {
        'SUCCES' => 'Réussi',
        'ECHEC' => 'Échec',
        'REMBOURSE' => 'Remboursé',
        _ => 'En cours',
      };
}

class Limits {
  Limits(this.kyc, this.perTx, this.dayLeft, this.monthLeft);
  final String kyc;
  final int perTx, dayLeft, monthLeft;
  factory Limits.fromJson(Map<String, dynamic> j) => Limits(
        j['kycStatut'],
        j['plafonds']['parTransaction'],
        j['restant']['jour'],
        j['restant']['mois'],
      );
}

class Cagnotte {
  Cagnotte({required this.id, required this.code, required this.nom, required this.objectif, required this.collecte,
      required this.participants, required this.dateFin, required this.op, required this.phone, required this.open, required this.mine});
  final String id, code, nom, phone;
  final int objectif, collecte, participants;
  final DateTime dateFin;
  final Op op;
  final bool open, mine;

  double get progress => objectif == 0 ? 0 : (collecte / objectif).clamp(0, 1).toDouble();

  factory Cagnotte.fromJson(Map<String, dynamic> j) => Cagnotte(
        id: j['id'],
        code: j['code'],
        nom: j['nom'],
        objectif: j['objectif'],
        collecte: j['collecte'],
        participants: j['participants'],
        dateFin: DateTime.parse(j['dateFin']).toLocal(),
        op: Op.from(j['operateur']),
        phone: j['telephone'],
        open: j['ouverte'],
        mine: j['estCreateur'],
      );
}
