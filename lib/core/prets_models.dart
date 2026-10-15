/// Modèles « petits prêts ». Tous les montants sont des FCFA entiers calculés par le serveur.
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class Choix {
  Choix({required this.montant, required this.frais, required this.totalDu});
  final int montant, frais, totalDu;
  factory Choix.fromJson(Map<String, dynamic> j) => Choix(montant: _i(j['montant']), frais: _i(j['frais']), totalDu: _i(j['totalDu']));
}

class Offre {
  Offre({required this.id, required this.montantMax, required this.dureeJours, required this.expireLe, required this.choix});
  final String id;
  final int montantMax, dureeJours;
  final DateTime? expireLe;
  final List<Choix> choix;
  factory Offre.fromJson(Map<String, dynamic> j) => Offre(
        id: '${j['id']}',
        montantMax: _i(j['montantMax']),
        dureeJours: _i(j['dureeJours']),
        expireLe: DateTime.tryParse('${j['expireLe']}')?.toLocal(),
        choix: ((j['choix'] as List?) ?? const []).map((e) => Choix.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class Remb {
  Remb({required this.statut, this.payinUrl});
  final String statut; // INITIALISE, PAYIN_PENDING, SUCCES, ECHEC, EXPIRE, ECART
  final String? payinUrl;
  bool get enCours => statut == 'INITIALISE' || statut == 'PAYIN_PENDING';
  factory Remb.fromJson(Map<String, dynamic> j) => Remb(statut: '${j['statut']}', payinUrl: (j['redirectUrl'] ?? j['payinUrl'])?.toString());
}

class Pret {
  Pret({
    required this.id,
    required this.statut,
    required this.montant,
    required this.frais,
    required this.totalDu,
    required this.dureeJours,
    required this.operateur,
    required this.telephone,
    required this.enRetard,
    required this.peutRembourser,
    this.echeanceLe,
    this.joursRestants,
    this.remboursement,
  });
  final String id, statut, operateur, telephone;
  final int montant, frais, totalDu, dureeJours;
  final DateTime? echeanceLe;
  final int? joursRestants;
  final bool enRetard, peutRembourser;
  final Remb? remboursement;

  bool get versementEnCours => const ['A_DECAISSER', 'DECAISSEMENT_PENDING', 'DECAISSEMENT_ECHEC'].contains(statut);

  factory Pret.fromJson(Map<String, dynamic> j) => Pret(
        id: '${j['id']}',
        statut: '${j['statut']}',
        montant: _i(j['montant']),
        frais: _i(j['frais']),
        totalDu: _i(j['totalDu']),
        dureeJours: _i(j['dureeJours']),
        operateur: '${j['operateur']}',
        telephone: '${j['telephone']}',
        echeanceLe: j['echeanceLe'] == null ? null : DateTime.tryParse('${j['echeanceLe']}')?.toLocal(),
        joursRestants: j['joursRestants'] == null ? null : _i(j['joursRestants']),
        enRetard: j['enRetard'] == true,
        peutRembourser: j['peutRembourser'] == true,
        remboursement: j['remboursement'] == null ? null : Remb.fromJson(Map<String, dynamic>.from(j['remboursement'] as Map)),
      );
}

class PretsData {
  PretsData({required this.ouvert, this.offre, this.pret, required this.historique});
  final bool ouvert;
  final Offre? offre;
  final Pret? pret;
  final List<Pret> historique;

  /// Le bouton « Prêt » de l'accueil n'apparaît que s'il y a quelque chose à montrer.
  bool get visible => pret != null || (ouvert && offre != null);

  factory PretsData.fromJson(Map<String, dynamic> j) => PretsData(
        ouvert: j['ouvert'] == true,
        offre: j['offre'] == null ? null : Offre.fromJson(Map<String, dynamic>.from(j['offre'] as Map)),
        pret: j['pret'] == null ? null : Pret.fromJson(Map<String, dynamic>.from(j['pret'] as Map)),
        historique: ((j['historique'] as List?) ?? const []).map((e) => Pret.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
