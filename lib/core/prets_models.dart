/// Modèles « petits prêts ». Tous les montants sont des FCFA entiers calculés par le serveur.
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class Choix {
  Choix({required this.montant, required this.frais, required this.totalDu, this.recu, this.cout});
  final int montant, frais, totalDu;
  final int? recu; // ce que le client reçoit RÉELLEMENT sur son numéro (frais Jèko déduits le cas échéant)
  final int? cout; // coût réel du prêt = totalDu − recu (affiché avant confirmation)
  int get recuReel => recu ?? montant;
  factory Choix.fromJson(Map<String, dynamic> j) =>
      Choix(montant: _i(j['montant']), frais: _i(j['frais']), totalDu: _i(j['totalDu']), recu: j['recu'] == null ? null : _i(j['recu']), cout: j['cout'] == null ? null : _i(j['cout']));
}

class Offre {
  Offre({required this.id, required this.montantMax, required this.dureeJours, required this.expireLe, required this.choix, this.palierSuivant});
  final String id;
  final int montantMax, dureeJours;
  final DateTime? expireLe;
  final List<Choix> choix;
  final int? palierSuivant; // plafond de progression : dernier montant remboursé + palier (l'admin garde la main au-delà)
  factory Offre.fromJson(Map<String, dynamic> j) => Offre(
        id: '${j['id']}',
        montantMax: _i(j['montantMax']),
        dureeJours: _i(j['dureeJours']),
        expireLe: DateTime.tryParse('${j['expireLe']}')?.toLocal(),
        palierSuivant: j['palierSuivant'] == null ? null : _i(j['palierSuivant']),
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
    this.telephoneReception,
    required this.enRetard,
    required this.peutRembourser,
    this.echeanceLe,
    this.joursRestants,
    this.remboursement,
  });
  final String id, statut, operateur, telephone;
  final String? telephoneReception; // numéro qui REÇOIT le versement (peut différer du numéro du compte)
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
        telephoneReception: j['telephoneReception']?.toString(),
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
