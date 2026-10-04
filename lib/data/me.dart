import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';

/// Le compte connecté (numéro, statut KYC).
class Me {
  Me({required this.id, required this.phone, required this.kyc});
  final String id, phone, kyc;

  factory Me.fromJson(Map<String, dynamic> j) =>
      Me(id: '${j['id']}', phone: '${j['numeroTelephone'] ?? ''}', kyc: '${j['kycStatut'] ?? 'AUCUN'}');

  /// Numéro sur 10 chiffres (« +2250700000000 » → « 0700000000 »).
  String get local {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225') && d.length == 13) d = d.substring(3);
    return d;
  }
}

final meProvider = FutureProvider.autoDispose<Me>((ref) async => Me.fromJson(await ref.read(repoProvider).me()));
