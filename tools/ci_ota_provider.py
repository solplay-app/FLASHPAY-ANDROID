#!/usr/bin/env python3
"""Déclare dans android/ ce que le plugin ota_update exige pour installer une mise à jour :
  - le <provider> OtaUpdateFileProvider + res/xml/filepaths.xml (sans eux, l'app plante quand le téléchargement atteint 100 %)
  - le <receiver> InstallResultReceiver
Idempotent. Lancé par .github/workflows/build-android.yml après « flutter create »."""
import pathlib, sys

M = pathlib.Path('android/app/src/main/AndroidManifest.xml')
X = pathlib.Path('android/app/src/main/res/xml/filepaths.xml')
if not M.exists():
    sys.exit('ERREUR : AndroidManifest.xml introuvable (flutter create doit passer avant).')

X.parent.mkdir(parents=True, exist_ok=True)
X.write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<paths xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <files-path name="internal_apk_storage" path="ota_update/"/>\n'
    '</paths>\n',
    encoding='utf-8',
)

PROVIDER = '''
        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/filepaths" />
        </provider>'''
RECEIVER = '''
        <receiver android:name="sk.fourq.otaupdate.InstallResultReceiver" android:exported="false">
            <intent-filter>
                <action android:name="${applicationId}.ACTION_INSTALL_COMPLETE"/>
            </intent-filter>
        </receiver>'''

s = M.read_text(encoding='utf-8')
add = ''
if 'sk.fourq.otaupdate.OtaUpdateFileProvider' not in s:
    add += PROVIDER
if 'sk.fourq.otaupdate.InstallResultReceiver' not in s:
    add += RECEIVER
if add:
    if '</application>' not in s:
        sys.exit('ERREUR : balise </application> introuvable dans AndroidManifest.xml')
    s = s.replace('</application>', add + '\n    </application>', 1)
    M.write_text(s, encoding='utf-8')
print('ota_update : provider, receiver et filepaths.xml OK')
