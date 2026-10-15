import 'package:dio/dio.dart';
import '../core/api.dart';
import '../core/models.dart';
import '../core/prets_models.dart';

class Repo {
  Repo(this._dio);
  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> requestOtp(String phone) => _run(() => _dio.post('/auth/request-otp', data: {'numeroTelephone': phone}));

  Future<String> verifyOtp(String phone, String code) => _run(() async {
        final r = await _dio.post('/auth/verify-otp', data: {'numeroTelephone': phone, 'code': code});
        return r.data['token'] as String;
      });

  Future<Quote> quote(int net) =>
      _run(() async => Quote.fromJson((await _dio.get('/transfers/quote', queryParameters: {'net': net})).data));

  Future<Transfer> create({
    required int net,
    required Op sender,
    required Op receiver,
    required String phone,
    required String payerPhone,
    required String idempotencyKey,
    String? cagnotteCode,
    String? pin,
  }) =>
      _run(() async {
        final r = await _dio.post('/transfers', data: {
          'netAmount': net,
          'senderOperator': sender.api,
          'receiverOperator': receiver.api,
          'receiverPhone': phone,
          'payerPhone': payerPhone,
          'idempotencyKey': idempotencyKey,
          if (cagnotteCode != null) 'cagnotteCode': cagnotteCode,
          if (pin != null) 'pin': pin, // vérifié par le serveur (code PIN obligatoire pour toute transaction)
        });
        return Transfer.fromJson(r.data);
      });

  Future<List<Transfer>> transfers() => _run(() async {
        final r = await _dio.get('/transfers');
        return (r.data as List).map((e) => Transfer.fromJson(e)).toList();
      });

  Future<Transfer> transfer(String id) => _run(() async => Transfer.fromJson((await _dio.get('/transfers/$id')).data));

  Future<Limits> limits() => _run(() async => Limits.fromJson((await _dio.get('/transfers/limits')).data));

  Future<String> kycStatus() => _run(() async => (await _dio.get('/kyc')).data['kycStatut'] as String);
  Future<void> submitKyc(String path) => _run(() => _dio.post('/kyc', data: {'documentPath': path}));
  /// Envoi de la pièce : signature fournie par le serveur, puis envoi DIRECT à Cloudinary (client sans jeton FlashPay :
  /// la clé secrète reste sur le serveur). Renvoie l'identifiant du fichier à transmettre à [submitKyc].
  Future<String> uploadKycPhoto(String filePath) => _run(() async {
        final sig = (await _dio.get('/kyc/upload-signature')).data as Map;
        final up = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 30)));
        final r = await up.post(sig['uploadUrl'] as String,
            data: FormData.fromMap({
              'file': await MultipartFile.fromFile(filePath, filename: 'cni.jpg'),
              'api_key': sig['apiKey'],
              'timestamp': sig['timestamp'],
              'signature': sig['signature'],
              'public_id': sig['publicId'],
              'type': sig['type'],
              'allowed_formats': sig['allowedFormats'],
            }));
        return (r.data['public_id'] ?? sig['publicId']).toString();
      });
  Future<String> userId() => _run(() async => (await _dio.get('/kyc/me')).data['id'] as String);

  Future<List<Cagnotte>> cagnottes() => _run(() async => ((await _dio.get('/cagnottes')).data as List).map((e) => Cagnotte.fromJson(e)).toList());
  Future<Cagnotte> cagnotte(String code) => _run(() async => Cagnotte.fromJson((await _dio.get('/cagnottes/${code.trim().toUpperCase()}')).data));
  Future<Cagnotte> createCagnotte({required String nom, required int objectif, required String dateFin, required Op op, required String phone}) =>
      _run(() async => Cagnotte.fromJson((await _dio.post('/cagnottes', data: {
            'nom': nom, 'objectif': objectif, 'dateFin': dateFin, 'operateur': op.api, 'telephone': phone,
          })).data));
  Future<void> closeCagnotte(String id) => _run(() => _dio.post('/cagnottes/$id/close'));

  // Compte connecté : { id, numeroTelephone, kycStatut }
  Future<Map<String, dynamic>> me() => _run(() async => Map<String, dynamic>.from((await _dio.get('/me')).data as Map));

  // Messages de FlashPay (maintenance, incident, bonus…) : { nonLus: int, rows: [...] }
  Future<Map<String, dynamic>> notices() => _run(() async => Map<String, dynamic>.from((await _dio.get('/notices')).data as Map));
  Future<void> readAllNotices() => _run(() => _dio.post('/notices/read-all'));

  // Notifications push : envoie le jeton Firebase du téléphone au serveur.
  // Code PIN : état, création, vérification, changement, réinitialisation par SMS.
  Future<PinStatus> pinStatus() => _run(() async => PinStatus.fromJson(Map<String, dynamic>.from((await _dio.get('/pin/status')).data as Map)));
  Future<void> setPin(String pin) => _run(() => _dio.post('/pin/set', data: {'pin': pin}));
  Future<void> verifyPin(String pin) => _run(() => _dio.post('/pin/verify', data: {'pin': pin}));
  Future<void> changePin(String ancien, String nouveau) => _run(() => _dio.post('/pin/change', data: {'ancien': ancien, 'nouveau': nouveau}));
  Future<void> resetPin(String code, String nouveau) => _run(() => _dio.post('/pin/reset', data: {'code': code, 'nouveau': nouveau}));


  // --- Petits prêts ---
  Future<PretsData> prets() => _run(() async => PretsData.fromJson((await _dio.get('/prets')).data));
  Future<Pret> pret(String id) => _run(() async => Pret.fromJson((await _dio.get('/prets/$id')).data));
  Future<Pret> accepterPret({required String offreId, required int montant, required Op op, required String idempotencyKey, required String pin}) =>
      _run(() async => Pret.fromJson((await _dio.post('/prets/accepter', data: {
            'offreId': offreId, 'montant': montant, 'operateur': op.api, 'idempotencyKey': idempotencyKey, 'pin': pin,
          })).data));
  Future<Pret> rembourserPret({required String id, required Op op, required String payerPhone, required String idempotencyKey, required String pin}) =>
      _run(() async => Pret.fromJson((await _dio.post('/prets/$id/rembourser', data: {
            'operateur': op.api, 'payerPhone': payerPhone, 'idempotencyKey': idempotencyKey, 'pin': pin,
          })).data));
}

/// État du code PIN du compte (réponse de GET /pin/status).
class PinStatus {
  PinStatus({required this.defini, this.secondesBloque = 0});
  final bool defini;
  final int secondesBloque;
  factory PinStatus.fromJson(Map<String, dynamic> j) => PinStatus(defini: j['defini'] == true, secondesBloque: (j['secondesBloque'] as num?)?.toInt() ?? 0);
}
