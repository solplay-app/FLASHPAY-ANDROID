import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../core/cgu_texte.dart';
import '../data/me.dart';
import '../state/providers.dart';
import 'app_lock.dart';
import 'home_screen.dart';
import 'pin_screens.dart';
import 'theme.dart';

/// ---------------------------------------------------------------------------
/// ÉTAPE 4 — LE VERROU
/// Écran de vérification de session : interroge GET /me sur le serveur Render.
///  - cguBetaAccepted == true  ➡️ écran d'accueil habituel (PinGate → AppLock → HomeScreen)
///  - cguBetaAccepted == false ➡️ EcranCguBlocage : impossible d'aller plus loin
///
/// Remarque : l'application n'utilise aucune route nommée (`MaterialApp.home`),
/// il n'existe donc pas de '/home' à pousser par Navigator.pushReplacement.
/// Remplacer l'arbre (le gate) est ici l'équivalent exact : l'utilisateur ne peut
/// ni revenir en arrière ni contourner l'écran.
/// Le gate est placé AVANT la barrière PIN : on accepte les CGU, puis on saisit le PIN.
/// ---------------------------------------------------------------------------
class CguGate extends ConsumerStatefulWidget {
  const CguGate({super.key});
  @override
  ConsumerState<CguGate> createState() => _CguGateState();
}

class _CguGateState extends ConsumerState<CguGate> {
  late Future<Me> _me;

  @override
  void initState() {
    super.initState();
    _me = _lire();
  }

  Future<Me> _lire() async => Me.fromJson(await ref.read(repoProvider).me());

  void _reload() => setState(() => _me = _lire());

  @override
  Widget build(BuildContext context) => FutureBuilder<Me>(
        future: _me,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            final msg = snap.error is ApiError ? (snap.error as ApiError).message : 'Connexion impossible. Vérifiez votre réseau.';
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_off, size: 56, color: fpMute),
                    const SizedBox(height: 12),
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _reload, child: const Text('Réessayer')),
                    TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Se déconnecter')),
                  ]),
                ),
              ),
            );
          }
          // CGU de la bêta acceptées : on entre dans l'application.
          if (snap.data!.cguBetaAccepted) return const PinGate(child: AppLock(child: HomeScreen()));
          // Sinon : écran de blocage. Après acceptation (200 OK), on relit /me : le gate bascule sur l'accueil.
          return EcranCguBlocage(onAccepted: _reload);
        },
      );
}

/// ---------------------------------------------------------------------------
/// ÉTAPES 3 et 5 — ÉCRAN DE BLOCAGE + VALIDATION
/// Encadré de lecture (bordure grise) → texte défilable des CGU → case à cocher → bouton.
/// Le bouton est grisé (onPressed: null) tant que la case n'est pas cochée.
/// ---------------------------------------------------------------------------
class EcranCguBlocage extends ConsumerStatefulWidget {
  const EcranCguBlocage({super.key, this.onAccepted});
  /// Appelé après un 200 OK du serveur : fait basculer le gate vers l'accueil.
  final VoidCallback? onAccepted;
  @override
  ConsumerState<EcranCguBlocage> createState() => _EcranCguBlocageState();
}

class _EcranCguBlocageState extends ConsumerState<EcranCguBlocage> {
  bool _estCoche = false; // état de la case « J'accepte »
  bool _envoi = false; // requête POST en cours → CircularProgressIndicator sur le bouton

  /// Étape 5 : envoi POST /cgu/accept, puis redirection vers l'accueil.
  Future<void> _accepter() async {
    setState(() => _envoi = true);
    try {
      await ref.read(repoProvider).acceptCgu();
      if (!mounted) return;
      // 200 OK : la base porte cgu_beta_accepted = true + l'horodatage. On passe à l'accueil.
      widget.onAccepted?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        toast(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false, // le bouton « retour » ne contourne pas l'acceptation des CGU
        child: Scaffold(
          backgroundColor: fpPaper,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const FlashPayLogo(size: 32),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Conditions Générales d’Utilisation', style: TextStyle(fontFamily: fpSerif, fontSize: 22, fontWeight: FontWeight.w700, color: fpInk)),
                  const SizedBox(height: 6),
                  const Text('Version bêta privée · Côte d’Ivoire', style: TextStyle(fontSize: 14, color: fpMute)),
                  const SizedBox(height: 14),

                  // 1. Encadré de lecture : bordure grise, hauteur extensible, texte défilable.
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFC9C9C9)), // bordure grise
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const SingleChildScrollView(
                        child: Text(
                          kCguBetaTexte,
                          style: TextStyle(fontSize: 14.5, height: 1.45, color: fpInk),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 2. Case à cocher liée à l'état _estCoche.
                  CheckboxListTile(
                    value: _estCoche,
                    onChanged: _envoi ? null : (v) => setState(() => _estCoche = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: brand,
                    title: const Text('J’ai lu et j’accepte les Conditions Générales d’Utilisation de la bêta privée FlashPay.',
                        style: TextStyle(fontSize: 14.5, color: fpInk)),
                  ),
                  const SizedBox(height: 10),

                  // 3. Bouton aux couleurs FlashPay : grisé tant que la case n'est pas cochée.
                  ElevatedButton(
                    onPressed: (!_estCoche || _envoi) ? null : _accepter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fpDeep,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD8D3E2),
                      disabledForegroundColor: const Color(0xFF8B8598),
                      minimumSize: const Size.fromHeight(56),
                      elevation: 0,
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _envoi
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Accepter et continuer'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _envoi ? null : () => ref.read(authProvider.notifier).logout(),
                    child: const Text('Refuser et me déconnecter', style: TextStyle(color: fpMute)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
