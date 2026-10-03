import 'package:dio/dio.dart';
import '../core/api.dart';
import '../core/models.dart';

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
    required String idempotencyKey,
    String? cagnotteCode,
  }) =>
      _run(() async {
        final r = await _dio.post('/transfers', data: {
          'netAmount': net,
          'senderOperator': sender.api,
          'receiverOperator': receiver.api,
          'receiverPhone': phone,
          'idempotencyKey': idempotencyKey,
          if (cagnotteCode != null) 'cagnotteCode': cagnotteCode,
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
  Future<String> firebaseToken() => _run(() async => (await _dio.get('/kyc/firebase-token')).data['token'] as String);
  Future<String> userId() => _run(() async => (await _dio.get('/kyc/me')).data['id'] as String);

  Future<List<Cagnotte>> cagnottes() => _run(() async => ((await _dio.get('/cagnottes')).data as List).map((e) => Cagnotte.fromJson(e)).toList());
  Future<Cagnotte> cagnotte(String code) => _run(() async => Cagnotte.fromJson((await _dio.get('/cagnottes/${code.trim().toUpperCase()}')).data));
  Future<Cagnotte> createCagnotte({required String nom, required int objectif, required String dateFin, required Op op, required String phone}) =>
      _run(() async => Cagnotte.fromJson((await _dio.post('/cagnottes', data: {
            'nom': nom, 'objectif': objectif, 'dateFin': dateFin, 'operateur': op.api, 'telephone': phone,
          })).data));
  Future<void> closeCagnotte(String id) => _run(() => _dio.post('/cagnottes/$id/close'));
}
