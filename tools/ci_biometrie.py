#!/usr/bin/env python3
"""Prépare android/ pour l'empreinte digitale (plugin local_auth), après `flutter create .` :
  1. MainActivity doit hériter de FlutterFragmentActivity (sinon la fenêtre d'empreinte ne s'ouvre pas)
  2. permission USE_BIOMETRIC
  3. thèmes LaunchTheme/NormalTheme basés sur AppCompat (sinon plantage sur Android 8 et moins)
Idempotent. Aucune étape n'est bloquante : si un fichier a changé de forme, l'app fonctionne quand même avec le code PIN seul
(l'empreinte est alors simplement proposée comme indisponible). Lancé par .github/workflows/build-android.yml."""
import pathlib, re

root = pathlib.Path('android/app/src/main')

# 1. MainActivity (Kotlin ou Java)
acts = list(root.rglob('MainActivity.kt')) + list(root.rglob('MainActivity.java'))
if not acts:
    print('AVERTISSEMENT : MainActivity introuvable, empreinte indisponible (le PIN fonctionne).')
for f in acts:
    s = f.read_text(encoding='utf-8')
    n = re.sub(r'\bFlutterActivity\b', 'FlutterFragmentActivity', s)
    if n != s:
        f.write_text(n, encoding='utf-8')
        print(f'{f.name} : hérite maintenant de FlutterFragmentActivity')
    elif 'FlutterFragmentActivity' in s:
        print(f'{f.name} : déjà FlutterFragmentActivity')
    else:
        print(f'AVERTISSEMENT : {f.name} a une forme inattendue, empreinte peut-être indisponible (le PIN fonctionne).')

# 2. Permission
m = root / 'AndroidManifest.xml'
if m.exists():
    s = m.read_text(encoding='utf-8')
    if 'android.permission.USE_BIOMETRIC' not in s:
        s = s.replace('<application', '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n    <application', 1)
        m.write_text(s, encoding='utf-8')
        print('Manifeste : USE_BIOMETRIC ajoutée')
else:
    print('AVERTISSEMENT : AndroidManifest.xml introuvable')

# 3. Thèmes AppCompat
changed = 0
for f in root.glob('res/values*/styles.xml'):
    s = f.read_text(encoding='utf-8')
    n = re.sub(r'(<style\s+name="(?:LaunchTheme|NormalTheme)"\s+parent=")[^"]*(")', r'\1Theme.AppCompat.DayNight.NoActionBar\2', s)
    if n != s:
        f.write_text(n, encoding='utf-8')
        changed += 1
print(f'Thèmes : {changed} fichier(s) styles.xml passé(s) en AppCompat')
if not changed and not list(root.glob('res/values*/styles.xml')):
    print('AVERTISSEMENT : aucun styles.xml trouvé (OK sur Android récent, risque de plantage sur Android 8 et moins).')
