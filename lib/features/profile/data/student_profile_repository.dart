import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/student_identity_helper.dart';
import '../../../models/student_profile_model.dart';
import '../../../services/nexora_api_service.dart';
import '../../authentication/data/auth_service.dart';

/// Exception thrown when a student profile operation fails
class NexoraProfileException implements Exception {
  final String message;
  final String? code;

  const NexoraProfileException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Repository responsible for reading and writing student profiles in Firestore (`students/{uid}`)
/// and connecting to the official BVC student portal via the backend API.
class StudentProfileRepository {
  final FirebaseFirestore? _injectedFirestore;

  StudentProfileRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _studentsRef =>
      _firestore.collection('students');

  /// Retrieve the [StudentProfile] for a given [uid].
  /// Returns `null` if the document does not exist.
  Future<StudentProfile?> getProfile(String uid) async {
    try {
      debugPrint('[StudentProfileRepository] Loading profile from students/$uid');
      final doc = await _studentsRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint('[StudentProfileRepository] No profile found at students/$uid');
        return null;
      }
      return StudentProfile.fromFirestore(doc);
    } on FirebaseException catch (e) {
      debugPrint(
        '[StudentProfileRepository] getProfile FirebaseException:\n'
        '  - Type: ${e.runtimeType}\n'
        '  - Code: ${e.code}\n'
        '  - Message: ${e.message}\n'
        '  - Path: students/$uid',
      );
      throw NexoraProfileException(
        'Unable to load your profile. Please check your connection.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('[StudentProfileRepository] getProfile error: $e');
      throw const NexoraProfileException(
        'An unexpected error occurred while loading your profile.',
        code: 'unknown',
      );
    }
  }

  /// Check whether the profile for [uid] exists and is marked as complete
  Future<bool> isProfileComplete(String uid) async {
    try {
      final profile = await getProfile(uid);
      return profile != null && profile.profileSetupCompleted;
    } catch (_) {
      return false;
    }
  }

  /// Connects to the official BVC student portal using the student's roll number.
  /// Calls POST /student/bvc/connect on the Nexora Cloudflare Worker.
  /// When successfully authenticated against the official portal, returns verified data
  /// and completes the student profile in Firestore.
  Future<Map<String, dynamic>> connectBvcStudent(String rawRollNumber) async {
    final rollNumber = rawRollNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (rollNumber.isEmpty) {
      throw const NexoraProfileException('Please enter your BVC roll number.', code: 'empty-roll');
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw const NexoraProfileException('No authenticated session found. Please sign in again.', code: 'no-user');
    }

    final idToken = await currentUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const NexoraProfileException('Authentication token unavailable. Please re-login.', code: 'no-token');
    }

