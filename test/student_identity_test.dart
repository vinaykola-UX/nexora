import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/constants/student_identity_helper.dart';
import 'package:nexora/models/student_profile_model.dart';

void main() {
  group('StudentIdentityHelper Tests', () {
    test(
        'TEST 1: Standard email 25221a0568@bvcgroup.in extracts correct roll number and 2nd B.Tech',
        () {
      const email = '25221a0568@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '25221A0568');
      expect(identity.batchCode, '25');
      expect(identity.academicYear, 2);
      expect(identity.academicYearLabel, '2nd B.Tech');
      expect(identity.email, '25221a0568@bvcgroup.in');
    });

    test(
        'TEST 2: Variable length roll number 25221a607@bvcgroup.in is accepted and preserved',
        () {
      const email = '25221a607@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '25221A607');
      expect(identity.batchCode, '25');
      expect(identity.academicYear, 2);
      expect(identity.academicYearLabel, '2nd B.Tech');
    });

    test(
        'TEST 3: Digits-only local part 25221356@bvcgroup.in is accepted without requiring letters',
        () {
      const email = '25221356@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '25221356');
      expect(identity.batchCode, '25');
      expect(identity.academicYear, 2);
      expect(identity.academicYearLabel, '2nd B.Tech');
    });

    test('TEST 4: 26 batch maps to 1st B.Tech', () {
      const email = '26221A0568@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '26221A0568');
      expect(identity.batchCode, '26');
      expect(identity.academicYear, 1);
      expect(identity.academicYearLabel, '1st B.Tech');
    });

    test('TEST 5: 24 batch maps to 3rd B.Tech', () {
      const email = '24221A0568@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '24221A0568');
      expect(identity.batchCode, '24');
      expect(identity.academicYear, 3);
      expect(identity.academicYearLabel, '3rd B.Tech');
    });

    test('TEST 6: 23 batch maps to 4th B.Tech', () {
      const email = '23221A0568@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isTrue);

      final identity = StudentIdentityHelper.extractFromEmail(email);
      expect(identity, isNotNull);
      expect(identity!.rollNumber, '23221A0568');
      expect(identity.batchCode, '23');
      expect(identity.academicYear, 4);
      expect(identity.academicYearLabel, '4th B.Tech');
    });

    test(
        'TEST 7: Returning student profile with profileSetupCompleted: true is complete',
        () {
      final profile = StudentProfile(
        uid: 'user_123',
        email: '25221a0568@bvcgroup.in',
        rollNumber: '25221A0568',
        batchCode: '25',
        academicYear: 2,
        academicYearLabel: '2nd B.Tech',
        studentClass: 'CSE',
        section: 'Section A',
        profileSetupCompleted: true,
      );

      expect(profile.profileSetupCompleted, isTrue);
      expect(profile.studentClass, 'CSE');
      expect(profile.section, 'Section A');

      final map = profile.toMap();
      expect(map['profileSetupCompleted'], isTrue);
      expect(map['class'], 'CSE');
      expect(map['section'], 'Section A');
      expect(map['rollNumber'], '25221A0568');
    });

    test('TEST 8: Incomplete profile has profileSetupCompleted != true', () {
      final profile = StudentProfile(
        uid: 'user_456',
        email: '25221a0568@bvcgroup.in',
        rollNumber: '25221A0568',
        batchCode: '25',
        academicYear: 2,
        academicYearLabel: '2nd B.Tech',
        studentClass: '',
        section: '',
        profileSetupCompleted: false,
      );

      expect(profile.profileSetupCompleted, isFalse);
    });

    test('TEST 9: Non-BVC domain 25221A0568@gmail.com is rejected', () {
      const email = '25221A0568@gmail.com';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isFalse);
      expect(StudentIdentityHelper.extractFromEmail(email), isNull);
    });

    test('TEST 10: Unsupported prefix 22221A0568@bvcgroup.in is rejected', () {
      const email = '22221A0568@bvcgroup.in';
      expect(StudentIdentityHelper.isValidStudentEmail(email), isFalse);
      expect(StudentIdentityHelper.extractFromEmail(email), isNull);
    });
  });

  group('Built-in BVC Branches List', () {
    test('All 9 official BVC engineering branches are present', () {
      expect(kBvcBranches.length, 9);
      final codes = kBvcBranches.map((b) => b.code).toList();
      expect(
          codes,
          containsAll([
            'CSE',
            'CSM',
            'CAD',
            'AIM',
            'ECE',
            'IT',
            'EEE',
            'MECH',
            'CIVIL'
          ]));
    });
  });
}
