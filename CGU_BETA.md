# CGU de la bêta privée — mise en service

Écran de blocage « CGU » : le testeur ne peut pas atteindre l'accueil tant qu'il n'a pas
coché « J'accepte » et validé. La preuve est enregistrée en base (booléen + horodatage).

## 1. Base de données (Render → PostgreSQL)

Deux façons de créer les champs sur `users` :

* **Automatique** : le serveur exécute `ensureCguSchema()` au démarrage (mêmes champs, idempotent).
* **Migration** : `npm run migrate` applique `migrations/008_cgu_beta.sql`.

```sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS cgu_beta_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cgu_beta_accepted_at TIMESTAMPTZ;
```

## 2. API

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/me` | renvoie désormais `cguBetaAccepted` (booléen) et `cguBetaAcceptedAt` |
| POST | `/cgu/accept` | jeton requis ; passe `cgu_beta_accepted` à `true`, horodate, renvoie `200 OK` |

```bash
curl -X POST https://VOTRE-SERVICE.onrender.com/cgu/accept \
  -H "Authorization: Bearer <jeton>"
# → {"ok":true,"cguBetaAccepted":true,"cguBetaAcceptedAt":"…"}
```

## 3. Application Flutter

* `lib/core/cgu_texte.dart` — texte intégral des CGU.
* `lib/ui/cgu_screen.dart` — `EcranCguBlocage` (encadré gris + texte défilable + case + bouton)
  et `CguGate` (vérification `/me`, verrou de session).
* `lib/data/me.dart` — champ `cguBetaAccepted`.
* `lib/data/repository.dart` — `acceptCgu()`.
* `lib/main.dart` — `home:` passe par `CguGate` avant `PinGate` → `AppLock` → `HomeScreen`.

Compilation sans changement d'API :

```bash
flutter pub get
flutter build apk --dart-define=API_URL=https://VOTRE-SERVICE.onrender.com
```

Pour révoquer l'acceptation d'un testeur (nouvelle version des CGU) :

```sql
UPDATE users SET cgu_beta_accepted = FALSE, cgu_beta_accepted_at = NULL WHERE numero_telephone = '+225XXXXXXXXXX';
```
