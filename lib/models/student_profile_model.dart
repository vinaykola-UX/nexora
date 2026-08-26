import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

/// Student profile model representing documents stored at `students/{uid}` in Cloud Firestore
class StudentProfile {
  final String uid;
  final String email;
  final String rollNumber;
  final String batchCode;
  final int academicYear;
  final String academicYearLabel;
  final String studentClass;
  final String section;
  final String role;
  final String college;
  final bool profileSetupCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentProfile({
    required this.uid,
    required this.email,
    required this.rollNumber,
    required this.batchCode,
    required this.academicYear,
    required this.academicYearLabel,
    required this.studentClass,
    required this.section,
    this.role = 'student',
    this.college = AppConstants.collegeName,
    this.profileSetupCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to parse from Firestore DocumentSnapshot
  factory StudentProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return StudentProfile.fromMap(data, snapshot.id);
  }

  /// Factory constructor to parse from Map
  factory StudentProfile.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final branchVal = data['branch'] as String? ?? data['class'] as String? ?? '';
    final currentYearVal = data['currentYear'] as String? ?? data['academicYearLabel'] as String? ?? '';
    final batchVal = data['batch'] as String? ?? data['batchCode'] as String? ?? '';

    return StudentProfile(
      uid: data['uid'] as String? ?? uid,
      email: (data['email'] as String? ?? '').toLowerCase(),
      rollNumber: (data['rollNumber'] as String? ?? '').toUpperCase(),
      batchCode: batchVal,
      academicYear: data['academicYear'] is int
          ? data['academicYear'] as int
          : int.tryParse(data['academicYear']?.toString() ?? '0') ?? 0,
      academicYearLabel: currentYearVal,
      studentClass: branchVal,
      section: data['section'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      college: data['college'] as String? ?? AppConstants.collegeName,
      profileSetupCompleted: data['profileSetupCompleted'] as bool? ?? false,
      createdAt: parseDateTime(data['createdAt']),
      updatedAt: parseDateTime(data['updatedAt']),
    );
  }

  /// Convert to Firestore-compatible Map matching students/{uid} schema
  Map<String, dynamic> toMap({bool forUpdate = false}) {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email.toLowerCase(),
      'rollNumber': rollNumber.toUpperCase(),
      'batch': batchCode,
      'currentYear': academicYearLabel,
      'academicYear': academicYear,
      'branch': studentClass,
      'class': studentClass,
      'section': section,
      'role': role,
      'college': college,
      'profileSetupCompleted': profileSetupCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!forUpdate) {
      map['createdAt'] = createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp();
    }

    return map;
  }

  StudentProfile copyWith({
    String? uid,
    String? email,
    String? rollNumber,
    String? batchCode,
    int? academicYear,
    String? academicYearLabel,
    String? studentClass,
    String? section,
    String? role,
    String? college,
    bool? profileSetupCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      rollNumber: rollNumber ?? this.rollNumber,
      batchCode: batchCode ?? this.batchCode,
      academicYear: academicYear ?? this.academicYear,
      academicYearLabel: academicYearLabel ?? this.academicYearLabel,
      studentClass: studentClass ?? this.studentClass,
      section: section ?? this.section,
      role: role ?? this.role,
      college: college ?? this.college,
      profileSetupCompleted: profileSetupCompleted ?? this.profileSetupCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'StudentProfile(uid: $uid, roll: $rollNumber, branch: $studentClass, section: $section, completed: $profileSetupCompleted)';
  }
}
