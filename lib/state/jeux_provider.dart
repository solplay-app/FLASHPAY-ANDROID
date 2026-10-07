import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import 'providers.dart';

/// Un lot du jeu (case de la roue, cadeau du coffre, lot de la tombola).
class Lot {
  Lot(this.libelle, this.gagnant);
  final String libelle;
  final bool gagnant;
  factory Lot.fromJson(Map<String, dynamic> j) => Lot((j['libelle'] ?? '').toString(), j['gagnant'] == true);
}

/// Un jeu envoyé par FlashPay (roue, coffre, tombola) et l'état de participation de l'utilisateur.
class Jeu {
  Jeu({
    required this.id,
    required this.type,
    required this.titre,
    required this.description,
    required this.occasion,
    required this.fin,
    required this.ouvert,
    required this.aJoue,
    required this.tirageFait,
    required this.remis,
    required this.lots,
    this.libelle,
    this.gagnant,
  });
  final String id, type, titre, description, occasion;
  final DateTime? fin;
  final bool ouvert, aJoue, tirageFait, remis;
  final String? libelle;
  final bool? gagnant;
  final List<Lot> lots;

  /// À jouer maintenant.
  bool get aJouer => ouvert && !aJoue;

  factory Jeu.fromJson(Map<String, dynamic> j) => Jeu(
        id: j['id'].toString(),
        type: (j['type'] ?? '').toString(),
        titre: (j['titre'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        occasion: (j['occasion'] ?? '').toString(),
        fin: j['fin'] == null ? null : DateTime.tryParse(j['fin'].toString()),
        ouvert: j['ouvert'] == true,
        aJoue: j['aJoue'] == true,
        tirageFait: j['tirageFait'] == true,
        remis: j['remis'] == true,
        libelle: j['libelle']?.toString(),
        gagnant: j['gagnant'] as bool?,
        lots: ((j['lots'] as List?) ?? const []).map((e) => Lot.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

/// Résultat renvoyé par le serveur après avoir joué. Le tirage est TOUJOURS fait côté serveur.
class JeuResult {
  JeuResult({this.index, this.libelle, this.gagnant = false, this.participe = false});
  final int? index; // numéro de la case de la roue
  final String? libelle;
  final bool gagnant;
  final bool participe; // tombola : participation enregistrée
  factory JeuResult.fromJson(Map<String, dynamic> j) => JeuResult(
        index: (j['index'] as num?)?.toInt(),
        libelle: j['libelle']?.toString(),
        gagnant: j['gagnant'] == true,
        participe: j['participe'] == true,
      );
}

class JeuxApi {
  JeuxApi(this._dio);
  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Jeu>> list() => _run(() async {
        final r = await _dio.get('/jeux');
        final rows = (r.data as Map)['rows'] as List;
        return rows.map((e) => Jeu.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      });

  Future<JeuResult> jouer(String id) => _run(() async {
        final r = await _dio.post('/jeux/$id/jouer');
        return JeuResult.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}

final jeuxApiProvider = Provider<JeuxApi>((ref) => JeuxApi(buildDio(() => ref.read(authProvider.notifier).logout())));

/// Mes jeux (à jouer + déjà joués).
final jeuxProvider = FutureProvider.autoDispose<List<Jeu>>((ref) => ref.watch(jeuxApiProvider).list());
