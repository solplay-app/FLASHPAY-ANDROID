import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Nombre de chiffres du code PIN (doit rester identique à PIN_LENGTH dans le backend, src/pin.ts).
const kPinLength = 6;

/// Empreinte digitale = simple raccourci pour retrouver le PIN.
/// Le serveur vérifie TOUJOURS le PIN : si l'empreinte est activée, le PIN est mémorisé dans le coffre sécurisé du téléphone
/// (Android Keystore) et n'est relu qu'après une empreinte réussie. Rien n'est jamais validé uniquement côté téléphone.
class PinService {
  PinService._();

  static const _storage = FlutterSecureStorage();
  static const _kBioPin = 'bio_pin';
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Le téléphone a un capteur ET au moins une empreinte enregistrée.
  static Future<bool> biometricAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// L'utilisateur a activé l'empreinte dans FlashPay.
  static Future<bool> biometricEnabled() async {
    try {
      return (await _storage.read(key: _kBioPin)) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _prompt(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Demande l'empreinte ; si elle est reconnue, renvoie le PIN mémorisé. Sinon null (annulé, échec, non activée).
  static Future<String?> unlockWithBiometric(String reason) async {
    try {
      final pin = await _storage.read(key: _kBioPin);
      if (pin == null) return null;
      if (!await _prompt(reason)) return null;
      return pin;
    } catch (_) {
      return null;
    }
  }

  /// Active l'empreinte : on vérifie d'abord qu'elle fonctionne, puis on mémorise le PIN (déjà validé par le serveur).
  static Future<bool> enableBiometric(String pin) async {
    if (!await biometricAvailable()) return false;
    if (!await _prompt('Confirmez votre empreinte pour l’activer')) return false;
    try {
      await _storage.write(key: _kBioPin, value: pin);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Le PIN a changé : on met à jour la copie protégée par l'empreinte (si elle est activée).
  static Future<void> updateBiometricPin(String pin) async {
    if (await biometricEnabled()) {
      try {
        await _storage.write(key: _kBioPin, value: pin);
      } catch (_) {}
    }
  }

  /// Désactive l'empreinte (désactivation volontaire, déconnexion, PIN mémorisé devenu faux).
  static Future<void> clearBiometric() async {
    try {
      await _storage.delete(key: _kBioPin);
    } catch (_) {}
  }
}
