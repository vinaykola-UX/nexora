import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/authentication/data/auth_service.dart';

void main() {
  group('AuthService - Domain Validation (@bvcgroup.in)', () {
    test('allows exact valid @bvcgroup.in email addresses', () {
      expect(AuthService.isAllowedDomain('student@bvcgroup.in'), isTrue);
      expect(AuthService.isAllowedDomain('faculty@bvcgroup.in'), isTrue);
      expect(AuthService.isAllowedDomain('principal@bvcgroup.in'), isTrue);
      expect(AuthService.isAllowedDomain('21bvc0452@bvcgroup.in'), isTrue);
      expect(AuthService.isAllowedDomain('STUDENT@BVCGROUP.IN'), isTrue);
      expect(AuthService.isAllowedDomain('  student@bvcgroup.in  '), isTrue);
    });

    test('rejects non-bvcgroup.in email domains', () {
      expect(AuthService.isAllowedDomain('student@gmail.com'), isFalse);
      expect(AuthService.isAllowedDomain('student@yahoo.com'), isFalse);
      expect(AuthService.isAllowedDomain('student@bvcgroup.com'), isFalse);
      expect(AuthService.isAllowedDomain('fake@notbvcgroup.in'), isFalse);
      expect(AuthService.isAllowedDomain('student@bvc.edu.in'), isFalse);
      expect(AuthService.isAllowedDomain('hacker@bvcgroup.in.com'), isFalse);
      expect(AuthService.isAllowedDomain('hacker@sub.bvcgroup.in'), isFalse);
    });

    test('rejects null, empty, or malformed email strings', () {
      expect(AuthService.isAllowedDomain(null), isFalse);
      expect(AuthService.isAllowedDomain(''), isFalse);
      expect(AuthService.isAllowedDomain('   '), isFalse);
      expect(AuthService.isAllowedDomain('bvcgroup.in'), isFalse);
      expect(AuthService.isAllowedDomain('@bvcgroup.in'), isFalse);
      expect(AuthService.isAllowedDomain('student@bvcgroup.in@other'), isFalse);
    });
  });
}
