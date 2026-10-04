"""Signe l'APK avec la clé FlashPay (au lieu de la clé de debug, qui change à chaque compilation).
Lancé par le workflow après « flutter create » : modifie android/app/build.gradle(.kts)."""
import pathlib
import re
import sys

app = pathlib.Path('android/app')
if (app / 'build.gradle.kts').exists():
    p, kts = app / 'build.gradle.kts', True
elif (app / 'build.gradle').exists():
    p, kts = app / 'build.gradle', False
else:
    sys.exit('ERREUR : android/app/build.gradle(.kts) introuvable')

s = p.read_text(encoding='utf-8')
if 'key.properties' in s:
    print('Signature déjà configurée')
    sys.exit(0)

if kts:
    s = 'import java.io.FileInputStream\nimport java.util.Properties\n\n' + s
    props = (
        'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
    )
    signing = (
        '    signingConfigs {\n'
        '        create("release") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '            storePassword = keystoreProperties["storePassword"] as String\n'
        '        }\n'
        '    }\n\n'
    )
    debug_re = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
    release = 'signingConfig = signingConfigs.getByName("release")'
else:
    props = (
        'def keystoreProperties = new Properties()\n'
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
    )
    signing = (
        '    signingConfigs {\n'
        '        release {\n'
        "            keyAlias keystoreProperties['keyAlias']\n"
        "            keyPassword keystoreProperties['keyPassword']\n"
        "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
        "            storePassword keystoreProperties['storePassword']\n"
        '        }\n'
        '    }\n\n'
    )
    debug_re = r'signingConfig\s*=?\s*signingConfigs\.(?:getByName\("debug"\)|debug)'
    release = 'signingConfig signingConfigs.release'

s, n1 = re.subn(r'^android\s*\{', lambda m: props + 'android {', s, count=1, flags=re.M)
s, n2 = re.subn(r'^[ \t]*buildTypes\s*\{', lambda m: signing + m.group(0), s, count=1, flags=re.M)
s, n3 = re.subn(debug_re, lambda m: release, s)
if (n1, n2, n3) != (1, 1, 1):
    sys.exit(f'ERREUR : le modèle Android de Flutter a changé (android={n1}, buildTypes={n2}, signature={n3}). Envoyer ce message à l’assistant.')
p.write_text(s, encoding='utf-8')
print('Signature release configurée dans', p)
