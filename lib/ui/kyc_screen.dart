import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../state/providers.dart';
import 'theme.dart';

/// Écran 5 : certification KYC. Nom, prénom, photo de la pièce et selfie (caméra uniquement) → Cloudinary (envoi direct, signé par le serveur) → identifiant transmis au backend.
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});
  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _numero = TextEditingController();
  XFile? _piece;
  XFile? _selfie;
  bool _busy = false;

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _numero.dispose();
    super.dispose();
  }

  /// Caméra uniquement (jamais la galerie) : la pièce et le selfie doivent être pris sur le moment.
  Future<void> _prendre({required bool selfie}) async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
        maxWidth: 1800,
        imageQuality: 80,
      );
      if (f == null || !mounted) return;
      setState(() {
        if (selfie) {
          _selfie = f;
        } else {
          _piece = f;
        }
      });
    } catch (_) {
      if (mounted) toast(context, 'Caméra inaccessible. Autorisez l’accès à la caméra dans les réglages du téléphone.');
    }
  }

  static final _lettres = RegExp(r"^[\p{L}][\p{L}' .-]{1,59}$", unicode: true);
  bool get _nomOk => _lettres.hasMatch(_nom.text.trim()) && _lettres.hasMatch(_prenom.text.trim());
  bool get _numeroOk => RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(_numero.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''));
  bool get _pret => _nomOk && _numeroOk && _piece != null && _selfie != null;

  Future<void> _submit() async {
    if (!_pret) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(repoProvider);
      final doc = await repo.uploadKycPhoto(_piece!.path);
      final selfie = await repo.uploadKycPhoto(_selfie!.path, selfie: true);
      await repo.submitKyc(nom: _nom.text.trim(), prenom: _prenom.text.trim(), numeroPiece: _numero.text.trim(), documentPath: doc, selfiePath: selfie);
      ref.invalidate(kycProvider);
      ref.invalidate(limitsProvider);
      if (mounted) {
        toast(context, 'Dossier envoyé. Validation en cours.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photo({required String titre, required String aide, required XFile? f, required bool selfie}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text(aide, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 10),
        if (f != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(f.path), height: 200, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _prendre(selfie: selfie),
          icon: Icon(selfie ? Icons.face_retouching_natural : Icons.photo_camera),
          label: Text(f == null ? (selfie ? 'Prendre mon selfie' : 'Photographier la pièce') : 'Reprendre la photo'),
        ),
      ]);

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
              if (s == 'REJETE') const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Votre dernier dossier a été refusé. Vérifiez votre nom et envoyez des photos plus nettes.', style: TextStyle(color: Colors.red))),
              const Text('Vos nom et prénom doivent être ceux de votre pièce d’identité.'),
              const SizedBox(height: 12),
              TextField(controller: _nom, enabled: !_busy, textCapitalization: TextCapitalization.characters, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 10),
              TextField(controller: _prenom, enabled: !_busy, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 10),
              TextField(controller: _numero, enabled: !_busy, textCapitalization: TextCapitalization.characters, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Numéro de la pièce d’identité', helperText: 'Tel qu’il est écrit sur votre CNI ou passeport')),
              const SizedBox(height: 22),
              _photo(titre: '1. Votre pièce d’identité', aide: 'CNI ou passeport : pièce entière, lisible, sans reflet.', f: _piece, selfie: false),
              const SizedBox(height: 22),
              _photo(titre: '2. Votre selfie', aide: 'Visage bien visible, de face, sans lunettes de soleil ni casquette.', f: _selfie, selfie: true),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _pret && !_busy ? _submit : null,
                child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer pour validation'),
              ),
              const SizedBox(height: 8),
              const Text('Les photos sont prises avec la caméra et envoyées de façon sécurisée. Elles ne servent qu’à vérifier votre identité.', style: TextStyle(color: Colors.black54, fontSize: 12)),
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
