import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

const supportPhone = '+2250105147123';
const supportPhoneLabel = '+225 01 05 14 71 23';
const supportEmail = 'flashpay@gmail.com';

Future<void> _open(BuildContext c, Uri u) async {
  if (!await launchUrl(u) && c.mounted) toast(c, 'Action impossible sur cet appareil');
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Support')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Un problème avec un transfert ? Contactez-nous en indiquant le montant, l’heure et le numéro du destinataire.'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.call, color: brand),
                title: const Text(supportPhoneLabel),
                subtitle: const Text('Appeler le support'),
                onTap: () => _open(context, Uri(scheme: 'tel', path: supportPhone)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined, color: brand),
                title: const Text(supportEmail),
                subtitle: const Text('Écrire au support'),
                onTap: () => _open(context, Uri(scheme: 'mailto', path: supportEmail, query: 'subject=Support FlashPay')),
              ),
            ),
          ]),
        ),
      );
}
