#!/usr/bin/env python3
"""Ajoute permissions Android/iOS (contacts, caméra, notifications, internet) après `flutter create .`.
Idempotent : peut être relancé sans doublon.   Usage : python3 tools/apply_platform_config.py
"""
import pathlib, sys

ANDROID = pathlib.Path('android/app/src/main/AndroidManifest.xml')
IOS = pathlib.Path('ios/Runner/Info.plist')

PERMS = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.READ_CONTACTS"/>',
    '<uses-permission android:name="android.permission.CAMERA"/>',
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',  # Android 13+ : demandée à l'exécution
    '<uses-feature android:name="android.hardware.camera" android:required="false"/>',
]
QUERY_INTENTS = [
    ('android.intent.action.VIEW', 'https', None),
    ('android.intent.action.DIAL', 'tel', None),
    ('android.intent.action.SENDTO', 'mailto', None),
]

def patch_android():
    if not ANDROID.exists():
        return print('Android : manifest introuvable (lancez `flutter create .` d’abord)')
    s = ANDROID.read_text(encoding='utf8')
    add = [p for p in PERMS if p.split('"')[1] not in s]
    if add:
        s = s.replace('<application', '\n    '.join(add) + '\n    <application', 1)
    intents = ''
    for action, scheme, _ in QUERY_INTENTS:
        if f'android:scheme="{scheme}"' not in s:
            intents += f'        <intent>\n            <action android:name="{action}"/>\n            <data android:scheme="{scheme}"/>\n        </intent>\n'
    if intents:
        if '</queries>' in s:
            s = s.replace('</queries>', intents + '    </queries>', 1)
        else:
            s = s.replace('</manifest>', '    <queries>\n' + intents + '    </queries>\n</manifest>', 1)
    ANDROID.write_text(s, encoding='utf8')
    print('Android : permissions OK')

PLIST = {
    'NSContactsUsageDescription': 'FlashPay utilise vos contacts pour choisir le destinataire.',
    'NSCameraUsageDescription': 'FlashPay utilise la caméra pour photographier votre pièce d’identité.',
    'NSPhotoLibraryUsageDescription': 'FlashPay accède à vos photos pour envoyer votre pièce d’identité.',
}

def patch_ios():
    if not IOS.exists():
        return print('iOS : Info.plist introuvable (ignoré)')
    s = IOS.read_text(encoding='utf8')
    add = ''.join(f'\t<key>{k}</key>\n\t<string>{v}</string>\n' for k, v in PLIST.items() if k not in s)
    if 'LSApplicationQueriesSchemes' not in s:
        add += '\t<key>LSApplicationQueriesSchemes</key>\n\t<array>\n\t\t<string>tel</string>\n\t\t<string>mailto</string>\n\t\t<string>https</string>\n\t</array>\n'
    if add:
        i = s.rindex('</dict>')
        s = s[:i] + add + s[i:]
        IOS.write_text(s, encoding='utf8')
    print('iOS : Info.plist OK')

patch_android()
patch_ios()
