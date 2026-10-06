import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/updater.dart';
import 'theme.dart';

/// Affiche un QR code : la personne qui le scanne télécharge la dernière version de FlashPay (lien [kApkUrl]).
class ShareAppScreen extends StatelessWidget {
  const ShareAppScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Partager FlashPay')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text(
              'Faites scanner ce code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fpInk),
            ),
            const SizedBox(height: 6),
            const Text(
              'Votre proche scanne le code avec l’appareil photo de son téléphone pour télécharger et installer FlashPay.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fpMute),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE6E0F5)),
                ),
                // Fond blanc obligatoire : sur un fond sombre, le code ne se scanne pas.
                child: QrImageView(
                  data: kApkUrl,
                  version: QrVersions.auto,
                  size: 250,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR code de téléchargement de FlashPay',
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Pour la personne qui scanne', style: TextStyle(fontWeight: FontWeight.w700, color: fpInk)),
            const SizedBox(height: 6),
            const Text(
              '1. Ouvrir le lien proposé après le scan et télécharger le fichier.\n'
              '2. Si Android le demande, autoriser l’installation depuis ce navigateur.\n'
              '3. Ouvrir le fichier téléchargé et appuyer sur Installer.',
              style: TextStyle(color: fpMute, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: kApkUrl));
                if (context.mounted) toast(context, 'Lien copié. Vous pouvez le coller dans WhatsApp ou un SMS.');
              },
              icon: const Icon(Icons.link),
              label: const Text('Copier le lien'),
            ),
          ]),
        ),
      );
}
