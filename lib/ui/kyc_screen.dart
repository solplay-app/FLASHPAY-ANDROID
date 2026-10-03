import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../state/providers.dart';
import 'theme.dart';

/// Écran 5 : certification KYC. Photo de la pièce → Firebase Storage (kyc/<id>/<fichier>) → chemin transmis au backend.
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});
  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  XFile? _photo;
  bool _busy = false;

  Future<void> _pick(ImageSource s) async {
    final f = await ImagePicker().pickImage(source: s, maxWidth: 1800, imageQuality: 80);
    if (f != null) setState(() => _photo = f);
  }

  Future<void> _submit() async {
    if (_photo == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(repoProvider);
      // Le backend délivre un jeton Firebase lié à l'id du compte : les Storage Rules limitent chacun à son dossier.
      await FirebaseAuth.instance.signInWithCustomToken(await repo.firebaseToken());
      final uid = await repo.userId();
      final path = 'kyc/$uid/cni_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await FirebaseStorage.instance.ref(path).putFile(File(_photo!.path), SettableMetadata(contentType: 'image/jpeg'));
      await repo.submitKyc(path);
      ref.invalidate(kycProvider);
      ref.invalidate(limitsProvider);
      if (mounted) {
        toast(context, 'Pièce envoyée. Validation en cours.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, e is FirebaseException ? 'Envoi impossible (${e.code})' : e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(kycProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification d’identité')),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => switch (s) {
          'VALIDE' => const _Info(Icons.verified, Colors.green, 'Identité vérifiée', 'Vos plafonds de transfert sont relevés.'),
          'EN_ATTENTE' => const _Info(Icons.hourglass_top, Colors.orange, 'Dossier en cours d’examen', 'Nous vous prévenons dès la validation.'),
          _ => ListView(padding: const EdgeInsets.all(16), children: [
              if (s == 'REJETE') const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Votre dernier dossier a été refusé. Envoyez une photo plus nette.', style: TextStyle(color: Colors.red))),
              const Text('Photographiez votre CNI ou votre passeport : pièce entière, lisible, sans reflet.'),
              const SizedBox(height: 16),
              if (_photo != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_photo!.path), height: 220, fit: BoxFit.cover)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Photo'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Galerie'))),
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _photo == null || _busy ? null : _submit,
                child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer pour validation'),
              ),
            ]),
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.color, this.title, this.text);
  final IconData icon;
  final Color color;
  final String title, text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
