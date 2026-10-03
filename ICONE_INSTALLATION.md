# Icône FlashPay

1. Copier le dossier `assets/icon/` dans `app/assets/icon/`.
2. Dans `app/pubspec.yaml` :

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
  remove_alpha_ios: true
  adaptive_icon_background: "assets/icon/icon_background.png"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
```

3. `flutter pub get` puis `dart run flutter_launcher_icons`.

Fichiers : `icon.png` (1024, carré, sans transparence : App Store / Play Store),
`icon_foreground.png` + `icon_background.png` (icône adaptative Android),
`flashpay_icon.svg` (source vectorielle).
