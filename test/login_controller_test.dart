import 'package:flutter_test/flutter_test.dart';
import 'package:my_logbook_app/features/auth/login_controller.dart';

void main() {
  group('Authentication / LoginController Tests', () {
    late LoginController controller;

    setUp(() {
      // (1) Setup (arrange, build)
      controller = LoginController();
    });

    test('TC_Auth_01 - login should return true for valid credentials', () {
      // (2) Exercise (act, operate)
      final result = controller.login('admin', '123');

      // (3) Verify (assert, check)
      expect(result, isTrue, reason: 'Mengembalikan true karena kredensial admin secara default benar');
    });

    test('TC_Auth_02 - login should return false for invalid password', () {
      // (2) Exercise (act, operate)
      final result = controller.login('admin', 'salah123');

      // (3) Verify (assert, check)
      expect(result, isFalse, reason: 'Mengembalikan false karena password salah');
    });

    test('TC_Auth_03 - login should prevent access from unregistered user', () {
      // (2) Exercise (act, operate)
      final result = controller.login('unknown', '123');

      // (3) Verify (assert, check)
      expect(result, isFalse, reason: 'Mengembalikan false karena username tidak ada di data base map');
    });
  });
}