    final url = Uri.parse('${NexoraApiService.defaultBaseUrl}/student/bvc/connect');
    http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'User-Agent': 'Nexora-Flutter-App/1.0',
        },
        body: jsonEncode({
          'rollNumber': rollNumber,
        }),
      ).timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('[StudentProfileRepository] connectBvcStudent network error: $e');
      throw const NexoraProfileException(
        'Unable to reach the official BVC student portal. Please check your network and try again.',
        code: 'network-error',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const NexoraProfileException(
        'Unexpected response from BVC portal service.',
        code: 'invalid-response',
      );
    }

    if (response.statusCode != 200 || body['success'] != true) {
      final msg = body['message'] as String? ?? body['error'] as String? ?? 'Failed to authenticate with official BVC portal.';
      throw NexoraProfileException(msg, code: 'portal-auth-failed');
    }

    final syncData = body['sync'] as Map<String, dynamic>? ?? {};
    final profileData = syncData['profile'] as Map<String, dynamic>? ?? {};

    final studentName = profileData['name'] as String? ?? 'BVC Student';
    final branch = profileData['branch'] as String? ?? 'Engineering';
    final course = profileData['course'] as String? ?? 'B.Tech';
    final batch = profileData['academic_batch'] as String? ?? '2025 - 2026';
    final collegeEmail = profileData['college_email'] as String? ?? currentUser.email ?? '$rollNumber@bvcgroup.in';
    final yearNum = profileData['year'] is int ? profileData['year'] as int : 1;
    final semNum = profileData['semester'] is int ? profileData['semester'] as int : 1;
    const college = 'BONAM VENKATA CHALAMAYYA ENGINEERING COLLEGE';

    // Persist verified profile to Firestore
    try {
      final docRef = _studentsRef.doc(currentUser.uid);
      final existingDoc = await docRef.get();

      final studentProfile = StudentProfile(
        uid: currentUser.uid,
        email: collegeEmail.toLowerCase(),
        rollNumber: rollNumber,
        batchCode: batch,
        academicYear: yearNum,
        academicYearLabel: '$yearNum B.Tech',
        studentClass: branch,
        section: 'A', // Default indicator as official portal does not expose section
        role: 'student',
        college: college,
        profileSetupCompleted: true,
        createdAt: existingDoc.exists ? null : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mapData = studentProfile.toMap(forUpdate: existingDoc.exists);
      mapData['fullName'] = studentName;
      mapData['course'] = course;
      mapData['semester'] = semNum;
      mapData['bvcPortalVerified'] = true;

      await docRef.set(mapData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[StudentProfileRepository] Firestore save error: $e');
    }

    return {
      'rollNumber': rollNumber,
      'name': studentName,
      'branch': branch,
      'course': course,
      'semester': semNum,
      'year': yearNum,
      'batch': batch,
      'college': college,
      'email': collegeEmail,
    };
  }

  /// Complete one-time profile setup with class and section (legacy/manual fallback).
  Future<StudentProfile> completeProfileSetup({
    required String uid,
    required String email,
    required String studentClass,
    required String section,
  }) async {
    final identity = StudentIdentityHelper.extractFromEmail(email);
    if (identity == null) {
      throw const NexoraProfileException(
        'Only valid BVC college emails starting with 23, 24, 25, or 26 can complete profile setup.',
        code: 'invalid-student-email',
      );
    }

    if (studentClass.trim().isEmpty || section.trim().isEmpty) {
      throw const NexoraProfileException(
        'Please select both Class/Branch and Section to proceed.',
        code: 'missing-class-section',
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw const NexoraProfileException(
        'No authenticated user session found. Please sign in again.',
        code: 'no-user',
      );
    }

    try {
      await currentUser.reload();
    } catch (_) {
      debugPrint('[StudentProfileRepository] Warning: user.reload() failed.');
    }

    final freshUser = FirebaseAuth.instance.currentUser;
    if (freshUser == null) {
      throw const NexoraProfileException(
        'Authentication session expired. Please sign in again.',
        code: 'session-expired',
      );
    }

    if (!freshUser.emailVerified) {
      throw const NexoraProfileException(
        'Your email is not verified. Please verify your email and try again.',
        code: 'email-not-verified',
      );
    }

    try {
      final docRef = _studentsRef.doc(freshUser.uid);
      final existingDoc = await docRef.get();

      if (existingDoc.exists &&
          existingDoc.data()?['profileSetupCompleted'] == true) {
        return StudentProfile.fromFirestore(existingDoc);
      }

      final profile = StudentProfile(
        uid: freshUser.uid,
        email: identity.email,
        rollNumber: identity.rollNumber,
        batchCode: identity.batchCode,
        academicYear: identity.academicYear,
        academicYearLabel: identity.academicYearLabel,
        studentClass: studentClass.trim(),
        section: section.trim(),
        role: 'student',
        college: identity.college,
        profileSetupCompleted: true,
        createdAt: existingDoc.exists ? null : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mapData = profile.toMap(forUpdate: existingDoc.exists);
      if (!existingDoc.exists) {
        await docRef.set(mapData);
      } else {
        await docRef.set(mapData, SetOptions(merge: true));
      }

      return profile;
    } on FirebaseException catch (e) {
      throw NexoraProfileException(
        '${e.code}: ${e.message ?? 'Failed to save student profile.'}',
        code: e.code,
      );
    } catch (e) {
      throw const NexoraProfileException(
        'An unexpected error occurred while saving your profile.',
        code: 'unknown',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final studentProfileRepositoryProvider =
    Provider<StudentProfileRepository>((ref) {
  return StudentProfileRepository();
});

/// Future provider to fetch the current student profile
final currentStudentProfileProvider =
    FutureProvider<StudentProfile?>((ref) async {
  final repository = ref.watch(studentProfileRepositoryProvider);
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;
  return repository.getProfile(authState.uid);
});
