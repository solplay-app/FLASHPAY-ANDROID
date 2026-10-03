#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Appelé par .github/workflows/build-android.yml (étape "Permissions et Gradle").
# Pas besoin de le lancer à la main.
# Il modifie android/ : minSdk 23, desugaring (notifications), plugin Firebase
# (seulement si android/app/google-services.json existe).
# Si la compilation GitHub échoue à cette étape, Flutter a changé la forme de ses fichiers
# Gradle : copier l'erreur et ajuster les expressions régulières ci-dessous.
# ---------------------------------------------------------------------------
"""Prépare android/ (généré par `flutter create .`) pour la compilation en CI :
minSdk 23, desugaring (flutter_local_notifications) et, si google-services.json est présent, le plugin Firebase.
Idempotent. Les deux fichiers Gradle peuvent être en Kotlin (.kts, modèle récent) ou en Groovy (.gradle)."""
import pathlib, re, sys

app = next((p for p in (pathlib.Path('android/app/build.gradle.kts'), pathlib.Path('android/app/build.gradle')) if p.exists()), None)
if not app:
    sys.exit('android/app/build.gradle(.kts) introuvable : lancez `flutter create .` avant.')
kts = app.suffix == '.kts'
s = app.read_text(encoding='utf8')

# 1. minSdk 23 (exigé par Firebase)
s = re.sub(r'minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)', 'minSdk = 23' if kts else 'minSdkVersion 23', s)

# 2. desugaring
if 'coreLibraryDesugaring' not in s:
    on = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    s = re.sub(r'(compileOptions\s*\{)', r'\1\n        ' + on, s, count=1)
    dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")' if kts else 'coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4"'
    if re.search(r'^dependencies\s*\{', s, re.M):
        s = re.sub(r'^dependencies\s*\{', 'dependencies {\n    ' + dep, s, count=1, flags=re.M)
    else:
        s += '\ndependencies {\n    ' + dep + '\n}\n'

# 3. Firebase (seulement si le fichier de configuration a été déposé)
if pathlib.Path('android/app/google-services.json').exists() and 'google-services' not in s:
    plug = 'id("com.google.gms.google-services")' if kts else "id 'com.google.gms.google-services'"
    s = re.sub(r'(id\(?\s*["\']dev\.flutter\.flutter-gradle-plugin["\']\s*\)?)', r'\1\n    ' + plug, s, count=1)
    settings = next((p for p in (pathlib.Path('android/settings.gradle.kts'), pathlib.Path('android/settings.gradle')) if p.exists()), None)
    if settings:
        t = settings.read_text(encoding='utf8')
        decl = 'id("com.google.gms.google-services") version "4.4.2" apply false' if settings.suffix == '.kts' else "id 'com.google.gms.google-services' version '4.4.2' apply false"
        t = re.sub(r'(id\(?\s*["\']com\.android\.application["\']\s*\)?\s*version[^\n]*)', r'\1\n    ' + decl, t, count=1)
        settings.write_text(t, encoding='utf8')

app.write_text(s, encoding='utf8')
print('android/ prêt pour la compilation.')
