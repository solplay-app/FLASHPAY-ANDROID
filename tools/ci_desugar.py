"""Monte desugar_jdk_libs à 2.1.4 (exigé par le plugin ota_update).
Lancé par le workflow après ci_prepare_android.py : cherche la ligne dans les fichiers Gradle d'android/."""
import pathlib
import re
import sys

CIBLE = '2.1.4'
motif = re.compile(r'(desugar_jdk_libs(?:_nio)?:)(\d+(?:\.\d+)*)')
trouve = False
for p in pathlib.Path('android').rglob('*.gradle*'):
    if not p.is_file():
        continue
    s = p.read_text(encoding='utf-8')
    if not motif.search(s):
        continue
    n = motif.sub(lambda m: m.group(1) + CIBLE, s)
    trouve = True
    if n != s:
        p.write_text(n, encoding='utf-8')
        print('desugar_jdk_libs ->', CIBLE, 'dans', p)
    else:
        print('desugar_jdk_libs déjà à', CIBLE, 'dans', p)
if not trouve:
    sys.exit('ERREUR : ligne desugar_jdk_libs introuvable dans android/. Envoyer ce message à l’assistant avec le fichier tools/ci_prepare_android.py.')
