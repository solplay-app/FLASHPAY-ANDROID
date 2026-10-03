# FlashPay — application Flutter

Écrans : 1 Connexion OTP · 2 Accueil · 3 Transfert · 4 Ticket de confirmation + suivi · 5 KYC.
Architecture : `core/` (Dio, intercepteur, modèles) · `data/` (appels API) · `state/` (Riverpod) · `ui/`.

## Mise en route
```bash
flutter create . --org ci.flashpay --project-name flashpay_app   # génère android/ et ios/ (ne remplace pas lib/)
flutter pub get
dart pub global activate flutterfire_cli && flutterfire configure   # Firebase (App Check + Storage)
flutter run --dart-define=API_URL=https://VOTRE-API.onrender.com
```
Permissions (contacts, caméra, notifications, internet) : une commande après `flutter create .` :
```bash
python3 tools/apply_platform_config.py   # Android (manifest) + iOS (Info.plist), relançable sans doublon
```
Notifications Android : l'autorisation `POST_NOTIFICATIONS` (Android 13+) est déclarée par le script, puis demandée à l'exécution par le bouton cloche de l'accueil.
Le plugin de notifications exige le « desugaring » dans `android/app/build.gradle(.kts)` :
`compileOptions { isCoreLibraryDesugaringEnabled = true }` et `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") }` (voir la doc de flutter_local_notifications).
Les notifications sont locales : elles partent quand l'app détecte un changement de statut (app ouverte ou en arrière-plan récent). Pour des notifications app fermée, il faudra Firebase Cloud Messaging côté backend.

## Logos des opérateurs
Déposez `wave.png`, `orange.png`, `mtn.png`, `moov.png` dans `assets/operators/` (logos officiels fournis par chaque opérateur). Sans fichier, une pastille colorée avec l'initiale s'affiche.

## Support
Écran Support (icône casque de l'accueil, lien « Besoin d'aide ? » à la connexion) : appel +225 01 05 14 71 23 et e-mail flashpay@gmail.com. Constantes dans `lib/ui/support_screen.dart`.

## Firebase Storage Rules (obligatoire pour le KYC)
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /kyc/{uid}/{file} {
      allow write: if request.auth != null && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
      allow read: if false;   // lecture réservée à l'admin (Admin SDK)
    }
  }
}
```
Côté backend : renseigner `FIREBASE_SERVICE_ACCOUNT_JSON`, puis `npm install` (nouvelle dépendance `firebase-admin`).

## Points d'attention
- Le paiement passe par la page de checkout Jèko (redirection HTTPS dans un navigateur intégré), pas par un SDK ni un push USSD : c'est ce que l'API Jèko documentée propose.
- La clé d'idempotence est générée une fois par ticket : un double appui ou une coupure réseau ne débite pas deux fois.
- Cagnottes : bouton « Cagnottes » de l'accueil (`lib/ui/cagnotte_screen.dart`). Chaque participation est un transfert normal vers le numéro du créateur ; les participants paient les 6 %.
- Le jeton est dans `flutter_secure_storage` ; un 401 déconnecte automatiquement.

## Détection automatique du réseau
Page « Numéro du destinataire » : le réseau est déduit du préfixe dès la saisie ou le choix d'un contact (`detectOp` dans `lib/core/models.dart`, testé dans `test/detect_op_test.dart`) : **01 → Moov, 05 → MTN, 07 → Orange**. Wave n'a pas de préfixe propre : il se choisit à la main dans la tuile. Une correction manuelle est conservée tant que le préfixe ne change pas. Préfixe inconnu : l'utilisateur choisit le réseau.

## Compilation sur GitHub
`.github/workflows/build-android.yml` génère `android/`, applique les permissions, compile et publie `app-release.apk` (onglet Actions > l'exécution > Artifacts).
Secrets du dépôt (Settings > Secrets and variables > Actions) :
- `API_URL` : URL de l'API Render, sans slash final (obligatoire).
- `GOOGLE_SERVICES_JSON` : contenu de `google-services.json` (Firebase, pour le KYC). L'identifiant Android de l'app Firebase doit être `ci.flashpay.flashpay_app`.
L'APK est signé avec la clé de debug : suffisant pour installer et tester. Pour le Play Store, il faudra une clé de signature. iOS n'est pas compilé (compte Apple Developer requis).
