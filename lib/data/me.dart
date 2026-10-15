import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';

/// Le compte connecté (numéro, statut KYC, acceptation des CGU de la bêta).
class Me {
  Me({required this.id, required this.phone, required this.kyc, this.cguBetaAccepted = false, this.cguBetaAcceptedAt});
  final String id, phone, kyc;

  /// false (ou champ absent, compte antérieur) = l'écran des CGU bloque l'accès à l'accueil.
  final bool cguBetaAccepted;
  final DateTime? cguBetaAcceptedAt;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: '${j['id']}',
        phone: '${j['numeroTelephone'] ?? ''}',
        kyc: '${j['kycStatut'] ?? 'AUCUN'}',
        cguBetaAccepted: j['cguBetaAccepted'] == true,
        cguBetaAcceptedAt: DateTime.tryParse('${j['cguBetaAcceptedAt'] ?? ''}')?.toLocal(),
      );

  /// Numéro sur 10 chiffres (« +2250700000000 » → « 0700000000 »).
  String get local {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return d;
  }
}

final meProvider = FutureProvider.autoDispose<Me>((ref) async => Me.fromJson(await ref.read(repoProvider).me()));
