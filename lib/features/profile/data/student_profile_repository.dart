import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/student_identity_helper.dart';
import '../../../models/student_profile_model.dart';
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
class StudentProfileRepository {
  final FirebaseFirestore? _injectedFirestore;

  StudentProfileRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

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

  /// Complete one-time profile setup with class and section.
  /// Automatically extracts identity from [email], merges into Firestore `students/{uid}`,
  /// and marks profileSetupCompleted = true.
  Future<StudentProfile> completeProfileSetup({
    required String uid,
    required String email,
    required String studentClass,
    required String section,
  }) async {
    // 1. Validate email and extract identity
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

    // 2. Reload Auth user to ensure the token is fresh and emailVerified is current
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
      // Non-fatal: proceed even if reload fails (offline scenario)
      debugPrint('[StudentProfileRepository] Warning: user.reload() failed — proceeding with cached auth state.');
    }

    // Re-fetch after reload to get the latest emailVerified state
    final freshUser = FirebaseAuth.instance.currentUser;
    if (freshUser == null) {
      throw const NexoraProfileException(
        'Authentication session expired. Please sign in again.',
        code: 'session-expired',
      );
    }

    debugPrint(
      '[StudentProfileRepository] Pre-write Auth State:\n'
      '  - UID           : ${freshUser.uid}\n'
      '  - Email         : ${freshUser.email}\n'
      '  - EmailVerified : ${freshUser.emailVerified}\n'
      '  - Target Path   : students/${freshUser.uid}',
    );

    if (!freshUser.emailVerified) {
      throw const NexoraProfileException(
        'Your email is not verified. Please verify your email and try again.',
        code: 'email-not-verified',
      );
    }

    try {
      final docRef = _studentsRef.doc(freshUser.uid);
      debugPrint('[StudentProfileRepository] Checking existing profile at students/${freshUser.uid}');
      final existingDoc = await docRef.get();

      // If already complete, prevent modifying immutable fields
      if (existingDoc.exists && existingDoc.data()?['profileSetupCompleted'] == true) {
        debugPrint('[StudentProfileRepository] Profile already completed for ${freshUser.uid} at students/${freshUser.uid}');
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
      debugPrint('[StudentProfileRepository] Writing profile to students/${freshUser.uid}:\n$mapData');

      // Save to Firestore — use set (no merge) on first creation to satisfy security rule hasAll check
      if (!existingDoc.exists) {
        await docRef.set(mapData);
      } else {
        await docRef.set(mapData, SetOptions(merge: true));
      }

      debugPrint('[StudentProfileRepository] Successfully completed profile for ${profile.rollNumber} (${freshUser.uid}) at students/${freshUser.uid}');
      return profile;
    } on FirebaseException catch (e) {
      final logUser = FirebaseAuth.instance.currentUser;
      debugPrint(
        '═══════════════════════════════════════════════════════════════════════\n'
        '[StudentProfileRepository] Firestore Write Error:\n'
        '  - Exception Type : ${e.runtimeType}\n'
        '  - Firebase Code  : ${e.code}\n'
        '  - Error Message  : ${e.message}\n'
        '  - Target Path    : students/$uid\n'
        '  - Auth UID       : ${logUser?.uid}\n'
        '  - User Email     : ${logUser?.email}\n'
        '  - Email Verified : ${logUser?.emailVerified}\n'
        '═══════════════════════════════════════════════════════════════════════',
      );
      if (e.code == 'permission-denied') {
        // In debug mode, include the code so we can see exactly what Firestore rejected
        final detail = kDebugMode ? ' [code: permission-denied] — Deploy Firestore rules in Firebase Console.' : '';
        throw NexoraProfileException(
          'Unable to save profile: database rules rejected this request.$detail',
          code: 'permission-denied',
        );
      } else if (e.code == 'unavailable') {
        throw const NexoraProfileException(
          'Firestore service unavailable. Please check your internet connection.',
          code: 'unavailable',
        );
      } else if (e.code == 'not-found') {
        throw const NexoraProfileException(
          'Firestore database not found. Please ensure the database is created in Firebase Console.',
          code: 'not-found',
        );
      }
      throw NexoraProfileException(
        '${e.code}: ${e.message ?? 'Failed to save student profile. Please try again.'}',
        code: e.code,
      );
    } catch (e, stackTrace) {
      debugPrint('[StudentProfileRepository] Unexpected saveProfile error: $e\n$stackTrace');
      throw const NexoraProfileException(
        'An unexpected error occurred while saving your profile. Please try again.',
        code: 'unknown',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final studentProfileRepositoryProvider = Provider<StudentProfileRepository>((ref) {
  return StudentProfileRepository();
});

/// Future provider to fetch the current student profile
final currentStudentProfileProvider = FutureProvider<StudentProfile?>((ref) async {
  final repository = ref.watch(studentProfileRepositoryProvider);
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;
  return repository.getProfile(authState.uid);
});
