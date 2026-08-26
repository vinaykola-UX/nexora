import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexora/core/constants/student_identity_helper.dart';
import 'package:nexora/models/student_profile_model.dart';
import 'package:nexora/features/authentication/data/auth_service.dart';

/// Exception thrown when a student profile operation fails
class NexoraProfileException implements Exception {
  final String message;
  final String? code;

  const NexoraProfileException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Repository responsible for reading and writing student profiles in Firestore (`users/{uid}`)
class StudentProfileRepository {
  final FirebaseFirestore? _injectedFirestore;

  StudentProfileRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore => _injectedFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Retrieve the [StudentProfile] for a given [uid].
  /// Returns `null` if the document does not exist.
  Future<StudentProfile?> getProfile(String uid) async {
    try {
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return StudentProfile.fromFirestore(doc);
    } on FirebaseException catch (e) {
      debugPrint('[StudentProfileRepository] getProfile FirebaseException: ${e.code} - ${e.message}');
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
  /// Automatically extracts identity from [email], merges into Firestore, and marks profileSetupCompleted = true.
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
        'Please select both Class and Section to proceed.',
        code: 'missing-class-section',
      );
    }

    try {
      final docRef = _usersRef.doc(uid);
      final existingDoc = await docRef.get();

      // If already complete, prevent modifying immutable fields
      if (existingDoc.exists && existingDoc.data()?['profileSetupCompleted'] == true) {
        debugPrint('[StudentProfileRepository] Profile already completed for $uid');
        return StudentProfile.fromFirestore(existingDoc);
      }

      final profile = StudentProfile(
        uid: uid,
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

      // Save to Firestore using set with merge to preserve existing data safely
      await docRef.set(profile.toMap(forUpdate: existingDoc.exists), SetOptions(merge: true));

      debugPrint('[StudentProfileRepository] Successfully completed profile for ${profile.rollNumber} ($uid)');
      return profile;
    } on FirebaseException catch (e) {
      debugPrint('[StudentProfileRepository] saveProfile FirebaseException: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw const NexoraProfileException(
          'Permission denied. Please ensure you are logged in with your verified BVC account.',
          code: 'permission-denied',
        );
      } else if (e.code == 'unavailable') {
        throw const NexoraProfileException(
          'Firestore service unavailable. Please check your internet connection.',
          code: 'unavailable',
        );
      }
      throw NexoraProfileException(
        e.message ?? 'Failed to save student profile. Please try again.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('[StudentProfileRepository] Unexpected saveProfile error: $e');
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
