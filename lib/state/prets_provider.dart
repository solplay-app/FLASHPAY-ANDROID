import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/prets_models.dart';
import 'providers.dart';

/// Offre faite à CET utilisateur, prêt en cours, historique. Relu à chaque ouverture et à la réception d'un push.
final pretsProvider = FutureProvider.autoDispose<PretsData>((ref) => ref.watch(repoProvider).prets());
