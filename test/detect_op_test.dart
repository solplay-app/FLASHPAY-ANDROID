import 'package:flutter_test/flutter_test.dart';
import 'package:flashpay_app/core/models.dart';

void main() {
  test('détection du réseau par préfixe', () {
    expect(detectOp('0102030405'), Op.moov);
    expect(detectOp('0512345678'), Op.mtn);
    expect(detectOp('0700000000'), Op.orange);
    expect(detectOp('07'), Op.orange);
    expect(detectOp('0'), isNull);
    expect(detectOp(''), isNull);
    expect(detectOp('0212345678'), isNull);
    expect(detectOp('2712345678'), isNull);
  });
}
