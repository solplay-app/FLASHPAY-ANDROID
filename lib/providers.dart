import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/push.dart';
import '../data/repository.dart';

/// null = non connecté ; 'CONNECTE' = jeton présent. `loading` tant que le jeton n'est pas lu.
class AuthNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => (await readToken()) == null ? null : 'CONNECTE';

  Future<void> login(String token) async {
    await saveToken(token);
    state = const AsyncData('CONNECTE');
  }

  Future<void> logout() async {
    await Push.stop(); // le téléphone ne reçoit plus les notifications de ce compte
    await clearToken();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, String?>(AuthNotifier.new);

final repoProvider = Provider<Repo>((ref) => Repo(buildDio(() => ref.read(authProvider.notifier).logout())));

final transfersProvider = FutureProvider.autoDispose<List<Transfer>>((ref) => ref.watch(repoProvider).transfers());
final limitsProvider = FutureProvider.autoDispose<Limits>((ref) => ref.watch(repoProvider).limits());
final kycProvider = FutureProvider.autoDispose<String>((ref) => ref.watch(repoProvider).kycStatus());
final cagnottesProvider = FutureProvider.autoDispose<List<Cagnotte>>((ref) => ref.watch(repoProvider).cagnottes());
